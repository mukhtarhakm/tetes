export type BrewHashFields = {
  bean_id: string;
  dose_g: number;
  ratio: number;
  water_temp_c: number;
  grind: string;
  total_time_s: number;
  taste_score: number;
  taste_tags: string[];
  brewed_at_utc: string;
  prev_hash: string;
};

export function buildHashInput(brew: BrewHashFields): string {
  const tenths = brew.ratio * 10;
  if (!Number.isFinite(brew.ratio) || Math.abs(tenths - Math.round(tenths)) > 0.0000001) {
    throw new Error("Rasio hanya boleh memakai satu angka desimal.");
  }
  const ratio = Number.isInteger(brew.ratio) ? brew.ratio.toFixed(0) : brew.ratio.toFixed(1);
  return [
    brew.bean_id,
    brew.dose_g.toFixed(1),
    `1:${ratio}`,
    brew.water_temp_c,
    brew.grind,
    brew.total_time_s,
    brew.taste_score,
    [...brew.taste_tags].sort().join(","),
    brew.brewed_at_utc,
    brew.prev_hash,
  ].join("|");
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
