const builtIn = new Set(["asam", "pahit", "hambar", "seimbang", "manis", "cokelat", "buah", "kacang", "floral", "karamel", "rempah"]);

export function normalizeCustomTasteTags(value: unknown): string[] | null {
  if (!Array.isArray(value) || value.some((tag) => typeof tag !== "string")) return null;
  const result: string[] = [];
  const seen = new Set<string>();
  for (const raw of value as string[]) {
    const tag = raw.trim().replace(/\s+/gu, " ").toLowerCase();
    if ([...tag].length < 1 || [...tag].length > 20 || !/^[\p{L}\p{N} -]+$/u.test(tag) || builtIn.has(tag)) return null;
    if (!seen.has(tag)) { seen.add(tag); result.push(tag); }
  }
  return result.length <= 3 ? result : null;
}
