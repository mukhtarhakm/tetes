import {
  bytesToBase64,
  createSalt,
  createSessionToken,
  derivePasswordHash,
  hashSessionToken,
  PASSWORD_ALGORITHM,
  PBKDF2_ITERATIONS,
  SESSION_DURATION_MS,
  validateRegistrationInput,
} from "../_shared/auth.ts";

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

type DatabaseError = {
  code?: string;
};

type CreatedUser = {
  id: string;
  username: string;
  created_at: string;
};

Deno.serve(async (request) => {
  try {
    return await handleRequest(request);
  } catch (_) {
    console.error("Terjadi kegagalan internal pada auth-register.");
    return errorResponse(500, "server_error", "Pendaftaran gagal. Coba lagi.");
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
      "Data pendaftaran tidak valid.",
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
  const salt = createSalt();
  const hashStartedAt = performance.now();
  const passwordHash = await derivePasswordHash(password, salt);
  const durationMs = Math.round((performance.now() - hashStartedAt) * 100) / 100;
  console.info(JSON.stringify({
    event: "password_hash_completed",
    duration_ms: durationMs,
    iterations: PBKDF2_ITERATIONS,
  }));

  const databaseHeaders = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  };

  const userResponse = await fetch(
    `${supabaseUrl}/rest/v1/users?select=id,username,created_at`,
    {
      method: "POST",
      headers: databaseHeaders,
      body: JSON.stringify({
        username,
        password_hash: bytesToBase64(passwordHash),
        salt: bytesToBase64(salt),
        iterations: PBKDF2_ITERATIONS,
        algo: PASSWORD_ALGORITHM,
      }),
    },
  );

  if (!userResponse.ok) {
    const databaseError = await readDatabaseError(userResponse);
    if (databaseError.code === "23505") {
      return errorResponse(
        409,
        "username_taken",
        "Username sudah digunakan.",
      );
    }
    console.error("Gagal menyimpan pengguna baru.");
    return errorResponse(500, "server_error", "Pendaftaran gagal. Coba lagi.");
  }

  const createdUsers = await userResponse.json() as CreatedUser[];
  const user = createdUsers[0];
  if (!user) {
    console.error("Database tidak mengembalikan pengguna baru.");
    return errorResponse(500, "server_error", "Pendaftaran gagal. Coba lagi.");
  }

  const sessionToken = createSessionToken();
  const tokenHash = await hashSessionToken(sessionToken);
  const expiresAt = new Date(Date.now() + SESSION_DURATION_MS)
    .toISOString()
    .replace(/\.\d{3}Z$/u, "Z");
  const sessionResponse = await fetch(`${supabaseUrl}/rest/v1/sessions`, {
    method: "POST",
    headers: databaseHeaders,
    body: JSON.stringify({
      user_id: user.id,
      token_hash: tokenHash,
      expires_at: expiresAt,
    }),
  });

  if (!sessionResponse.ok) {
    console.error("Gagal membuat session pengguna baru.");
    await removeIncompleteUser(supabaseUrl, databaseHeaders, user.id);
    return errorResponse(500, "server_error", "Pendaftaran gagal. Coba lagi.");
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
    responseBody.duration_ms = durationMs;
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: jsonHeaders,
  });
}

async function readDatabaseError(response: Response): Promise<DatabaseError> {
  try {
    return await response.json() as DatabaseError;
  } catch (_) {
    return {};
  }
}

async function removeIncompleteUser(
  supabaseUrl: string,
  headers: Record<string, string>,
  userId: string,
): Promise<void> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`,
    { method: "DELETE", headers },
  );
  if (!response.ok) {
    console.error("Gagal membersihkan pengguna setelah pembuatan session gagal.");
  }
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
