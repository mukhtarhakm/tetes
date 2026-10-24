CREATE TABLE public.chain_anchors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id),
  seq bigint NOT NULL CHECK (seq > 0),
  head_hash text NOT NULL CHECK (head_hash ~ '^[0-9a-f]{64}$'),
  user_key text NOT NULL CHECK (user_key ~ '^0x[0-9a-f]{64}$'),
  tx_hash text CHECK (tx_hash IS NULL OR tx_hash ~ '^0x[0-9a-f]{64}$'),
  chain_id integer NOT NULL DEFAULT 11155111 CHECK (chain_id = 11155111),
  anchored_at timestamptz NOT NULL DEFAULT now(),
  requested_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'pending', 'confirmed', 'failed')),
  UNIQUE (user_id, seq),
  CHECK (status <> 'pending' OR tx_hash IS NOT NULL)
);

CREATE INDEX chain_anchors_user_requested_idx ON public.chain_anchors (user_id, requested_at DESC);
CREATE UNIQUE INDEX chain_anchors_one_open_per_user ON public.chain_anchors (user_id)
  WHERE status IN ('reserved', 'pending');

ALTER TABLE public.chain_anchors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.chain_anchors FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.chain_anchors TO service_role;

-- Kunci baris users membuat pemeriksaan dan reservasi serial per pengguna.
CREATE FUNCTION public.reserve_chain_anchor(p_user_id uuid, p_user_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_head record;
  v_last public.chain_anchors%ROWTYPE;
  v_open public.chain_anchors%ROWTYPE;
  v_id uuid;
BEGIN
  IF p_user_key !~ '^0x[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid user key';
  END IF;

  PERFORM 1 FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unknown user'; END IF;

  SELECT seq, hash INTO v_head FROM public.brews
  WHERE user_id = p_user_id ORDER BY seq DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('kind', 'no_brews'); END IF;
  IF v_head.hash !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'invalid brew hash'; END IF;

  SELECT * INTO v_last FROM public.chain_anchors
  WHERE user_id = p_user_id AND status = 'confirmed'
  ORDER BY seq DESC LIMIT 1;
  IF FOUND AND v_last.seq >= v_head.seq THEN
    RETURN jsonb_build_object('kind', 'already_anchored', 'seq', v_last.seq, 'tx_hash', v_last.tx_hash);
  END IF;

  SELECT * INTO v_open FROM public.chain_anchors
  WHERE user_id = p_user_id AND status IN ('reserved', 'pending') LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('kind', 'in_progress', 'id', v_open.id, 'seq', v_open.seq,
      'head_hash', v_open.head_hash, 'user_key', v_open.user_key, 'tx_hash', v_open.tx_hash,
      'status', v_open.status, 'requested_at', v_open.requested_at);
  END IF;

  SELECT * INTO v_last FROM public.chain_anchors
  WHERE user_id = p_user_id ORDER BY requested_at DESC LIMIT 1;
  IF FOUND AND v_last.requested_at > now() - interval '5 minutes' THEN
    RETURN jsonb_build_object('kind', 'rate_limited', 'requested_at', v_last.requested_at);
  END IF;

  INSERT INTO public.chain_anchors (user_id, seq, head_hash, user_key)
  VALUES (p_user_id, v_head.seq, v_head.hash, p_user_key)
  ON CONFLICT (user_id, seq) DO UPDATE
    SET status = 'reserved', tx_hash = NULL, requested_at = now(),
      anchored_at = now(), head_hash = EXCLUDED.head_hash, user_key = EXCLUDED.user_key
    WHERE public.chain_anchors.status = 'failed'
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'reservation conflict'; END IF;
  RETURN jsonb_build_object('kind', 'reserved', 'id', v_id, 'seq', v_head.seq,
    'head_hash', v_head.hash, 'user_key', p_user_key, 'tx_hash', NULL,
    'status', 'reserved', 'requested_at', now());
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_chain_anchor(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_chain_anchor(uuid, text) TO service_role;
