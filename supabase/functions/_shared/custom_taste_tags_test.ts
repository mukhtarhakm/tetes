import { normalizeCustomTasteTags } from "./custom_taste_tags.ts";

Deno.test("custom taste tags normalize and reject invalid values", () => {
  const result = normalizeCustomTasteTags([" Teh   Hitam ", "teh hitam", "Kréma-2"]);
  if (JSON.stringify(result) !== JSON.stringify(["teh hitam", "kréma-2"])) throw new Error("normalization failed");
  for (const value of [[""], ["teh!"], ["MANIS"], ["a".repeat(21)], ["a", "b", "c", "d"], [3]]) {
    if (normalizeCustomTasteTags(value) !== null) throw new Error("invalid tag accepted");
  }
});
