import { buildHashInput, sha256Hex } from "./hash.ts";

for (const [ratio, waterTemp, time, score, tags, date, previous, expected] of [
  [16, 92, 195, 3, ["cokelat", "asam"], "2026-10-17T08:30:00Z", "0", "bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34"],
  [15, 90, 185, 4, ["seimbang", "cokelat"], "2026-10-18T08:30:00Z", "bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34", "2fbdd892eb66dc64c4436c654ad6ada4c6eaaf50252f9cf21c5adb05105fdd3c"],
] as const) {
  Deno.test(`hash vector ${date}`, async () => {
    const input = buildHashInput({
      bean_id: "11111111-1111-4111-8111-111111111111",
      dose_g: 15,
      ratio,
      water_temp_c: waterTemp,
      grind: "sedang",
      total_time_s: time,
      taste_score: score,
      taste_tags: [...tags],
      brewed_at_utc: date,
      prev_hash: previous,
    });
    const actual = await sha256Hex(input);
    if (actual !== expected) throw new Error(`Hash tidak sesuai: ${actual}`);
  });
}
