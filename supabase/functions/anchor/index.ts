import { Contract, JsonRpcProvider, Wallet, isAddress } from "npm:ethers@6.17.0";
import { requireValidSession, SessionUnauthorizedError } from "../_shared/session.ts";
import { canAnchor, headHashBytes32, reservationExpired, retryAfterSeconds, userKey } from "./logic.ts";

const contractAbi = [
  "function latest(bytes32) view returns (bytes32 headHash, uint64 seq, uint64 anchoredAt)",
  "function owner() view returns (address)",
  "function anchor(bytes32 userKey, bytes32 headHash, uint64 seq)",
  "event Anchored(bytes32 indexed userKey, bytes32 headHash, uint64 seq, uint64 anchoredAt)",
];
const headers = { "Content-Type": "application/json; charset=utf-8" };
const chainId = 11155111;
const deployedAddress = "0x8d80e52E86BDc990f6787D7DD5faF46BeC369324";
type AnchorRow = {
  id: string;
  seq: number;
  head_hash: string;
  user_key: string;
  tx_hash: string | null;
  status: "reserved" | "pending" | "confirmed" | "failed";
  requested_at: string;
};
type Reservation =
  | { kind: "no_brews" }
  | { kind: "already_anchored"; seq: number; tx_hash: string | null }
  | { kind: "rate_limited"; requested_at: string }
  | ({ kind: "in_progress" | "reserved" } & AnchorRow);

class AnchorError extends Error {
  constructor(readonly status: number, readonly code: string, readonly category: string) {
    super(code);
  }
}

function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...headers, ...extraHeaders } });
}

function errorResponse(status: number, code: string): Response {
  const message = status === 401 ? "Sesi tidak sah. Masuk kembali."
    : status === 429 ? "Tunggu lima menit sebelum mencatat jangkar berikutnya."
    : status === 503 ? "Pencatatan sementara gagal. Coba lagi nanti."
    : "Pencatatan jangkar gagal. Coba lagi.";
  return json({ error: { code, message } }, status);
}

function dbHeaders(): Record<string, string> {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key) throw new AnchorError(500, "server_configuration_error", "configuration");
  return { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
}

async function db(path: string, init: RequestInit = {}): Promise<Response> {
  const base = Deno.env.get("SUPABASE_URL");
  if (!base) throw new AnchorError(500, "server_configuration_error", "configuration");
  const response = await fetch(`${base}/rest/v1/${path}`, {
    ...init,
    headers: { ...dbHeaders(), ...init.headers },
  });
  if (!response.ok) throw new AnchorError(503, "retryable_error", "database");
  return response;
}

async function headFor(userId: string): Promise<{ seq: number; hash: string } | undefined> {
  const query = new URLSearchParams({ user_id: `eq.${userId}`, select: "seq,hash", order: "seq.desc", limit: "1" });
  const rows = await (await db(`brews?${query}`)).json() as { seq: number; hash: string }[];
  return rows[0];
}

async function openFor(userId: string): Promise<AnchorRow | undefined> {
  const query = new URLSearchParams({ user_id: `eq.${userId}`, status: "in.(reserved,pending)", select: "*", limit: "1" });
  const rows = await (await db(`chain_anchors?${query}`)).json() as AnchorRow[];
  return rows[0];
}

async function reserve(userId: string, key: string): Promise<Reservation> {
  return await (await db("rpc/reserve_chain_anchor", {
    method: "POST",
    body: JSON.stringify({ p_user_id: userId, p_user_key: key }),
  })).json() as Reservation;
}

async function changeStatus(row: AnchorRow, status: AnchorRow["status"], changes: Record<string, unknown> = {}): Promise<void> {
  const query = new URLSearchParams({ id: `eq.${row.id}`, status: `eq.${row.status}`, select: "id" });
  const response = await db(`chain_anchors?${query}`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ ...changes, status }),
  });
  const updated = await response.json() as { id: string }[];
  if (updated.length !== 1) throw new AnchorError(503, "retryable_error", "state_conflict");
  row.status = status;
  if ("tx_hash" in changes) row.tx_hash = changes.tx_hash as string | null;
}

async function eventTransactionHash(contract: Contract, key: string, seq: bigint): Promise<string | null> {
  try {
    const tip = await contract.runner!.provider!.getBlockNumber();
    const logs = await contract.queryFilter(contract.filters.Anchored(key), Math.max(0, tip - 5000), tip);
    const event = logs.find((log) => "args" in log && log.args.seq === seq);
    return event?.transactionHash ?? null;
  } catch {
    return null;
  }
}

async function confirm(row: AnchorRow, contract: Contract, txHash: string | null = row.tx_hash): Promise<Response> {
  const foundHash = txHash ?? await eventTransactionHash(contract, row.user_key, BigInt(row.seq));
  await changeStatus(row, "confirmed", { tx_hash: foundHash, anchored_at: new Date().toISOString() });
  const address = await contract.getAddress();
  return json({ anchored: true, seq: row.seq, head_hash: row.head_hash, user_key: row.user_key,
    tx_hash: foundHash, chain_id: chainId,
    explorer_url: `https://sepolia.etherscan.io/${foundHash ? `tx/${foundHash}` : `address/${address}`}` });
}

async function reconcile(row: AnchorRow, contract: Contract, provider: JsonRpcProvider): Promise<Response | null> {
  if (row.status === "pending" && row.tx_hash) {
    const receipt = await provider.getTransactionReceipt(row.tx_hash);
    if (receipt?.status === 1) return await confirm(row, contract);
    if (receipt?.status === 0) {
      await changeStatus(row, "failed");
      return null;
    }
    const onChain = await contract.latest(row.user_key);
    if (!canAnchor(BigInt(row.seq), onChain.seq)) return await confirm(row, contract);
    return json({ anchored: false, reason: "pending", tx_hash: row.tx_hash, seq: row.seq }, 202);
  }

  const onChain = await contract.latest(row.user_key);
  if (!canAnchor(BigInt(row.seq), onChain.seq)) return await confirm(row, contract);
  if (reservationExpired(row.requested_at, Date.now())) {
    await changeStatus(row, "failed");
    return null;
  }
  return json({ anchored: false, reason: "pending", tx_hash: null, seq: row.seq }, 202);
}

function nonceError(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const code = "code" in error ? String(error.code) : "";
  const message = "message" in error ? String(error.message).toLowerCase() : "";
  return code === "NONCE_EXPIRED" || code === "REPLACEMENT_UNDERPRICED" ||
    message.includes("nonce too low") || message.includes("replacement transaction underpriced");
}

function definitelyNotSent(error: unknown): boolean {
  if (!error || typeof error !== "object" || !("code" in error)) return false;
  return ["CALL_EXCEPTION", "INSUFFICIENT_FUNDS", "INVALID_ARGUMENT"].includes(String(error.code));
}

async function sendAnchor(row: AnchorRow, contract: Contract, provider: JsonRpcProvider, wallet: Wallet): Promise<Response> {
  const hash = headHashBytes32(row.head_hash);
  let transaction;
  try {
    transaction = await contract.anchor(row.user_key, hash, BigInt(row.seq), {
      nonce: await provider.getTransactionCount(wallet.address, "pending"),
    });
  } catch (error) {
    if (!nonceError(error)) {
      if (definitelyNotSent(error)) await changeStatus(row, "failed");
      throw new AnchorError(503, "retryable_error", definitelyNotSent(error) ? "send_rejected" : "send_uncertain");
    }
    const onChain = await contract.latest(row.user_key);
    if (!canAnchor(BigInt(row.seq), onChain.seq)) return await confirm(row, contract);
    try {
      transaction = await contract.anchor(row.user_key, hash, BigInt(row.seq), {
        nonce: await provider.getTransactionCount(wallet.address, "pending"),
      });
    } catch (retryError) {
      if (nonceError(retryError) || definitelyNotSent(retryError)) await changeStatus(row, "failed");
      throw new AnchorError(503, "retryable_error", nonceError(retryError) ? "nonce" :
        definitelyNotSent(retryError) ? "send_rejected" : "send_uncertain");
    }
  }

  await changeStatus(row, "pending", { tx_hash: transaction.hash });
  try {
    const receipt = await provider.waitForTransaction(transaction.hash, 1, 25_000);
    if (receipt?.status === 1) return await confirm(row, contract, transaction.hash);
    if (receipt?.status === 0) {
      await changeStatus(row, "failed");
      throw new AnchorError(503, "retryable_error", "reverted");
    }
  } catch (error) {
    if (error instanceof AnchorError) throw error;
    // Hash sudah tersimpan; pemeriksaan receipt dilanjutkan pada permintaan berikutnya.
  }
  return json({ anchored: false, reason: "pending", tx_hash: transaction.hash, seq: row.seq }, 202);
}

async function handle(request: Request): Promise<Response> {
  if (request.method !== "POST") return errorResponse(400, "invalid_request");
  const userId = await requireValidSession(request.headers.get("x-session-token") ?? "");
  const rpc = Deno.env.get("CHAIN_RPC_URL");
  const privateKey = Deno.env.get("CHAIN_PRIVATE_KEY");
  const address = Deno.env.get("CHAIN_CONTRACT_ADDRESS");
  if (!rpc || !privateKey || !address || !isAddress(address) ||
      address.toLowerCase() !== deployedAddress.toLowerCase()) {
    throw new AnchorError(500, "server_configuration_error", "configuration");
  }

  const head = await headFor(userId);
  if (!head) return json({ anchored: false, reason: "no_brews" });
  headHashBytes32(head.hash);
  const key = userKey(userId);
  const provider = new JsonRpcProvider(rpc);
  const wallet = new Wallet(privateKey, provider);
  const contract = new Contract(address, contractAbi, wallet);
  if ((await provider.getNetwork()).chainId !== BigInt(chainId) ||
      (await contract.owner()).toLowerCase() !== wallet.address.toLowerCase()) {
    throw new AnchorError(500, "server_configuration_error", "chain_configuration");
  }

  const existing = await openFor(userId);
  if (existing) {
    const result = await reconcile(existing, contract, provider);
    if (result) return result;
  }

  const reservation = await reserve(userId, key);
  if (reservation.kind === "no_brews") return json({ anchored: false, reason: "no_brews" });
  if (reservation.kind === "already_anchored") {
    return json({ anchored: false, reason: "already_anchored", tx_hash: reservation.tx_hash, seq: reservation.seq });
  }
  if (reservation.kind === "rate_limited") {
    return json({ error: { code: "rate_limited", message: "Tunggu lima menit sebelum mencatat jangkar berikutnya." } },
      429, { "Retry-After": String(retryAfterSeconds(reservation.requested_at, Date.now())) });
  }
  if (reservation.kind === "in_progress") {
    return await reconcile(reservation, contract, provider) ??
      errorResponse(503, "retryable_error");
  }

  const onChain = await contract.latest(key);
  if (!canAnchor(BigInt(reservation.seq), onChain.seq)) return await confirm(reservation, contract);
  return await sendAnchor(reservation, contract, provider, wallet);
}

Deno.serve(async (request) => {
  try {
    return await handle(request);
  } catch (error) {
    if (error instanceof SessionUnauthorizedError) return errorResponse(401, "invalid_session");
    const failure = error instanceof AnchorError ? error : new AnchorError(500, "server_error", "unexpected");
    console.error(JSON.stringify({ event: "anchor_error", category: failure.category }));
    return errorResponse(failure.status, failure.code);
  }
});
