import { keccak256, toUtf8Bytes } from "npm:ethers@6.17.0";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const head = /^[0-9a-f]{64}$/;

export function userKey(userId: string): string {
  const normalized = userId.toLowerCase();
  if (!uuid.test(normalized)) throw new Error("invalid_user_id");
  return keccak256(toUtf8Bytes(normalized));
}

export function headHashBytes32(hash: string): string {
  if (!head.test(hash) || /^0+$/.test(hash)) throw new Error("invalid_head_hash");
  return `0x${hash}`;
}

export function canAnchor(headSeq: bigint, onChainSeq: bigint): boolean {
  return headSeq > onChainSeq;
}

export function reservationExpired(requestedAt: string, now: number): boolean {
  return now - Date.parse(requestedAt) >= 10 * 60 * 1000;
}

export function retryAfterSeconds(requestedAt: string, now: number): number {
  return Math.max(0, Math.ceil((Date.parse(requestedAt) + 5 * 60 * 1000 - now) / 1000));
}
