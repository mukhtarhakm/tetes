import {
  base64ToBytes,
  constantTimeEquals,
  createSessionToken,
  derivePasswordHash,
  hashSessionToken,
  PASSWORD_ALGORITHM,
  PASSWORD_HASH_BYTES,
  PBKDF2_ITERATIONS,
  SALT_BYTES,
  SESSION_DURATION_MS,
  validateRegistrationInput,
} from "../_shared/auth.ts";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };
const loginWindowMs = 15 * 60 * 1000;
const maximumFailedAttempts = 5;
const dummySalt = new Uint8Array(SALT_BYTES);
const dummyHash = new Uint8Array(PASSWORD_HASH_BYTES);

type UserRow = {
  id: string;
  username: string;
  password_hash: string;
  salt: string;
  iterations: number;
  algo: string;
  created_at: string;
};

type LoginAttemptRow = {
  attempt_count: number;
};

Deno.serve(async (request) => {
  try {
    return await handleRequest(request);
  } catch (_) {
    console.error("Terjadi kegagalan internal pada auth-login.");
    return errorResponse(500, "server_error", "Login gagal. Coba lagi.");
  }
});

async function handleRequest(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return errorResponse(400, "invalid_request", "Permintaan harus memakai POST.");
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (_) {
    return errorResponse(400, "invalid_json", "Body JSON tidak valid.");
  }

  const validation = validateRegistrationInput(body);
  if (!validation.valid) {
    return errorResponse(
      400,
      "invalid_input",
      "Data login tidak valid.",
      { fields: validation.fields },
    );
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

  const { username, password } = validation.input;
  const nowMs = Date.now();
  const windowStartMs = Math.floor(nowMs / loginWindowMs) * loginWindowMs;
  const windowStart = toUtcSeconds(windowStartMs);
  const databaseHeaders = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
  };

  const attemptResponse = await fetch(
    `${supabaseUrl}/rest/v1/login_attempts` +
      `?username=eq.${encodeURIComponent(username)}` +
      `&window_start=eq.${encodeURIComponent(windowStart)}` +
      "&select=attempt_count&limit=1",
    { headers: databaseHeaders },
  );
  if (!attemptResponse.ok) {
    console.error("Gagal membaca batas percobaan login.");
    return errorResponse(500, "server_error", "Login gagal. Coba lagi.");
  }

  const attempts = await attemptResponse.json() as LoginAttemptRow[];
  if ((attempts[0]?.attempt_count ?? 0) >= maximumFailedAttempts) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((windowStartMs + loginWindowMs - Date.now()) / 1000),
    );
    return errorResponse(
      429,
      "login_rate_limited",
      "Terlalu banyak percobaan login. Coba lagi nanti.",
      { retry_after_s: retryAfterSeconds },
    );
  }

  const userResponse = await fetch(
    `${supabaseUrl}/rest/v1/users` +
      `?username=eq.${encodeURIComponent(username)}` +
      "&select=id,username,password_hash,salt,iterations,algo,created_at&limit=1",
    { headers: databaseHeaders },
  );
  if (!userResponse.ok) {
    console.error("Gagal membaca pengguna saat login.");
    return errorResponse(500, "server_error", "Login gagal. Coba lagi.");
  }

  const users = await userResponse.json() as UserRow[];
  const user = users[0];
  const verification = await verifyPassword(password, user);

  console.info(JSON.stringify({
    event: "login_password_hash_completed",
    duration_ms: verification.durationMs,
    iterations: verification.iterations,
  }));

  if (!verification.matches || !user) {
    const incrementResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/increment_login_attempt`,
      {
        method: "POST",
        headers: databaseHeaders,
        body: JSON.stringify({
          p_username: username,
          p_window_start: windowStart,
        }),
      },
    );
    if (!incrementResponse.ok) {
      console.error("Gagal mencatat percobaan login.");
      return errorResponse(500, "server_error", "Login gagal. Coba lagi.");
    }

    const details = request.headers.get("x-debug-timing") === "1"
      ? { duration_ms: verification.durationMs }
      : {};
    return errorResponse(
      401,
      "invalid_credentials",
      "Username atau password salah",
      details,
    );
  }

  const clearAttemptResponse = await fetch(
    `${supabaseUrl}/rest/v1/login_attempts` +
      `?username=eq.${encodeURIComponent(username)}` +
      `&window_start=eq.${encodeURIComponent(windowStart)}`,
    {
      method: "DELETE",
      headers: { ...databaseHeaders, Prefer: "return=minimal" },
    },
  );
  if (!clearAttemptResponse.ok) {
    console.error("Gagal menghapus percobaan login setelah berhasil.");
    return errorResponse(500, "server_error", "Login gagal. Coba lagi.");
  }

  const sessionToken = createSessionToken();
  const tokenHash = await hashSessionToken(sessionToken);
  const expiresAt = toUtcSeconds(Date.now() + SESSION_DURATION_MS);
  const sessionResponse = await fetch(`${supabaseUrl}/rest/v1/sessions`, {
    method: "POST",
    headers: { ...databaseHeaders, Prefer: "return=minimal" },
    body: JSON.stringify({
      user_id: user.id,
      token_hash: tokenHash,
      expires_at: expiresAt,
    }),
  });
  if (!sessionResponse.ok) {
    console.error("Gagal membuat session setelah login.");
    return errorResponse(500, "server_error", "Login gagal. Coba lagi.");
  }

  const responseBody: Record<string, unknown> = {
    user: {
      id: user.id,
      username: user.username,
      created_at: user.created_at,
    },
    session_token: sessionToken,
    expires_at: expiresAt,
  };
  if (request.headers.get("x-debug-timing") === "1") {
    responseBody.duration_ms = verification.durationMs;
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: jsonHeaders,
  });
}

async function verifyPassword(
  password: string,
  user: UserRow | undefined,
): Promise<{ matches: boolean; durationMs: number; iterations: number }> {
  let salt = dummySalt;
  let expectedHash = dummyHash;
  let iterations = PBKDF2_ITERATIONS;
  let storedParametersValid = false;

  if (
    user?.algo === PASSWORD_ALGORITHM &&
    Number.isInteger(user.iterations) &&
    user.iterations > 0
  ) {
    try {
      const decodedSalt = base64ToBytes(user.salt);
      const decodedHash = base64ToBytes(user.password_hash);
      if (
        decodedSalt.length === SALT_BYTES &&
        decodedHash.length === PASSWORD_HASH_BYTES
      ) {
        salt = decodedSalt;
        expectedHash = decodedHash;
        iterations = user.iterations;
        storedParametersValid = true;
      }
    } catch (_) {
      storedParametersValid = false;
    }
  }

  const startedAt = performance.now();
  const actualHash = await derivePasswordHash(password, salt, iterations);
  const durationMs = Math.round((performance.now() - startedAt) * 100) / 100;
  const matches = constantTimeEquals(actualHash, expectedHash);

  return {
    matches: storedParametersValid && matches,
    durationMs,
    iterations,
  };
}

function toUtcSeconds(timestampMs: number): string {
  return new Date(timestampMs).toISOString().replace(/\.\d{3}Z$/u, "Z");
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
