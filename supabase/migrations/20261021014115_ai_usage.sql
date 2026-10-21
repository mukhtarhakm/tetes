CREATE TABLE public.ai_usage (
  user_id uuid NOT NULL REFERENCES public.users(id),
  window_start timestamptz NOT NULL,
  call_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, window_start)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.increment_ai_usage(
  p_user_id uuid,
  p_window_start timestamptz,
  p_limit integer
)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.ai_usage (user_id, window_start, call_count)
  VALUES (p_user_id, p_window_start, 1)
  ON CONFLICT (user_id, window_start)
  DO UPDATE SET call_count = LEAST(public.ai_usage.call_count + 1, p_limit + 1)
  RETURNING call_count;
$$;

REVOKE ALL ON FUNCTION public.increment_ai_usage(uuid, timestamptz, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.increment_ai_usage(uuid, timestamptz, integer) FROM anon;
REVOKE ALL ON FUNCTION public.increment_ai_usage(uuid, timestamptz, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.increment_ai_usage(uuid, timestamptz, integer) TO service_role;
