CREATE OR REPLACE FUNCTION public.increment_login_attempt(
  p_username text,
  p_window_start timestamptz
)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.login_attempts (username, window_start, attempt_count)
  VALUES (p_username, p_window_start, 1)
  ON CONFLICT (username, window_start)
  DO UPDATE
    SET attempt_count = public.login_attempts.attempt_count + 1
  RETURNING attempt_count;
$$;

REVOKE ALL ON FUNCTION public.increment_login_attempt(text, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.increment_login_attempt(text, timestamptz) FROM anon;
REVOKE ALL ON FUNCTION public.increment_login_attempt(text, timestamptz) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.increment_login_attempt(text, timestamptz) TO service_role;
