import { hashSessionToken } from "../_shared/auth.ts";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

Deno.serve(async (request) => {
  try {
    return await handleRequest(request);
  } catch (_) {
    console.error("Terjadi kegagalan internal pada auth-logout.");
    return errorResponse(500, "server_error", "Logout gagal. Coba lagi.");
  }
});

async function handleRequest(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return errorResponse(400, "invalid_request", "Permintaan harus memakai POST.");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Environment database Edge Function tidak tersedia.");
    return errorResponse(
      500,
      "server_configuration_error",
      "Server belum siap. Coba lagi nanti.",
    );
  }

  const sessionToken = request.headers.get("x-session-token")?.trim() ?? "";
  if (!sessionToken) {
    return successResponse(request, null);
  }

  const startedAt = performance.now();
  const tokenHash = await hashSessionToken(sessionToken);
  const durationMs = Math.round((performance.now() - startedAt) * 100) / 100;
  console.info(JSON.stringify({
    event: "logout_session_token_hash_completed",
    duration_ms: durationMs,
  }));

  const response = await fetch(
    `${supabaseUrl}/rest/v1/sessions` +
      `?token_hash=eq.${encodeURIComponent(tokenHash)}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({ revoked: true }),
    },
  );

  if (!response.ok) {
    console.error("Gagal mencabut session saat logout.");
    return errorResponse(500, "server_error", "Logout gagal. Coba lagi.");
  }

  return successResponse(request, durationMs);
}

function successResponse(request: Request, durationMs: number | null): Response {
  const body: Record<string, unknown> = { ok: true };
  if (request.headers.get("x-debug-timing") === "1" && durationMs !== null) {
    body.duration_ms = durationMs;
  }
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: jsonHeaders,
  });
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  details: Record<string, unknown> = {},
): Response {
  return new Response(
    JSON.stringify({ error: { code, message, details } }),
    { status, headers: jsonHeaders },
  );
}
