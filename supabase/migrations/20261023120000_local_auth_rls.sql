-- Auth credentials are checked in Flutter; these grants limit the public REST surface.
REVOKE ALL ON TABLE public.users, public.sessions FROM PUBLIC, anon, authenticated;

GRANT SELECT (id, username, password_hash, salt, iterations, algo, created_at)
  ON public.users TO anon;
GRANT INSERT (username, password_hash, salt, iterations, algo)
  ON public.users TO anon;

CREATE POLICY users_anon_login_select ON public.users
  FOR SELECT TO anon
  USING (
    username = (current_setting('request.headers', true)::json ->> 'x-login-username')
  );

CREATE POLICY users_anon_register_insert ON public.users
  FOR INSERT TO anon
  WITH CHECK (
    username ~ '^[a-z0-9._]{3,30}$'
    AND algo = 'pbkdf2-hmac-sha256'
    AND iterations = 600000
  );

GRANT SELECT (token_hash) ON public.sessions TO anon;
GRANT INSERT (user_id, token_hash, expires_at) ON public.sessions TO anon;
GRANT UPDATE (revoked) ON public.sessions TO anon;

CREATE POLICY sessions_anon_token_select ON public.sessions
  FOR SELECT TO anon
  USING (
    token_hash = (current_setting('request.headers', true)::json ->> 'x-token-hash')
  );

CREATE POLICY sessions_anon_insert ON public.sessions
  FOR INSERT TO anon
  WITH CHECK (
    revoked = false
    AND expires_at > now()
    AND expires_at <= now() + interval '7 days'
  );

CREATE POLICY sessions_anon_revoke ON public.sessions
  FOR UPDATE TO anon
  USING (
    token_hash = (current_setting('request.headers', true)::json ->> 'x-token-hash')
  )
  WITH CHECK (revoked = true);

GRANT SELECT ON TABLE public.sessions TO service_role;

DROP FUNCTION public.increment_login_attempt(text, timestamptz);
DROP TABLE public.login_attempts;
