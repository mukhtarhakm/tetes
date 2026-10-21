type Row = Record<string, unknown>;
export type AiType = "recommend" | "diagnose";
export type AiInput = { type: AiType; payload: Row };

const species = ["arabika", "robusta", "campuran"];
const beanTypes = ["single_origin", "blend"];
const processes = ["washed", "natural", "honey", "lainnya"];
const roastLevels = ["light", "medium", "dark"];
const grinds = ["sangat_halus", "halus", "sedang_halus", "sedang", "sedang_kasar", "kasar"];
const tags = ["asam", "pahit", "hambar", "seimbang", "manis", "cokelat", "buah", "kacang", "floral", "karamel", "rempah"];
const stageNames = ["bloom", "pouring_2", "pouring_3", "pouring_4", "pouring_5"];

const record = (value: unknown): value is Row => value !== null && typeof value === "object" && !Array.isArray(value);
const only = (value: Row, keys: string[]) => Object.keys(value).every((key) => keys.includes(key));
const number = (value: unknown, min: number, max: number): value is number => typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
const integer = (value: unknown, min: number, max: number): value is number => Number.isInteger(value) && number(value, min, max);
const text = (value: unknown, max = 500): value is string => typeof value === "string" && value.trim().length > 0 && value.length <= max;
const choice = (value: unknown, values: string[]) => typeof value === "string" && values.includes(value);
const optional = (value: unknown, check: (value: unknown) => boolean) => value == null || check(value);
const note = (value: unknown) => value == null || typeof value === "string";
const tasteTags = (value: unknown) => typeof value === "string" && value.length > 0 && value.split(",").every((tag) => tags.includes(tag)) && new Set(value.split(",")).size === value.split(",").length;
const utc = (value: unknown) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value) && !Number.isNaN(Date.parse(value));

function bean(value: unknown): value is Row {
  if (!record(value) || !only(value, ["name", "species", "bean_type", "arabica_percent", "roastery", "is_self_roasted", "origin", "process", "process_custom", "roast_level", "roast_date", "roastery_notes_tags", "roastery_notes_text", "initial_stock_g"])) return false;
  return text(value.name, 100) && choice(value.species, species) &&
    optional(value.bean_type, (v) => choice(v, beanTypes)) &&
    optional(value.arabica_percent, (v) => integer(v, 0, 100)) &&
    optional(value.roastery, (v) => text(v)) &&
    optional(value.is_self_roasted, (v) => typeof v === "boolean") &&
    optional(value.origin, (v) => text(v)) &&
    optional(value.process, (v) => choice(v, processes)) &&
    optional(value.process_custom, (v) => text(v, 40)) &&
    optional(value.roast_level, (v) => choice(v, roastLevels)) &&
    optional(value.roast_date, (v) => typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v)) &&
    optional(value.roastery_notes_tags, (v) => typeof v === "string" && v.length <= 500) &&
    note(value.roastery_notes_text) &&
    optional(value.initial_stock_g, (v) => number(v, 0, 1000000));
}

function stage(value: unknown, position: number): value is Row {
  if (!record(value) || !only(value, ["position", "name", "target_start_s", "target_duration_s", "target_water_cum_g", "target_pour_g", "actual_start_s", "actual_duration_s", "actual_water_g", "drawdown_s"])) return false;
  return value.position === position && choice(value.name, stageNames) &&
    integer(value.target_start_s, 0, 3600) && integer(value.target_duration_s, 1, 3600) &&
    number(value.target_water_cum_g, 0, 1200) && number(value.target_pour_g, 0, 1200) &&
    optional(value.actual_start_s, (v) => integer(v, 0, 3600)) &&
    optional(value.actual_duration_s, (v) => integer(v, 0, 3600)) &&
    optional(value.actual_water_g, (v) => number(v, 0, 1200)) &&
    optional(value.drawdown_s, (v) => integer(v, 0, 3600));
}

function brew(value: unknown, diagnosis: boolean): value is Row {
  if (!record(value) || !only(value, ["dose_g", "ratio", "water_temp_c", "grind", "total_time_s", "taste_score", "taste_tags", "brewed_at_utc", "status", "notes", "stages"])) return false;
  if (!number(value.dose_g, 5, 60) || !number(value.ratio, 10, 20) || !integer(value.water_temp_c, 80, 100) || !choice(value.grind, grinds) ||
    !integer(value.taste_score, 1, 5) || !tasteTags(value.taste_tags) || !note(value.notes) ||
    !optional(value.total_time_s, (v) => integer(v, 0, 3600)) ||
    !optional(value.brewed_at_utc, utc) ||
    !optional(value.status, (v) => v === "aktif" || v === "dibatalkan")) return false;
  if (diagnosis && (!Array.isArray(value.stages) || value.stages.length < 1)) return false;
  return value.stages == null || Array.isArray(value.stages) && value.stages.length <= 5 && value.stages.every((item, index) => stage(item, index + 1));
}

export function validateInput(value: unknown): AiInput | null {
  if (!record(value) || !only(value, ["type", "payload"]) || (value.type !== "recommend" && value.type !== "diagnose") || !record(value.payload)) return null;
  const type = value.type;
  const payload = value.payload;
  if (!only(payload, type === "recommend" ? ["bean", "history", "pouring_count"] : ["bean", "brew", "history"]) || !bean(payload.bean) ||
    !Array.isArray(payload.history) || payload.history.length > 5 || !payload.history.every((item) => brew(item, false))) return null;
  if (type === "recommend" ? !integer(payload.pouring_count, 1, 5) : !brew(payload.brew, true)) return null;
  const clean = structuredClone(payload);
  const trim = (value: string) => [...value].slice(0, 500).join("");
  const trimNotes = (row: Row) => { if (typeof row.notes === "string") row.notes = trim(row.notes); };
  if (typeof (clean.bean as Row).roastery_notes_text === "string") (clean.bean as Row).roastery_notes_text = trim((clean.bean as Row).roastery_notes_text as string);
  for (const item of clean.history as Row[]) trimNotes(item);
  if (type === "diagnose") trimNotes(clean.brew as Row);
  return { type, payload: clean };
}

export function validateOutput(type: AiType, value: unknown, pouringCount?: number): Row | null {
  if (!record(value)) return null;
  if (type === "recommend") {
    if (!only(value, ["dose_g", "ratio", "water_temp_c", "grind", "stages", "note"]) ||
      !number(value.dose_g, 5, 60) || !number(value.ratio, 10, 20) || !integer(value.water_temp_c, 80, 100) || !choice(value.grind, grinds) ||
      !text(value.note) || !Array.isArray(value.stages) || !integer(pouringCount, 1, 5) || value.stages.length !== pouringCount) return null;
    let end = 0;
    let water = 0;
    for (let i = 0; i < value.stages.length; i++) {
      const item = value.stages[i];
      if (!record(item) || !only(item, ["name", "start_s", "duration_s", "water_cum_g"]) || item.name !== stageNames[i] ||
        !integer(item.start_s, end, 3600) || !integer(item.duration_s, 1, 3600) || !number(item.water_cum_g, water + Number.EPSILON, 1200)) return null;
      end = item.start_s + item.duration_s;
      water = item.water_cum_g;
    }
    return Math.abs(water - value.dose_g * value.ratio) <= 1 ? value : null;
  }
  if (!only(value, ["diagnosis", "likely_causes", "suggestions", "note"]) || !text(value.diagnosis) || !text(value.note) ||
    !Array.isArray(value.likely_causes) || value.likely_causes.length < 1 || value.likely_causes.length > 5 || !value.likely_causes.every((item) => text(item)) ||
    !Array.isArray(value.suggestions) || value.suggestions.length > 2) return null;
  for (const item of value.suggestions) {
    if (!record(item) || !only(item, ["variable", "from", "to", "reason"]) || !text(item.reason)) return null;
    const valid = item.variable === "dose_g" ? (v: unknown) => number(v, 5, 60) :
      item.variable === "ratio" ? (v: unknown) => number(v, 10, 20) :
      item.variable === "water_temp_c" ? (v: unknown) => integer(v, 80, 100) :
      item.variable === "grind" ? (v: unknown) => choice(v, grinds) : null;
    if (!valid || !valid(item.from) || !valid(item.to)) return null;
  }
  return value;
}

export function parseOutput(type: AiType, text: string, pouringCount?: number): Row | null {
  try { return validateOutput(type, JSON.parse(text), pouringCount); } catch { return null; }
}
