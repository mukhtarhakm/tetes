import { requireValidSession, SessionUnauthorizedError } from "../_shared/session.ts";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };
const hash = /^[0-9a-f]{64}$/;
const beanColumns = "id,name,species,bean_type,arabica_percent,roastery,is_self_roasted,origin,process,process_custom,roast_level,roast_date,pack_size_g,price_original,currency,fx_rate,fx_date,price_idr_per_kg,initial_stock_g,roastery_notes_tags,roastery_notes_text,best_brew_id,archived,created_at,updated_at";
const brewColumns = "id,seq,bean_id,brewed_at_text,dose_g,ratio,water_temp_c,grind,total_time_s,taste_score,taste_tags,custom_taste_tags,notes,ai_advice,cost_idr,status,prev_hash,hash,created_at";
const stageColumns = "id,brew_id,position,name,target_start_s,target_duration_s,target_water_cum_g,target_pour_g,actual_start_s,actual_duration_s,actual_water_g,drawdown_s";
type Row = Record<string, unknown>;

Deno.serve(async (request) => {
  const started = performance.now();
  let status = "error";
  let beanCount = 0;
  let brewCount = 0;
  try {
    const result = await handle(request);
    status = result.status;
    beanCount = "beans" in result ? result.beans.length : 0;
    brewCount = "brews" in result ? result.brews.length : 0;
    return new Response(JSON.stringify(result), { status: 200, headers: jsonHeaders });
  } catch (error) {
    if (error instanceof SessionUnauthorizedError) {
      status = "invalid_session";
      return errorResponse(401, status, "Sesi tidak sah. Masuk kembali.");
    }
    if (error instanceof InputError) {
      status = error.code;
      return errorResponse(error.status, error.code, error.message);
    }
    console.error(JSON.stringify({ event: "sync_pull_error", status, beans: beanCount, brews: brewCount, duration_ms: Math.round(performance.now() - started) }));
    return errorResponse(500, "server_error", "Sinkronisasi gagal. Coba lagi.");
  } finally {
    console.info(JSON.stringify({ event: "sync_pull", status, beans: beanCount, brews: brewCount, duration_ms: Math.round(performance.now() - started) }));
  }
});

class InputError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

async function handle(request: Request) {
  if (request.method !== "POST") throw new InputError(400, "invalid_request", "Permintaan harus memakai POST.");
  const userId = await requireValidSession(request.headers.get("x-session-token") ?? "");
  let body: unknown;
  try { body = await request.json(); } catch { throw new InputError(400, "invalid_json", "Body JSON tidak valid."); }
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new InputError(400, "invalid_input", "Data sinkronisasi tidak valid.");
  const input = body as Row;
  if (input.group !== undefined) return await pullGroup(input, userId);
  if (!Number.isInteger(input.last_seq) || (input.last_seq as number) < 0 || (input.last_seq as number) > 2147483647 ||
    (input.last_seq === 0 ? input.last_hash !== null : typeof input.last_hash !== "string" || !hash.test(input.last_hash)) ||
    (input.page_size !== undefined && (!Number.isInteger(input.page_size) || (input.page_size as number) < 1 || (input.page_size as number) > 50))) {
    throw new InputError(400, "invalid_input", "Data sinkronisasi tidak valid.");
  }
  const lastSeq = input.last_seq as number;
  const pageSize = (input.page_size ?? 50) as number;
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("database unavailable");
  const headers = { apikey: key, Authorization: `Bearer ${key}` };
  const read = async (table: string, parameters: Record<string, string>, count = false): Promise<Row[]> => {
    const query = new URL(`${url}/rest/v1/${table}`);
    query.searchParams.set("user_id", `eq.${userId}`);
    for (const [name, value] of Object.entries(parameters)) query.searchParams.set(name, value);
    const response = await fetch(query, { headers: count ? { ...headers, Prefer: "count=exact" } : headers });
    if (!response.ok) throw new Error("database read failed");
    if (count) {
      const total = Number(response.headers.get("Content-Range")?.split("/")[1]);
      if (total > 500) throw new InputError(413, "too_many_beans", "Jumlah biji melebihi batas sinkronisasi.");
    }
    return await response.json() as Row[];
  };
  const latest = await read("brews", { select: "seq", order: "seq.desc", limit: "1" });
  const serverLastSeq = latest[0]?.seq as number | undefined ?? 0;
  let status: "empty_server" | "pull" | "local_ahead" | "diverged" | "up_to_date";
  if (serverLastSeq === 0) status = "empty_server";
  else if (lastSeq === 0) status = "pull";
  else if (lastSeq > serverLastSeq) status = "local_ahead";
  else {
    const match = await read("brews", { select: "hash", seq: `eq.${lastSeq}`, limit: "1" });
    status = match[0]?.hash !== input.last_hash ? "diverged" : lastSeq === serverLastSeq ? "up_to_date" : "pull";
  }
  if (status === "local_ahead" || status === "diverged") {
    return { status, server_last_seq: serverLastSeq, has_more: false, beans: [], brews: [] };
  }
  const beanRows = await read("beans", { select: beanColumns, order: "id.asc", limit: "501" }, true);
  if (beanRows.length > 500) throw new InputError(413, "too_many_beans", "Jumlah biji melebihi batas sinkronisasi.");
  const beans = beanRows.map((row) => ({ ...row, created_at: utc(row.created_at), updated_at: utc(row.updated_at),
    arabica_percent: numeric(row.arabica_percent), pack_size_g: numeric(row.pack_size_g), price_original: numeric(row.price_original),
    fx_rate: numeric(row.fx_rate), price_idr_per_kg: numeric(row.price_idr_per_kg), initial_stock_g: numeric(row.initial_stock_g) }));
  let brews: Row[] = [];
  if (status === "pull") {
    const brewRows = await read("brews", { select: brewColumns, seq: `gt.${lastSeq}`, order: "seq.asc", limit: String(pageSize) });
    const ids = brewRows.map((row) => row.id as string);
    const stages = ids.length ? await read("brew_stages", { select: stageColumns, brew_id: `in.(${ids.join(",")})`, order: "brew_id.asc,position.asc", limit: "251" }) : [];
    if (stages.length > 250) throw new Error("too many stages");
    brews = brewRows.map(({ brewed_at_text, ...row }) => ({ ...row, brewed_at_utc: brewed_at_text,
      created_at: utc(row.created_at), seq: numeric(row.seq), dose_g: numeric(row.dose_g), ratio: numeric(row.ratio),
      water_temp_c: numeric(row.water_temp_c), total_time_s: numeric(row.total_time_s), taste_score: numeric(row.taste_score),
      cost_idr: numeric(row.cost_idr), stages: stages.filter((stage) => stage.brew_id === row.id).map((stage) => ({
        ...stage, position: numeric(stage.position), target_start_s: numeric(stage.target_start_s),
        target_duration_s: numeric(stage.target_duration_s), target_water_cum_g: numeric(stage.target_water_cum_g),
        target_pour_g: numeric(stage.target_pour_g), actual_start_s: numeric(stage.actual_start_s),
        actual_duration_s: numeric(stage.actual_duration_s), actual_water_g: numeric(stage.actual_water_g), drawdown_s: numeric(stage.drawdown_s),
      })) }));
  }
  return { status, server_last_seq: serverLastSeq, has_more: status === "pull" && brews.length > 0 && (brews.at(-1)!.seq as number) < serverLastSeq, beans, brews };
}

async function pullGroup(input: Row, userId: string) {
  const group = input.group;
  if (group !== "events" && group !== "game_scores" && group !== "feedback") {
    throw new InputError(400, "invalid_input", "Kelompok sinkronisasi tidak valid.");
  }
  const cursorAt = input.cursor_at;
  const cursorId = input.cursor_id;
  if ((cursorAt == null) !== (cursorId == null) ||
    cursorAt != null && (typeof cursorAt !== "string" || Number.isNaN(Date.parse(cursorAt)) ||
      typeof cursorId !== "string" || !/^[0-9a-f-]{36}$/.test(cursorId))) {
    throw new InputError(400, "invalid_input", "Kursor sinkronisasi tidak valid.");
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("database unavailable");
  const query = new URL(`${url}/rest/v1/${group}`);
  query.searchParams.set("user_id", `eq.${userId}`);
  query.searchParams.set("select", group === "events"
    ? "id,name,event_type,location,notes,start_utc,source_zone,reminder_minutes,deleted,created_at,updated_at,server_updated_at"
    : group === "game_scores"
    ? "id,level,accuracy,stars,duration_s,played_at,server_updated_at"
    : "id,suggestion,impression,created_at,server_updated_at");
  if (cursorAt != null) {
    query.searchParams.set("or", `(server_updated_at.gt.${cursorAt},and(server_updated_at.eq.${cursorAt},id.gt.${cursorId}))`);
  }
  query.searchParams.set("order", "server_updated_at.asc,id.asc");
  query.searchParams.set("limit", "51");
  const response = await fetch(query, { headers: { apikey: key, Authorization: `Bearer ${key}` } });
  if (!response.ok) throw new Error("database read failed");
  const rows = await response.json() as Row[];
  const page = rows.slice(0, 50).map((row) => {
    const result = { ...row };
    if (group === "events") {
      result.deleted = row.deleted === true;
      for (const field of ["start_utc", "created_at", "updated_at"]) result[field] = utc(row[field]);
    } else if (group === "game_scores") {
      result.accuracy = numeric(row.accuracy);
      result.level = numeric(row.level);
      result.stars = numeric(row.stars);
      result.duration_s = numeric(row.duration_s);
      result.played_at = utc(row.played_at);
    } else result.created_at = utc(row.created_at);
    return result;
  });
  const last = page.at(-1);
  return { status: "pull", group, rows: page, has_more: rows.length > 50,
    cursor_at: last?.server_updated_at ?? null, cursor_id: last?.id ?? null };
}

function utc(value: unknown): string { return new Date(value as string).toISOString().replace(/\.\d{3}Z$/, "Z"); }
function numeric(value: unknown): number | null { return value == null ? null : Number(value); }
function errorResponse(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ error: { code, message, details: {} } }), { status, headers: jsonHeaders });
}
