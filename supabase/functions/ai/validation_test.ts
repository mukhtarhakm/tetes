import { normalizeOutput, openAiResponseSchema, parseOutput, responseSchemas, validateInput, validateOutput } from "./validation.ts";

const validRecommend = {
  dose_g: 15, ratio: 16, water_temp_c: 92, grind: "sedang",
  stages: [
    { name: "bloom", start_s: 0, duration_s: 40, water_cum_g: 45 },
    { name: "pouring_2", start_s: 40, duration_s: 50, water_cum_g: 140 },
    { name: "pouring_3", start_s: 90, duration_s: 50, water_cum_g: 240 },
  ],
  pouring_count: 3,
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

Deno.test("jumlah tahap recommend mengikuti pouring_count keluaran", () => {
  const output = JSON.stringify(validRecommend);
  if (!parseOutput("recommend", output, 2)) throw new Error("valid output rejected");
  if (parseOutput("recommend", JSON.stringify({ ...validRecommend, pouring_count: 2 }))) throw new Error("mismatched stage count accepted");
  if (parseOutput("recommend", JSON.stringify({ ...validRecommend, pouring_count: 6 }))) throw new Error("out of range count accepted");
});

Deno.test("normalisasi recommend membulatkan waktu dan air akhir tanpa menerima air sebelumnya yang berlebih", () => {
  const value = structuredClone(validRecommend);
  value.stages[0].duration_s = 40.4;
  value.stages[1].start_s = 39.6;
  value.stages[2].water_cum_g = 238;
  const normalized = normalizeOutput("recommend", value);
  if (!validateOutput("recommend", normalized) || (normalized as typeof value).stages[1].start_s !== 40 ||
    (normalized as typeof value).stages[2].water_cum_g !== 240) throw new Error("normalization failed");
  value.stages[1].water_cum_g = 241;
  if (validateOutput("recommend", normalizeOutput("recommend", value))) throw new Error("excess prior water accepted");
});

Deno.test("normalisasi diagnose memangkas teks dan mengubah angka string sebelum validasi", () => {
  const value = { ...validDiagnose, diagnosis: "  Kemungkinan ekstraksi kurang.  ",
    likely_causes: Array(6).fill("  Penyebab mungkin suhu.  "),
    suggestions: Array(3).fill({ variable: "water_temp_c", from: "92", to: "94", reason: "  Coba.  " }) };
  const normalized = normalizeOutput("diagnose", value) as Record<string, unknown>;
  if (!validateOutput("diagnose", normalized) || normalized.diagnosis !== "Kemungkinan ekstraksi kurang." ||
    (normalized.likely_causes as unknown[]).length !== 5 || (normalized.suggestions as unknown[]).length !== 2) throw new Error("diagnose normalization failed");
  if (validateOutput("diagnose", normalizeOutput("diagnose", { ...value, suggestions: [{ variable: "water_temp_c", from: "abc", to: "94", reason: "Coba." }] }))) throw new Error("invalid number accepted");
  if (validateOutput("diagnose", normalizeOutput("diagnose", { ...value, suggestions: [{ variable: "water_temp_c", from: "0x5c", to: "94", reason: "Coba." }] }))) throw new Error("non-decimal number accepted");
});

Deno.test("jumlah tahap salah memicu retry tanpa menambah ai_usage", async () => {
  const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve");
  const originalFetch = globalThis.fetch;
  const names = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "LLM_API_KEY", "AI_MODEL", "AI_PROVIDER"];
  const previous = names.map((name) => Deno.env.get(name));
  let handler: ((request: Request) => Response | Promise<Response>) | undefined;
  let usageCalls = 0;
  let modelCalls = 0;
  const prompts: string[] = [];
  const mimeTypes: string[] = [];
  const configs: Record<string, unknown>[] = [];
  try {
    Object.defineProperty(Deno, "serve", { configurable: true, value: (callback: typeof handler) => { handler = callback; } });
    for (const name of names) Deno.env.set(name, "test-value");
    Deno.env.set("SUPABASE_URL", "https://example.test");
    Deno.env.delete("AI_PROVIDER");
    globalThis.fetch = async (input, init) => {
      const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
      if (url.pathname === "/rest/v1/sessions") return Response.json([{ user_id: "11111111-1111-4111-8111-111111111111", expires_at: "2099-01-01T00:00:00Z" }]);
      if (url.pathname === "/rest/v1/rpc/increment_ai_usage") { usageCalls++; return Response.json(1); }
      if (url.pathname.endsWith(":generateContent")) {
        modelCalls++;
        const body = JSON.parse(String(init?.body));
        prompts.push(body.systemInstruction.parts[0].text);
        mimeTypes.push(body.generationConfig.responseMimeType);
        configs.push(body.generationConfig);
        if (modelCalls === 3) return Response.json({ candidates: [{ content: { parts: [{ text: JSON.stringify(validDiagnose) }] } }] });
        const output = structuredClone(validRecommend);
        if (modelCalls === 1) output.stages.pop();
        if (modelCalls === 2) { output.pouring_count = 2; output.stages.pop(); output.stages[1].water_cum_g = 240; }
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
    if (prompts.length !== 2 || prompts.some((prompt) => !prompt.includes("preferensi pengguna") || !prompt.includes("alasan") || !prompt.includes("pouring_count output")) ||
      mimeTypes.some((mimeType) => mimeType !== "application/json") ||
      configs.some((config) => JSON.stringify(config.responseSchema) !== JSON.stringify(responseSchemas.recommend) || config.maxOutputTokens !== 1024 || Object.hasOwn(config, "thinkingConfig"))) {
      throw new Error("Gemini request does not match schema or prompt");
    }
    const diagnosis = await handler(new Request("https://example.test/ai", {
      method: "POST", headers: { "x-session-token": "test-session" },
      body: JSON.stringify({ type: "diagnose", payload: { bean: { name: "Biji", species: "arabika" }, history: [],
        brew: { dose_g: 15, ratio: 16, water_temp_c: 92, grind: "sedang", taste_score: 3, taste_tags: "asam",
          notes: "Terlalu asam", stages: [{ position: 1, name: "bloom", target_start_s: 0, target_duration_s: 40,
            target_water_cum_g: 45, target_pour_g: 45, actual_start_s: null, actual_duration_s: null,
            actual_water_g: 43, drawdown_s: null }] } } }),
    }));
    if (diagnosis.status !== 200 || usageCalls !== 2 || modelCalls !== 3 ||
      JSON.stringify(configs[2].responseSchema) !== JSON.stringify(responseSchemas.diagnose) ||
      configs[2].maxOutputTokens !== 1024 || Object.hasOwn(configs[2], "thinkingConfig") ||
      !prompts[2].includes("notes pengguna") || !prompts[2].includes("selisih target vs aktual")) {
      throw new Error("diagnose request does not match schema or prompt");
    }
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

Deno.test("OpenAI memakai skema JSON strict untuk semua objek", () => {
  const check = (value: Record<string, unknown>): void => {
    if (Array.isArray(value.anyOf)) {
      for (const item of value.anyOf) check(item as Record<string, unknown>);
      return;
    }
    if (value.type === "object") {
      const properties = value.properties as Record<string, Record<string, unknown>>;
      if (value.additionalProperties !== false ||
        JSON.stringify(value.required) !== JSON.stringify(Object.keys(properties))) throw new Error("non-strict object");
      for (const child of Object.values(properties)) check(child);
    }
    if (value.type === "array") check(value.items as Record<string, unknown>);
  };
  for (const type of ["recommend", "diagnose"] as const) check(openAiResponseSchema(type));
  const recommend = openAiResponseSchema("recommend");
  const properties = recommend.properties as Record<string, Record<string, unknown>>;
  if (properties.pouring_count.minimum !== 1 || properties.pouring_count.maximum !== 5 ||
    (properties.stages.items as Record<string, unknown>).type !== "object") throw new Error("recommend schema bounds missing");
});

Deno.test("OpenAI memilih secret sendiri, retry 429, dan menolak keluaran tidak sah", async () => {
  const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve");
  const originalFetch = globalThis.fetch;
  const originalLog = console.info;
  const names = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "AI_PROVIDER", "LLM_API_KEY", "AI_MODEL",
    "OPENAI_API_KEY", "OPENAI_MODEL", "OPENAI_REASONING_EFFORT"];
  const previous = names.map((name) => Deno.env.get(name));
  let handler: ((request: Request) => Response | Promise<Response>) | undefined;
  let usageCalls = 0;
  let modelCalls = 0;
  let mode: "valid" | "invalid" | "chat" = "valid";
  const requests: Array<{ headers: Headers; body: Record<string, unknown> }> = [];
  const logs: Record<string, unknown>[] = [];
  try {
    Object.defineProperty(Deno, "serve", { configurable: true, value: (callback: typeof handler) => { handler = callback; } });
    Deno.env.set("SUPABASE_URL", "https://example.test");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-secret");
    Deno.env.set("AI_PROVIDER", "openai");
    Deno.env.set("OPENAI_API_KEY", "test-openai-secret");
    Deno.env.set("OPENAI_MODEL", "gpt-5-nano");
    Deno.env.delete("OPENAI_REASONING_EFFORT");
    Deno.env.delete("LLM_API_KEY");
    Deno.env.delete("AI_MODEL");
    console.info = (value) => { logs.push(JSON.parse(String(value))); };
    globalThis.fetch = async (input, init) => {
      const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
      if (url.pathname === "/rest/v1/sessions") return Response.json([{ user_id: "11111111-1111-4111-8111-111111111111", expires_at: "2099-01-01T00:00:00Z" }]);
      if (url.pathname === "/rest/v1/rpc/increment_ai_usage") { usageCalls++; return Response.json(1); }
      if (url.pathname === "/rest/v1/rpc/increment_chat_usage") return Response.json([{ allowed: true, used: 1, remaining: 19 }]);
      if (url.pathname === "/v1/chat/completions") {
        modelCalls++;
        requests.push({ headers: new Headers(init?.headers), body: JSON.parse(String(init?.body)) });
        if (mode === "valid" && modelCalls === 1) return Response.json({}, { status: 429 });
        const content = mode === "chat" ? "Coba suhu 92°C." : JSON.stringify(mode === "invalid"
          ? { ...validRecommend, water_temp_c: 101 } : validRecommend);
        return Response.json({ choices: [{ message: { content }, finish_reason: mode === "invalid" ? "length" : "stop" }] });
      }
      throw new Error(`Unexpected request: ${url.pathname}`);
    };
    await import("./index.ts?openai-test");
    if (!handler) throw new Error("AI handler was not registered");
    const send = (type: "recommend" | "chat") => handler!(new Request("https://example.test/ai", {
      method: "POST", headers: { "x-session-token": "test-session" }, body: JSON.stringify({ type,
        payload: type === "chat" ? { messages: [{ role: "user", content: "Suhu V60?" }] } :
          { bean: { name: "Biji", species: "arabika" }, history: [], pouring_count: 3 } }),
    }));
    let response = await send("recommend");
    if (response.status !== 200 || usageCalls !== 1 || modelCalls !== 2 ||
      !validateOutput("recommend", await response.json())) throw new Error("OpenAI retry or mapping failed");
    for (const request of requests) {
      const format = request.body.response_format as Record<string, unknown>;
      const schema = format.json_schema as Record<string, unknown>;
      if (request.headers.get("Authorization") !== "Bearer test-openai-secret" ||
        request.body.model !== "gpt-5-nano" || request.body.max_completion_tokens !== 2048 ||
        format.type !== "json_schema" || schema.strict !== true ||
        JSON.stringify(schema.schema) !== JSON.stringify(openAiResponseSchema("recommend")) ||
        Object.hasOwn(request.body, "reasoning_effort") || Object.hasOwn(request.body, "temperature") ||
        !JSON.stringify(request.body.messages).includes("<DATA>")) throw new Error("OpenAI request is incorrect");
    }
    mode = "invalid";
    Deno.env.set("OPENAI_REASONING_EFFORT", "minimal");
    response = await send("recommend");
    const error = await response.json();
    if (response.status !== 502 || error.error.code !== "ai_invalid_output" || modelCalls !== 4 ||
      requests.slice(2).some((request) => request.body.reasoning_effort !== "minimal") ||
      !logs.some((log) => log.provider === "openai" && log.finish_reason === "length" && log.candidate_count === 1 && log.part_count === 1)) {
      throw new Error("invalid output, reasoning effort, or metadata failed");
    }
    if (JSON.stringify(logs).includes("test-openai-secret") || JSON.stringify(logs).includes("Biji")) {
      throw new Error("secret or user data leaked to logs");
    }
    mode = "chat";
    Deno.env.delete("OPENAI_REASONING_EFFORT");
    response = await send("chat");
    const chat = await response.json();
    const chatRequest = requests.at(-1)!.body;
    if (response.status !== 200 || chat.reply !== "Coba suhu 92°C." || chatRequest.max_completion_tokens !== 800 ||
      Object.hasOwn(chatRequest, "response_format") || Object.hasOwn(chatRequest, "reasoning_effort")) throw new Error("OpenAI chat request failed");
    Deno.env.delete("OPENAI_API_KEY");
    response = await send("recommend");
    if (response.status !== 500 || (await response.json()).error.code !== "server_configuration_error") throw new Error("missing provider key accepted");
    Deno.env.set("OPENAI_API_KEY", "test-openai-secret");
    Deno.env.delete("OPENAI_MODEL");
    response = await send("recommend");
    if (response.status !== 500 || (await response.json()).error.code !== "server_configuration_error") throw new Error("missing provider model accepted");
    Deno.env.set("OPENAI_MODEL", "gpt-5-nano");
    Deno.env.set("AI_PROVIDER", "unsupported");
    response = await send("recommend");
    if (response.status !== 500 || (await response.json()).error.code !== "server_configuration_error") throw new Error("unknown provider accepted");
  } finally {
    if (originalServe) Object.defineProperty(Deno, "serve", originalServe);
    else Reflect.deleteProperty(Deno, "serve");
    globalThis.fetch = originalFetch;
    console.info = originalLog;
    names.forEach((name, index) => previous[index] === undefined ? Deno.env.delete(name) : Deno.env.set(name, previous[index]));
  }
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
      taste_tags: "asam", custom_taste_tags: [" Teh   Hitam "], notes: "x".repeat(700), stages: [{ position: 1, name: "bloom",
        target_start_s: 0, target_duration_s: 40, target_water_cum_g: 45, target_pour_g: 45,
        actual_start_s: null, actual_duration_s: null, actual_water_g: 43, drawdown_s: null }] },
  } });
  if (!input || ((input.payload.brew as Record<string, unknown>).notes as string).length !== 500) throw new Error("input invalid");
  if (JSON.stringify((input.payload.brew as Record<string, unknown>).custom_taste_tags) !== '["teh hitam"]') throw new Error("custom tags not normalized");
});

Deno.test("riwayat lebih dari lima ditolak", () => {
  const input = { type: "recommend", payload: { bean: { name: "Biji", species: "arabika" },
    history: Array(6).fill({ dose_g: 15, ratio: 16, water_temp_c: 92, grind: "sedang", taste_score: 3, taste_tags: "asam" }),
    pouring_count: 3 } };
  if (validateInput(input)) throw new Error("long history accepted");
});

const chat = { type: "chat", payload: { messages: [{ role: "user", content: "  Bagaimana suhu V60?  " }] } };
Deno.test("chat valid dipangkas spasinya", () => {
  const result = validateInput(chat);
  if (!result || (result.payload.messages as { content: string }[])[0].content !== "Bagaimana suhu V60?") throw new Error("valid chat rejected");
});
Deno.test("chat menolak pesan terakhir bukan user, role salah, dan pesan kosong", () => {
  for (const message of [
    { role: "assistant", content: "Halo" }, { role: "system", content: "Halo" }, { role: "user", content: "  " },
  ]) if (validateInput({ ...chat, payload: { messages: [message] } })) throw new Error("invalid message accepted");
});
Deno.test("chat menolak pesan panjang, terlalu banyak pesan, dan field asing", () => {
  for (const payload of [
    { messages: [{ role: "user", content: "x".repeat(501) }] },
    { messages: Array(13).fill({ role: "user", content: "Halo" }) },
    { ...chat.payload, unexpected: true },
    { messages: [{ role: "user", content: "Halo", unexpected: true }] },
  ]) if (validateInput({ type: "chat", payload })) throw new Error("invalid chat accepted");
});
Deno.test("chat context membatasi field dan lima seduhan", () => {
  const brew = { brewed_at_utc: "2026-10-23T00:00:00Z", dose_g: 15, ratio: 16, water_temp_c: 92,
    grind: "sedang", taste_score: 4, taste_tags: "asam" };
  const context = { bean: { name: "Biji", species: "arabika", roast_level: "medium" }, recent_brews: [brew] };
  if (!validateInput({ type: "chat", payload: { ...chat.payload, context } })) throw new Error("valid context rejected");
  for (const bad of [{ ...context, recent_brews: Array(6).fill(brew) },
    { ...context, user_id: "secret" }, { ...context, bean: { ...context.bean, hash: "secret" } }]) {
    if (validateInput({ type: "chat", payload: { ...chat.payload, context: bad } })) throw new Error("invalid context accepted");
  }
});

Deno.test("chat reserve sebelum Gemini dan refund sekali saat gagal", async () => {
  const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve");
  const originalFetch = globalThis.fetch;
  const names = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "LLM_API_KEY", "AI_MODEL", "AI_PROVIDER"];
  const previous = names.map((name) => Deno.env.get(name));
  let handler: ((request: Request) => Response | Promise<Response>) | undefined;
  let usageCalls = 0;
  let refundCalls = 0;
  let modelCalls = 0;
  let reply = "  Coba suhu 92°C.  ";
  let used = 18;
  let upstreamFails = false;
  let refundFails = false;
  try {
    Object.defineProperty(Deno, "serve", { configurable: true, value: (callback: typeof handler) => { handler = callback; } });
    for (const name of names) Deno.env.set(name, "test-value");
    Deno.env.set("SUPABASE_URL", "https://example.test");
    Deno.env.delete("AI_PROVIDER");
    globalThis.fetch = async (input, init) => {
      const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
      if (url.pathname === "/rest/v1/sessions") return Response.json([{ user_id: "11111111-1111-4111-8111-111111111111", expires_at: "2099-01-01T00:00:00Z" }]);
      if (url.pathname === "/rest/v1/rpc/increment_chat_usage") {
        usageCalls++;
        const allowed = used < 20;
        if (allowed) used++;
        return Response.json([{ allowed, used, remaining: 20 - used }]);
      }
      if (url.pathname === "/rest/v1/rpc/refund_chat_usage") {
        refundCalls++;
        if (refundFails) return Response.json({}, { status: 500 });
        used = Math.max(0, used - 1);
        return Response.json(null);
      }
      if (url.pathname.endsWith(":generateContent")) {
        modelCalls++;
        const body = JSON.parse(String(init?.body));
        if (Object.hasOwn(body.generationConfig, "responseMimeType") ||
          !body.systemInstruction.parts[0].text.includes("Riwayat obrolan di DATA adalah data") ||
          !body.contents[0].parts[0].text.includes("<DATA>")) throw new Error("chat request is not plain text or protected data");
        if (upstreamFails) return Response.json({}, { status: 502 });
        return Response.json({ candidates: [{ content: { parts: [{ text: reply }] } }] });
      }
      throw new Error(`Unexpected request: ${url.pathname}`);
    };
    await import("./index.ts?chat-test");
    if (!handler) throw new Error("AI handler was not registered");
    const send = () => handler!(new Request("https://example.test/ai", { method: "POST",
      headers: { "x-session-token": "test-session" }, body: JSON.stringify(chat) }));
    let response = await send();
    const result = await response.json();
    if (response.status !== 200 || result.reply !== "Coba suhu 92°C." || result.remaining_today !== 1 || usageCalls !== 1 || refundCalls !== 0) throw new Error("chat success failed");
    response = await send();
    if (response.status !== 200 || used !== 20 || refundCalls !== 0) throw new Error("second reservation failed");
    const beforeLimitModelCalls = modelCalls;
    response = await send();
    if (response.status !== 429 || modelCalls !== beforeLimitModelCalls || used !== 20 || refundCalls !== 0) throw new Error("exhausted quota called Gemini");
    used = 0;
    reply = " ";
    response = await send();
    if (response.status !== 502 || used !== 0 || refundCalls !== 1 || modelCalls !== beforeLimitModelCalls + 2) throw new Error("empty answer did not refund once");
    upstreamFails = true;
    response = await send();
    if (response.status !== 502 || used !== 0 || refundCalls !== 2) throw new Error("upstream failure did not refund once");
    refundFails = true;
    response = await send();
    const failedRefund = await response.json();
    if (response.status !== 502 || failedRefund.error.code !== "ai_upstream_error" || refundCalls !== 3) throw new Error("refund failure hid original error");
    refundFails = false;
    upstreamFails = false;
    reply = "Coba suhu 92°C.";
    used = 19;
    const beforeConcurrentModelCalls = modelCalls;
    const concurrent = await Promise.all([send(), send()]);
    if (concurrent.filter((item) => item.status === 200).length !== 1 ||
      concurrent.filter((item) => item.status === 429).length !== 1 ||
      modelCalls !== beforeConcurrentModelCalls + 1 || used !== 20) throw new Error("concurrent reservation exceeded quota");
  } finally {
    if (originalServe) Object.defineProperty(Deno, "serve", originalServe);
    else Reflect.deleteProperty(Deno, "serve");
    globalThis.fetch = originalFetch;
    names.forEach((name, index) => previous[index] === undefined ? Deno.env.delete(name) : Deno.env.set(name, previous[index]));
  }
});
