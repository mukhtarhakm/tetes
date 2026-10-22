import { buildHashInput, sha256Hex, type BrewHashFields } from "../_shared/hash.ts";
import { requireValidSession, SessionUnauthorizedError } from "../_shared/session.ts";
import { validateEvent, validateScore, validateFeedback } from "./validation.ts";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const utc = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const date = /^\d{4}-\d{2}-\d{2}$/;
const hash = /^(0|[0-9a-f]{64})$/;
const enums = {
  species: ["arabika", "robusta", "campuran"],
  bean_type: ["single_origin", "blend"],
  process: ["washed", "natural", "honey", "lainnya"],
  roast_level: ["light", "medium", "dark"],
  grind: ["sangat_halus", "halus", "sedang_halus", "sedang", "sedang_kasar", "kasar"],
  taste_tag: ["asam", "pahit", "hambar", "seimbang", "manis", "cokelat", "buah", "kacang", "floral", "karamel", "rempah"],
  status: ["aktif", "dibatalkan"],
  stage: ["bloom", "pouring_2", "pouring_3", "pouring_4", "pouring_5"],
} as const;
type Row = Record<string, unknown>;
type Rejection = { table: "beans" | "brews" | "events" | "game_scores" | "feedback"; id: string; reason: "invalid" | "invalid_event" | "invalid_score" | "invalid_feedback" | "future_timestamp" | "hash_mismatch" | "chain_broken" | "tamper" | "not_owner" | "chain_blocked" | "immutable" | "stale" };

Deno.serve(async (request) => {
  const started = performance.now();
  let beanCount = 0;
  let brewCount = 0;
  try {
    const response = await handle(request, (beans, brews) => { beanCount = beans; brewCount = brews; });
    console.info(JSON.stringify({ event: "sync_push", beans: beanCount, brews: brewCount, duration_ms: Math.round(performance.now() - started) }));
    return response;
  } catch (error) {
    if (error instanceof SessionUnauthorizedError) return errorResponse(401, "invalid_session", "Sesi tidak sah. Masuk kembali.");
    console.error(JSON.stringify({ event: "sync_push_error", beans: beanCount, brews: brewCount, duration_ms: Math.round(performance.now() - started) }));
    return errorResponse(500, "server_error", "Sinkronisasi gagal. Coba lagi.");
  }
});

async function handle(request: Request, count: (beans: number, brews: number) => void): Promise<Response> {
  if (request.method !== "POST") return errorResponse(400, "invalid_request", "Permintaan harus memakai POST.");
  const userId = await requireValidSession(request.headers.get("x-session-token") ?? "");
  let body: unknown;
  try { body = await request.json(); } catch { return errorResponse(400, "invalid_json", "Body JSON tidak valid."); }
  if (!record(body) || !Array.isArray(body.beans) || !Array.isArray(body.brews) || body.beans.length > 100 || body.brews.length > 50 ||
    !["events", "game_scores", "feedback"].every((name) => body[name] === undefined || Array.isArray(body[name]) && (body[name] as unknown[]).length <= 100)) {
    return errorResponse(400, "invalid_input", "Jumlah atau bentuk data sinkronisasi tidak valid.");
  }
  count(body.beans.length, body.brews.length);
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("database unavailable");
  const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
  const accepted = { beans: [] as string[], brews: [] as string[], events: [] as string[], game_scores: [] as string[], feedback: [] as string[] };
  const rejected: Rejection[] = [];

  for (const value of body.beans) {
    const id = record(value) && typeof value.id === "string" ? value.id : "";
    const bean = validateBean(value);
    if (!bean) { rejected.push({ table: "beans", id, reason: "invalid" }); continue; }
    const response = await fetch(`${url}/rest/v1/rpc/upsert_sync_bean`, {
      method: "POST", headers, body: JSON.stringify({ p_user_id: userId, p_bean: bean }),
    });
    if (!response.ok) throw new Error("bean rpc failed");
    const result = await response.json();
    if (result === "not_owner") rejected.push({ table: "beans", id, reason: "not_owner" });
    else if (result === "accepted") accepted.beans.push(id);
    else throw new Error("unexpected bean rpc result");
  }

  const sorted = [...body.brews].sort((a, b) => (record(a) && typeof a.seq === "number" ? a.seq : Infinity) - (record(b) && typeof b.seq === "number" ? b.seq : Infinity));
  let blocked = false;
  for (const value of sorted) {
    const id = record(value) && typeof value.id === "string" ? value.id : "";
    if (blocked) { rejected.push({ table: "brews", id, reason: "chain_blocked" }); continue; }
    const brew = validateBrew(value);
    if (!brew) { rejected.push({ table: "brews", id, reason: "invalid" }); blocked = true; continue; }
    const query = new URL(`${url}/rest/v1/brews`);
    query.searchParams.set("id", `eq.${id}`);
    query.searchParams.set("select", "*");
    query.searchParams.set("limit", "1");
    const lookup = await fetch(query, { headers });
    if (!lookup.ok) throw new Error("brew lookup failed");
    const existing = (await lookup.json() as Row[])[0];
    let reason: Rejection["reason"] | undefined;
    if (existing?.user_id !== undefined && existing.user_id !== userId) reason = "not_owner";
    else if (existing && !sameHashedFields(existing, brew)) reason = "tamper";
    else if (await sha256Hex(buildHashInput({ ...brew, taste_tags: brew.taste_tags.split(",") })) !== brew.hash) reason = "hash_mismatch";
    else if (existing) {
      const update = await fetch(`${url}/rest/v1/brews?id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH", headers: { ...headers, Prefer: "return=minimal" },
        body: JSON.stringify({ notes: brew.notes, ai_advice: brew.ai_advice, cost_idr: brew.cost_idr, status: brew.status }),
      });
      if (!update.ok) throw new Error("brew update failed");
      accepted.brews.push(id);
      continue;
    } else {
      const insert = await fetch(`${url}/rest/v1/rpc/insert_brew_with_stages`, {
        method: "POST", headers,
        body: JSON.stringify({ p_user_id: userId, p_brew: brew, p_stages: brew.stages }),
      });
      if (!insert.ok) throw new Error("brew rpc failed");
      const result = await insert.json();
      if (result === "accepted") { accepted.brews.push(id); continue; }
      if (result === "chain_broken" || result === "not_owner") reason = result;
      else throw new Error("unexpected brew rpc result");
    }
    rejected.push({ table: "brews", id, reason: reason ?? "invalid" });
    blocked = true;
  }
  const groups = [
    ["events", "upsert_sync_event", validateEvent],
    ["game_scores", "insert_sync_score", validateScore],
    ["feedback", "insert_sync_feedback", validateFeedback],
  ] as const;
  for (const [table, rpc, validate] of groups) {
    for (const value of (body[table] ?? []) as unknown[]) {
      const id = record(value) && typeof value.id === "string" ? value.id : "";
      if (!validate(value)) {
        const fields = table === "events" ? ["created_at", "updated_at"]
          : table === "game_scores" ? ["played_at"] : ["created_at"];
        const future = record(value) && fields.some((field) => typeof value[field] === "string" &&
          !Number.isNaN(Date.parse(value[field] as string)) && Date.parse(value[field] as string) > Date.now() + 300000);
        rejected.push({ table, id, reason: future ? "future_timestamp" :
          table === "events" ? "invalid_event" : table === "game_scores" ? "invalid_score" : "invalid_feedback" });
        continue;
      }
      const payload = { ...value };
      delete payload.user_id;
      delete payload.sync_status;
      delete payload.notif_base_id;
      if (table === "events") payload.deleted = value.deleted === true;
      const response = await fetch(`${url}/rest/v1/rpc/${rpc}`, {
        method: "POST", headers,
        body: JSON.stringify({ p_user_id: userId, [`p_${table === "game_scores" ? "score" : table === "events" ? "event" : "feedback"}`]: payload }),
      });
      if (!response.ok) throw new Error("sync rpc failed");
      const result = await response.json();
      if (result === "accepted") accepted[table].push(id);
      else if (result === "not_owner" || result === "immutable" || result === "stale") rejected.push({ table, id, reason: result });
      else throw new Error("unexpected sync rpc result");
    }
  }
  return new Response(JSON.stringify({ accepted, rejected }), { status: 200, headers: jsonHeaders });
}

function record(value: unknown): value is Row { return value !== null && typeof value === "object" && !Array.isArray(value); }
function text(value: unknown): value is string { return typeof value === "string" && value.length > 0; }
function optionalText(value: unknown): boolean { return value == null || typeof value === "string"; }
function number(value: unknown, min = -Infinity, max = Infinity): value is number { return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max; }
function integer(value: unknown, min = 0, max = 2147483647): value is number { return Number.isInteger(value) && number(value, min, max); }
function optionalNumber(value: unknown, min = -Infinity): boolean { return value == null || number(value, min); }
function timestamp(value: unknown): value is string { return typeof value === "string" && utc.test(value) && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString().replace(/\.\d{3}Z$/, "Z") === value; }
function calendarDate(value: unknown): boolean { return value == null || (typeof value === "string" && date.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`)) && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value); }
function choice(value: unknown, options: readonly string[]): boolean { return value == null || (typeof value === "string" && options.includes(value)); }

function validateBean(value: unknown): Row | null {
  if (!record(value) || typeof value.id !== "string" || !uuid.test(value.id) || !text(value.name) || !choice(value.species, enums.species) || value.species == null ||
    !choice(value.bean_type, enums.bean_type) || !choice(value.process, enums.process) || !choice(value.roast_level, enums.roast_level) ||
    !optionalText(value.roastery) || !optionalText(value.origin) || !optionalText(value.roastery_notes_text) ||
    !calendarDate(value.roast_date) || !calendarDate(value.fx_date) || !timestamp(value.created_at) || !timestamp(value.updated_at) ||
    (value.is_self_roasted != null && typeof value.is_self_roasted !== "boolean") ||
    (value.archived != null && typeof value.archived !== "boolean") ||
    !number(value.initial_stock_g, 0.0000001) || !optionalNumber(value.pack_size_g, 0.0000001) ||
    !optionalNumber(value.price_original, 0.0000001) || !optionalNumber(value.fx_rate, 0.0000001) ||
    !optionalNumber(value.price_idr_per_kg, 0) ||
    (value.price_original != null && (value.pack_size_g == null || !text(value.currency))) ||
    (value.currency != null && (typeof value.currency !== "string" || !/^[A-Z]{3}$/.test(value.currency))) ||
    (value.best_brew_id != null && (typeof value.best_brew_id !== "string" || !uuid.test(value.best_brew_id)))) return null;
  if (value.species === "campuran" ? !integer(value.arabica_percent, 0, 100) : value.arabica_percent != null) return null;
  if (value.process === "lainnya" ? !text(value.process_custom) || (value.process_custom as string).length > 40 : value.process_custom != null && value.process_custom !== "") return null;
  if (value.roastery_notes_tags != null) {
    if (typeof value.roastery_notes_tags !== "string") return null;
    const tags = value.roastery_notes_tags === "" ? [] : value.roastery_notes_tags.split(",");
    if (tags.length > 10 || new Set(tags).size !== tags.length || tags.join(",") !== [...tags].sort().join(",") || tags.some((tag) => tag !== tag.trim() || tag !== tag.toLowerCase() || tag.length > 30 || tag.length === 0)) return null;
  }
  return { ...value, is_self_roasted: value.is_self_roasted ?? false, archived: value.archived ?? false };
}

type ValidBrew = Row & Omit<BrewHashFields, "taste_tags"> & { id: string; seq: number; hash: string; taste_tags: string; stages: Row[] };
function validateBrew(value: unknown): ValidBrew | null {
  if (!record(value) || typeof value.id !== "string" || !uuid.test(value.id) || typeof value.bean_id !== "string" || !uuid.test(value.bean_id) ||
    !integer(value.seq, 1) || !timestamp(value.brewed_at_utc) || !number(value.dose_g, 5, 60) || Math.abs((value.dose_g as number) * 10 - Math.round((value.dose_g as number) * 10)) > 0.0000001 ||
    !number(value.ratio, 10, 20) || Math.abs((value.ratio as number) * 10 - Math.round((value.ratio as number) * 10)) > 0.0000001 ||
    !integer(value.water_temp_c, 80, 100) || !choice(value.grind, enums.grind) || value.grind == null ||
    !integer(value.total_time_s) || !integer(value.taste_score, 1, 5) ||
    typeof value.taste_tags !== "string" || !/^[a-z_,]*$/.test(value.taste_tags) ||
    value.taste_tags.split(",").some((tag) => tag && !enums.taste_tag.includes(tag as typeof enums.taste_tag[number])) ||
    !optionalText(value.notes) || !optionalText(value.ai_advice) || !optionalNumber(value.cost_idr, 0) ||
    !choice(value.status, enums.status) || !timestamp(value.created_at) ||
    typeof value.prev_hash !== "string" || !hash.test(value.prev_hash) ||
    typeof value.hash !== "string" || !/^[0-9a-f]{64}$/.test(value.hash) ||
    !Array.isArray(value.stages) || value.stages.length < 1 || value.stages.length > 5) return null;
  const tags = value.taste_tags === "" ? [] : value.taste_tags.split(",");
  if (new Set(tags).size !== tags.length || tags.join(",") !== [...tags].sort().join(",") || tags.some((tag) => !tag)) return null;
  if (value.ai_advice != null) {
    try { JSON.parse(value.ai_advice as string); } catch { return null; }
  }
  const stageIds = new Set<string>();
  for (let i = 0; i < value.stages.length; i++) {
    const stage = value.stages[i];
    if (!record(stage) || typeof stage.id !== "string" || !uuid.test(stage.id) || stage.position !== i + 1 ||
      stageIds.has(stage.id) || (stage.brew_id != null && stage.brew_id !== value.id) ||
      !choice(stage.name, enums.stage) || stage.name == null || !integer(stage.target_start_s) || !integer(stage.target_duration_s) ||
      !number(stage.target_water_cum_g, 0) || !number(stage.target_pour_g, 0) ||
      stage.actual_start_s != null || stage.actual_duration_s != null ||
      !optionalNumber(stage.actual_water_g, 0) || !optionalNumber(stage.drawdown_s, 0) ||
      (i < value.stages.length - 1 && stage.drawdown_s != null)) return null;
    stageIds.add(stage.id);
  }
  return { ...value, status: value.status ?? "aktif", taste_tags: value.taste_tags as string, stages: value.stages as Row[] } as ValidBrew;
}

function sameHashedFields(existing: Row, incoming: ValidBrew): boolean {
  return existing.bean_id === incoming.bean_id && existing.dose_g === incoming.dose_g && existing.ratio === incoming.ratio &&
    existing.water_temp_c === incoming.water_temp_c && existing.grind === incoming.grind &&
    existing.total_time_s === incoming.total_time_s && existing.taste_score === incoming.taste_score &&
    existing.taste_tags === incoming.taste_tags && existing.brewed_at_text === incoming.brewed_at_utc &&
    existing.prev_hash === incoming.prev_hash && existing.hash === incoming.hash && existing.seq === incoming.seq;
}

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ error: { code, message, details: {} } }), { status, headers: jsonHeaders });
}
