-- Quota chat terpisah dari ai_usage; tanggal mengikuti tengah malam Asia/Jakarta.
CREATE TABLE IF NOT EXISTS public.chat_usage (
  user_id uuid NOT NULL REFERENCES public.users(id),
  usage_date date NOT NULL,
  call_count integer NOT NULL DEFAULT 0 CHECK (call_count BETWEEN 0 AND 20),
  PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE public.chat_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.chat_usage FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.chat_usage TO service_role;
COMMENT ON TABLE public.chat_usage IS 'Reservasi kuota chat per pengguna per tanggal Asia/Jakarta.';

-- Satu UPSERT atomik mereservasi maksimal 20 panggilan; baca terpisah hanya saat ditolak.
CREATE OR REPLACE FUNCTION public.increment_chat_usage(p_user_id uuid)
RETURNS TABLE (allowed boolean, used integer, remaining integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_date date := (now() AT TIME ZONE 'Asia/Jakarta')::date;
  v_count integer;
BEGIN
  INSERT INTO public.chat_usage (user_id, usage_date, call_count)
  VALUES (p_user_id, v_date, 1)
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET call_count = public.chat_usage.call_count + 1
  WHERE public.chat_usage.call_count < 20
  RETURNING call_count INTO v_count;

  IF v_count IS NOT NULL THEN
    RETURN QUERY SELECT true, v_count, 20 - v_count;
    RETURN;
  END IF;

  SELECT call_count INTO v_count
  FROM public.chat_usage
  WHERE user_id = p_user_id AND usage_date = v_date;
  RETURN QUERY SELECT false, v_count, 20 - v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_chat_usage(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_chat_usage(uuid) TO service_role;
COMMENT ON FUNCTION public.increment_chat_usage(uuid) IS 'Reservasi satu panggilan chat secara atomik dan kembalikan sisa kuota harian.';

-- Kembalikan satu reservasi saat permintaan gagal setelah diterima.
CREATE OR REPLACE FUNCTION public.refund_chat_usage(p_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE public.chat_usage
  SET call_count = GREATEST(call_count - 1, 0)
  WHERE user_id = p_user_id
    AND usage_date = (now() AT TIME ZONE 'Asia/Jakarta')::date;
$$;

REVOKE ALL ON FUNCTION public.refund_chat_usage(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_chat_usage(uuid) TO service_role;
COMMENT ON FUNCTION public.refund_chat_usage(uuid) IS 'Kembalikan satu reservasi chat gagal pada tanggal Asia/Jakarta saat ini.';
