import { parseOutput, validateInput } from "./validation.ts";

const validRecommend = {
  dose_g: 15, ratio: 16, water_temp_c: 92, grind: "sedang",
  stages: [
    { name: "bloom", start_s: 0, duration_s: 40, water_cum_g: 45 },
    { name: "pouring_2", start_s: 40, duration_s: 50, water_cum_g: 140 },
    { name: "pouring_3", start_s: 90, duration_s: 50, water_cum_g: 240 },
  ],
  note: "Titik awal seduh.",
};

const validDiagnose = {
  diagnosis: "Kemungkinan ekstraksi kurang.",
  likely_causes: ["Suhu air mungkin terlalu rendah."],
  suggestions: [{ variable: "water_temp_c", from: 92, to: 94, reason: "Coba naikkan sedikit." }],
  note: "Coba satu perubahan dahulu.",
};

Deno.test("keluaran recommend dan diagnose sah", () => {
  if (!parseOutput("recommend", JSON.stringify(validRecommend), 3) || !parseOutput("diagnose", JSON.stringify(validDiagnose))) throw new Error("valid output rejected");
});

Deno.test("jumlah tahap recommend harus sama dengan pouring_count", () => {
  const output = JSON.stringify(validRecommend);
  if (!parseOutput("recommend", output, 3)) throw new Error("matching stage count rejected");
  if (parseOutput("recommend", output, 2)) throw new Error("extra stage accepted");
  if (parseOutput("recommend", output, 4)) throw new Error("missing stage accepted");
});

Deno.test("jumlah tahap salah memicu retry tanpa menambah ai_usage", async () => {
  const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve");
  const originalFetch = globalThis.fetch;
  const names = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "LLM_API_KEY", "AI_MODEL"];
  const previous = names.map((name) => Deno.env.get(name));
  let handler: ((request: Request) => Response | Promise<Response>) | undefined;
  let usageCalls = 0;
  let modelCalls = 0;
  const prompts: string[] = [];
  const mimeTypes: string[] = [];
  const hasResponseSchema: boolean[] = [];
  try {
    Object.defineProperty(Deno, "serve", { configurable: true, value: (callback: typeof handler) => { handler = callback; } });
    for (const name of names) Deno.env.set(name, "test-value");
    Deno.env.set("SUPABASE_URL", "https://example.test");
    globalThis.fetch = async (input, init) => {
      const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
      if (url.pathname === "/rest/v1/sessions") return Response.json([{ user_id: "11111111-1111-4111-8111-111111111111", expires_at: "2099-01-01T00:00:00Z" }]);
      if (url.pathname === "/rest/v1/rpc/increment_ai_usage") { usageCalls++; return Response.json(1); }
      if (url.pathname.endsWith(":generateContent")) {
        modelCalls++;
        const body = JSON.parse(String(init?.body));
        prompts.push(body.systemInstruction.parts[0].text);
        mimeTypes.push(body.generationConfig.responseMimeType);
        hasResponseSchema.push(Object.hasOwn(body.generationConfig, "responseSchema"));
        const output = structuredClone(validRecommend);
        if (modelCalls === 2) {
          output.stages.pop();
          output.stages[1].water_cum_g = 240;
        }
        return Response.json({ candidates: [{ content: { parts: [{ text: JSON.stringify(output) }] } }] });
      }
      throw new Error(`Unexpected request: ${url.pathname}`);
    };
    await import("./index.ts");
    if (!handler) throw new Error("AI handler was not registered");
    const response = await handler(new Request("https://example.test/ai", {
      method: "POST", headers: { "x-session-token": "test-session" },
      body: JSON.stringify({ type: "recommend", payload: { bean: { name: "Biji", species: "arabika" }, history: [], pouring_count: 2 } }),
    }));
    const result = await response.json();
    if (response.status !== 200 || usageCalls !== 1 || modelCalls !== 2 || !parseOutput("recommend", JSON.stringify(result), 2)) {
      throw new Error(`retry flow failed: status=${response.status}, usage=${usageCalls}, model=${modelCalls}`);
    }
    const requiredRules = [
      "tepat dose_g, ratio, water_temp_c, grind, stages, note; tanpa key tambahan",
      "dose_g harus angka 5 sampai 60; ratio angka 10 sampai 20; water_temp_c bilangan bulat 80 sampai 100",
      "sangat_halus, halus, sedang_halus, sedang, sedang_kasar, kasar",
      "note harus teks tidak kosong, maksimal 500 karakter",
      "stages harus berisi tepat 2 tahap. Nama tahap harus berurutan persis: bloom, pouring_2",
      "hanya memiliki key name, start_s, duration_s, water_cum_g; tanpa key tambahan",
      "start_s dan duration_s harus bilangan bulat",
      "start_s tahap pertama 0 sampai 3600",
      "setiap start_s berikutnya minimal akhir tahap sebelumnya (start_s sebelumnya + duration_s sebelumnya) dan maksimal 3600",
      "duration_s setiap tahap 1 sampai 3600",
      "water_cum_g harus angka yang meningkat secara ketat",
      "lebih dari 0 dan maksimal 1200 gram",
      "water_cum_g tahap terakhir harus sama dengan dose_g * ratio dengan selisih maksimal 1 gram",
      "Gunakan angka JSON untuk semua nilai numerik, bukan string",
    ];
    if (prompts.length !== 2 || prompts.some((prompt) => requiredRules.some((rule) => !prompt.includes(rule))) ||
      mimeTypes.some((mimeType) => mimeType !== "application/json") || hasResponseSchema.some(Boolean)) throw new Error("Gemini request does not match validator rules");
  } finally {
    if (originalServe) Object.defineProperty(Deno, "serve", originalServe);
    else Reflect.deleteProperty(Deno, "serve");
    globalThis.fetch = originalFetch;
    names.forEach((name, index) => previous[index] === undefined ? Deno.env.delete(name) : Deno.env.set(name, previous[index]));
  }
});

Deno.test("total air terakhir harus sama dengan dose kali ratio", () => {
  const value = structuredClone(validRecommend);
  value.stages[2].water_cum_g = 230;
  if (parseOutput("recommend", JSON.stringify(value), 3)) throw new Error("water mismatch accepted");
});

Deno.test("suhu di luar batas ditolak", () => {
  if (parseOutput("recommend", JSON.stringify({ ...validRecommend, water_temp_c: 101 }), 3)) throw new Error("temperature accepted");
});

Deno.test("variable asing ditolak", () => {
  const value = { ...validDiagnose, suggestions: [{ variable: "cost_idr", from: 1, to: 2, reason: "Coba." }] };
  if (parseOutput("diagnose", JSON.stringify(value))) throw new Error("foreign variable accepted");
});

Deno.test("nama tahap yang salah ditolak", () => {
  const value = structuredClone(validRecommend);
  value.stages[1].name = "pouring_5";
  if (parseOutput("recommend", JSON.stringify(value), 3)) throw new Error("wrong stage accepted");
});

Deno.test("teks bukan JSON ditolak", () => {
  if (parseOutput("recommend", "mulai dengan air panas", 3)) throw new Error("non-JSON accepted");
});

Deno.test("input diagnosa memakai brew tunggal dan memotong catatan", () => {
  const input = validateInput({ type: "diagnose", payload: {
    bean: { name: "Biji", species: "arabika" }, history: [],
    brew: { dose_g: 15, ratio: 16, water_temp_c: 92, grind: "sedang", taste_score: 3,
      taste_tags: "asam", notes: "x".repeat(700), stages: [{ position: 1, name: "bloom",
        target_start_s: 0, target_duration_s: 40, target_water_cum_g: 45, target_pour_g: 45,
        actual_start_s: null, actual_duration_s: null, actual_water_g: 43, drawdown_s: null }] },
  } });
  if (!input || ((input.payload.brew as Record<string, unknown>).notes as string).length !== 500) throw new Error("input invalid");
});

Deno.test("riwayat lebih dari lima ditolak", () => {
  const input = { type: "recommend", payload: { bean: { name: "Biji", species: "arabika" },
    history: Array(6).fill({ dose_g: 15, ratio: 16, water_temp_c: 92, grind: "sedang", taste_score: 3, taste_tags: "asam" }),
    pouring_count: 3 } };
  if (validateInput(input)) throw new Error("long history accepted");
});
