import { normalizeCustomTasteTags } from "../_shared/custom_taste_tags.ts";

type Row = Record<string, unknown>;
export type AiType = "recommend" | "diagnose" | "chat";
export type AiInput = { type: AiType; payload: Row };

const species = ["arabika", "robusta", "campuran"];
const beanTypes = ["single_origin", "blend"];
const processes = ["washed", "natural", "honey", "lainnya"];
const roastLevels = ["light", "medium", "dark"];
const grinds = ["sangat_halus", "halus", "sedang_halus", "sedang", "sedang_kasar", "kasar"];
const tags = ["asam", "pahit", "hambar", "seimbang", "manis", "cokelat", "buah", "kacang", "floral", "karamel", "rempah"];
const stageNames = ["bloom", "pouring_2", "pouring_3", "pouring_4", "pouring_5"];

const string = (max = 500) => ({ type: "STRING", maxLength: max });
const numeric = (type: "INTEGER" | "NUMBER", minimum: number, maximum: number) => ({ type, minimum, maximum });
const suggestionSchema = (variable: string, value: object) => ({
  type: "OBJECT", required: ["variable", "from", "to", "reason"],
  properties: { variable: { type: "STRING", enum: [variable] }, from: value, to: value, reason: string() },
});
export const responseSchemas = {
  recommend: {
    type: "OBJECT", required: ["dose_g", "ratio", "water_temp_c", "grind", "pouring_count", "stages", "note"],
    properties: {
      dose_g: numeric("NUMBER", 5, 60), ratio: numeric("NUMBER", 10, 20),
      water_temp_c: numeric("INTEGER", 80, 100), grind: { type: "STRING", enum: grinds },
      pouring_count: numeric("INTEGER", 1, 5), note: string(),
      stages: { type: "ARRAY", minItems: 1, maxItems: 5, items: {
        type: "OBJECT", required: ["name", "start_s", "duration_s", "water_cum_g"],
        properties: { name: { type: "STRING", enum: stageNames }, start_s: numeric("NUMBER", 0, 3600),
          duration_s: numeric("NUMBER", 1, 3600), water_cum_g: numeric("NUMBER", 0, 1200) },
      } },
    },
  },
  diagnose: {
    type: "OBJECT", required: ["diagnosis", "likely_causes", "suggestions", "note"],
    properties: {
      diagnosis: string(), note: string(),
      likely_causes: { type: "ARRAY", minItems: 1, maxItems: 5, items: string() },
      suggestions: { type: "ARRAY", maxItems: 2, items: { anyOf: [
        suggestionSchema("dose_g", numeric("NUMBER", 5, 60)),
        suggestionSchema("ratio", numeric("NUMBER", 10, 20)),
        suggestionSchema("water_temp_c", numeric("INTEGER", 80, 100)),
        suggestionSchema("grind", { type: "STRING", enum: grinds }),
      ] } },
    },
  },
} as const;

export function openAiResponseSchema(type: "recommend" | "diagnose"): Record<string, unknown> {
  const convert = (source: Record<string, unknown>): Record<string, unknown> => {
    if (Array.isArray(source.anyOf)) return { anyOf: source.anyOf.map((item) => convert(item as Record<string, unknown>)) };
    const result: Record<string, unknown> = { ...source, type: String(source.type).toLowerCase() };
    if (source.type === "OBJECT") {
      const properties = source.properties as Record<string, Record<string, unknown>>;
      result.properties = Object.fromEntries(Object.entries(properties).map(([key, value]) => [key, convert(value)]));
      result.required = Object.keys(properties);
      result.additionalProperties = false;
    } else if (source.type === "ARRAY") {
      result.items = convert(source.items as Record<string, unknown>);
    }
    return result;
  };
  return convert(responseSchemas[type] as unknown as Record<string, unknown>);
}

export function normalizeOutput(type: AiType, value: unknown): unknown {
  if (!record(value)) return value;
  if (type === "recommend") {
    const output = { ...value };
    if (!Array.isArray(output.stages)) return output;
    let end = 0;
    output.stages = output.stages.map((stage: unknown, index: number) => {
      if (!record(stage)) return stage;
      const next = { ...stage };
      if (typeof next.start_s === "number" && Number.isFinite(next.start_s)) {
        const rounded = Math.round(next.start_s);
        next.start_s = index === 0 ? rounded : Math.max(rounded, end);
      }
      if (typeof next.duration_s === "number" && Number.isFinite(next.duration_s)) next.duration_s = Math.round(next.duration_s);
      if (typeof next.start_s === "number" && typeof next.duration_s === "number") end = next.start_s + next.duration_s;
      return next;
    });
    if (typeof output.dose_g === "number" && typeof output.ratio === "number" &&
      Number.isFinite(output.dose_g) && Number.isFinite(output.ratio) && output.stages.length) {
      const last = output.stages[output.stages.length - 1];
      const total = Math.round(output.dose_g * output.ratio * 10) / 10;
      if (record(last) && (output.stages.length === 1 ||
        (record(output.stages[output.stages.length - 2]) &&
          typeof output.stages[output.stages.length - 2].water_cum_g === "number" &&
          output.stages[output.stages.length - 2].water_cum_g < total))) {
        output.stages[output.stages.length - 1] = { ...last, water_cum_g: total };
      }
    }
    return output;
  }
  if (type !== "diagnose") return value;
  const output = { ...value };
  for (const key of ["diagnosis", "note"]) if (typeof output[key] === "string") output[key] = output[key].trim();
  if (Array.isArray(output.likely_causes)) output.likely_causes = output.likely_causes.slice(0, 5).map((item: unknown) => typeof item === "string" ? item.trim() : item);
  if (Array.isArray(output.suggestions)) output.suggestions = output.suggestions.slice(0, 2).map((item: unknown) => {
    if (!record(item)) return item;
    const next = { ...item };
    if (typeof next.reason === "string") next.reason = next.reason.trim();
    for (const key of ["from", "to"]) if (next.variable !== "grind" && typeof next[key] === "string" &&
      /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(next[key].trim())) {
      const converted = Number(next[key]);
      if (Number.isFinite(converted)) next[key] = converted;
    }
    return next;
  });
  return output;
}

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

function chatPayload(payload: Row): boolean {
  // 8 KiB caps total chat data, including context, before it reaches the model.
  if (new TextEncoder().encode(JSON.stringify(payload)).length > 8 * 1024 || !only(payload, ["messages", "context"])) return false;
  const messages = payload.messages;
  if (!Array.isArray(messages) || messages.length < 1 || messages.length > 12 ||
    !messages.every((item) => record(item) && only(item, ["role", "content"]) &&
      choice(item.role, ["user", "assistant"]) && typeof item.content === "string" &&
      item.content.trim().length >= 1 && item.content.trim().length <= 500) ||
    messages[messages.length - 1].role !== "user") return false;
  if (payload.context === undefined) return true;
  const context = payload.context;
  if (!record(context) || !only(context, ["bean", "recent_brews"])) return false;
  if (context.bean !== undefined) {
    const bean = context.bean;
    if (!record(bean) || !only(bean, ["name", "species", "roast_level", "remaining_stock_g", "best_settings"]) ||
      !text(bean.name, 100) || !choice(bean.species, species) ||
      !optional(bean.roast_level, (v) => choice(v, roastLevels)) ||
      !optional(bean.remaining_stock_g, (v) => number(v, 0, 1000000))) return false;
    if (bean.best_settings !== undefined) {
      const best = bean.best_settings;
      if (!record(best) || !only(best, ["dose_g", "ratio", "water_temp_c", "grind"]) ||
        !number(best.dose_g, 5, 60) || !number(best.ratio, 10, 20) ||
        !integer(best.water_temp_c, 80, 100) || !choice(best.grind, grinds)) return false;
    }
  }
  if (context.recent_brews !== undefined) {
    if (!Array.isArray(context.recent_brews) || context.recent_brews.length > 5 ||
      !context.recent_brews.every((item) => record(item) &&
        only(item, ["brewed_at_utc", "dose_g", "ratio", "water_temp_c", "grind", "taste_score", "taste_tags"]) &&
        utc(item.brewed_at_utc) && number(item.dose_g, 5, 60) && number(item.ratio, 10, 20) &&
        integer(item.water_temp_c, 80, 100) && choice(item.grind, grinds) &&
        integer(item.taste_score, 1, 5) && tasteTags(item.taste_tags))) return false;
  }
  return true;
}

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
  if (!record(value) || !only(value, ["dose_g", "ratio", "water_temp_c", "grind", "total_time_s", "taste_score", "taste_tags", "custom_taste_tags", "brewed_at_utc", "status", "notes", "stages"])) return false;
  if (!number(value.dose_g, 5, 60) || !number(value.ratio, 10, 20) || !integer(value.water_temp_c, 80, 100) || !choice(value.grind, grinds) ||
    !integer(value.taste_score, 1, 5) || !tasteTags(value.taste_tags) || !note(value.notes) ||
    normalizeCustomTasteTags(value.custom_taste_tags ?? []) === null ||
    !optional(value.total_time_s, (v) => integer(v, 0, 3600)) ||
    !optional(value.brewed_at_utc, utc) ||
    !optional(value.status, (v) => v === "aktif" || v === "dibatalkan")) return false;
  if (diagnosis && (!Array.isArray(value.stages) || value.stages.length < 1)) return false;
  return value.stages == null || Array.isArray(value.stages) && value.stages.length <= 5 && value.stages.every((item, index) => stage(item, index + 1));
}

export function validateInput(value: unknown): AiInput | null {
  if (!record(value) || !only(value, ["type", "payload"]) || (value.type !== "recommend" && value.type !== "diagnose" && value.type !== "chat") || !record(value.payload)) return null;
  const type = value.type;
  const payload = value.payload;
  if (type === "chat") {
    if (!chatPayload(payload)) return null;
    const clean = structuredClone(payload);
    (clean.messages as Row[]).forEach((message) => { message.content = (message.content as string).trim(); });
    return { type, payload: clean };
  }
  if (!only(payload, type === "recommend" ? ["bean", "history", "pouring_count"] : ["bean", "brew", "history"]) || !bean(payload.bean) ||
    !Array.isArray(payload.history) || payload.history.length > 5 || !payload.history.every((item) => brew(item, false))) return null;
  if (type === "recommend" ? !integer(payload.pouring_count, 1, 5) : !brew(payload.brew, true)) return null;
  const clean = structuredClone(payload);
  const trim = (value: string) => [...value].slice(0, 500).join("");
  const trimNotes = (row: Row) => { if (typeof row.notes === "string") row.notes = trim(row.notes); };
  if (typeof (clean.bean as Row).roastery_notes_text === "string") (clean.bean as Row).roastery_notes_text = trim((clean.bean as Row).roastery_notes_text as string);
  for (const item of clean.history as Row[]) trimNotes(item);
  if (type === "diagnose") {
    trimNotes(clean.brew as Row);
    (clean.brew as Row).custom_taste_tags = normalizeCustomTasteTags((clean.brew as Row).custom_taste_tags ?? []);
  }
  return { type, payload: clean };
}

export function validateOutput(type: AiType, value: unknown, _pouringCount?: number): Row | null {
  if (!record(value)) return null;
  if (type === "recommend") {
    if (!only(value, ["dose_g", "ratio", "water_temp_c", "grind", "pouring_count", "stages", "note"]) ||
      !number(value.dose_g, 5, 60) || !number(value.ratio, 10, 20) || !integer(value.water_temp_c, 80, 100) || !choice(value.grind, grinds) ||
      !text(value.note) || !Array.isArray(value.stages) || !integer(value.pouring_count, 1, 5) || value.stages.length !== value.pouring_count) return null;
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
