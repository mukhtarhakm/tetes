type Row = Record<string, unknown>;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const utc = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const zones = new Set(["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura", "Europe/London"]);
const types = new Set(["pameran", "lomba", "cupping", "workshop", "lainnya"]);
const isRow = (value: unknown): value is Row => value !== null && typeof value === "object" && !Array.isArray(value);
const id = (value: unknown) => typeof value === "string" && uuid.test(value);
const text = (value: unknown, max: number, required = false) =>
  value == null ? !required : typeof value === "string" && value.length <= max && (!required || value.trim().length > 0);
const integer = (value: unknown, min: number, max: number) => Number.isInteger(value) && (value as number) >= min && (value as number) <= max;
function utcTimestamp(value: unknown): value is string {
  return typeof value === "string" && utc.test(value) && !Number.isNaN(Date.parse(value)) &&
    new Date(value).toISOString().replace(/\.\d{3}Z$/, "Z") === value;
}
export function timestamp(value: unknown, now = Date.now()): value is string {
  return utcTimestamp(value) && Date.parse(value) <= now + 300000;
}
function eventStart(value: unknown, now: number): value is string {
  if (!utcTimestamp(value)) return false;
  const lower = new Date(now);
  const upper = new Date(now);
  lower.setUTCFullYear(lower.getUTCFullYear() - 5);
  upper.setUTCFullYear(upper.getUTCFullYear() + 5);
  return Date.parse(value) >= lower.getTime() && Date.parse(value) <= upper.getTime();
}
export function validateEvent(value: unknown, now = Date.now()): value is Row {
  if (!isRow(value)) return false;
  const reminders = typeof value.reminder_minutes === "string" ? value.reminder_minutes.split(",") : [];
  return id(value.id) && text(value.name, 80, true) && types.has(value.event_type as string) &&
    text(value.location, 120) && text(value.notes, 500) && eventStart(value.start_utc, now) &&
    zones.has(value.source_zone as string) && reminders.length >= 1 && reminders.length <= 3 &&
    reminders.every((item) => ["1440", "180", "30"].includes(item)) && new Set(reminders).size === reminders.length &&
    (value.deleted === true || value.deleted === false) && timestamp(value.created_at, now) &&
    timestamp(value.updated_at, now) && Date.parse(value.updated_at as string) >= Date.parse(value.created_at as string);
}
export function validateScore(value: unknown, now = Date.now()): value is Row {
  return isRow(value) && id(value.id) && integer(value.level, 1, 3) &&
    typeof value.accuracy === "number" && Number.isFinite(value.accuracy) && value.accuracy >= 0 && value.accuracy <= 1 &&
    integer(value.stars, 1, 3) && value.stars === (value.accuracy >= 0.90 ? 3 : value.accuracy >= 0.70 ? 2 : 1) &&
    integer(value.duration_s, 1, [30, 40, 45][(value.level as number) - 1] ?? 0) && timestamp(value.played_at, now);
}
export function validateFeedback(value: unknown, now = Date.now()): value is Row {
  return isRow(value) && id(value.id) && text(value.suggestion, 500) && text(value.impression, 500) &&
    (typeof value.suggestion === "string" && value.suggestion.trim().length > 0 ||
      typeof value.impression === "string" && value.impression.trim().length > 0) && timestamp(value.created_at, now);
}
