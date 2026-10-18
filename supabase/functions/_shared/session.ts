import { hashSessionToken } from "./auth.ts";

type SessionRow = {
  user_id: string;
};

export class SessionUnauthorizedError extends Error {
  constructor() {
    super("Session tidak sah.");
    this.name = "SessionUnauthorizedError";
  }
}

// Dipakai oleh sync-push, sync-pull, dan ai untuk memvalidasi session server.
export async function requireValidSession(token: string): Promise<string> {
  if (!token) {
    throw new SessionUnauthorizedError();
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Environment database Edge Function tidak tersedia.");
  }

  const tokenHash = await hashSessionToken(token);
  const now = new Date().toISOString();
  const response = await fetch(
    `${supabaseUrl}/rest/v1/sessions` +
      `?token_hash=eq.${encodeURIComponent(tokenHash)}` +
      "&revoked=is.false" +
      `&expires_at=gt.${encodeURIComponent(now)}` +
      "&select=user_id&limit=1",
    {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error("Gagal memvalidasi session di database.");
  }

  const sessions = await response.json() as SessionRow[];
  const session = sessions[0];
  if (!session) {
    throw new SessionUnauthorizedError();
  }

  return session.user_id;
}
