CREATE TABLE public.events (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  name text NOT NULL,
  event_type text,
  location text,
  notes text,
  start_utc timestamptz NOT NULL,
  source_zone text NOT NULL,
  reminder_minutes text NOT NULL,
  notif_base_id integer,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  server_updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.game_scores (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  level integer NOT NULL,
  accuracy double precision NOT NULL,
  stars integer NOT NULL,
  duration_s integer NOT NULL,
  played_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  server_updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.feedback (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  suggestion text,
  impression text,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  server_updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_events_user_updated ON public.events(user_id, updated_at);
CREATE INDEX idx_scores_user_updated ON public.game_scores(user_id, updated_at);
CREATE INDEX idx_feedback_user_updated ON public.feedback(user_id, updated_at);
CREATE INDEX idx_events_pull ON public.events(user_id, server_updated_at, id);
CREATE INDEX idx_scores_pull ON public.game_scores(user_id, server_updated_at, id);
CREATE INDEX idx_feedback_pull ON public.feedback(user_id, server_updated_at, id);
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.upsert_sync_event(p_user_id uuid, p_event jsonb)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_existing public.events%ROWTYPE;
BEGIN
  SELECT * INTO v_existing FROM public.events
    WHERE id = (p_event->>'id')::uuid FOR UPDATE;
  IF v_existing.id IS NOT NULL AND v_existing.user_id <> p_user_id THEN RETURN 'not_owner'; END IF;
  IF v_existing.id IS NOT NULL AND (p_event->>'updated_at')::timestamptz <= v_existing.updated_at THEN
    IF (p_event->>'updated_at')::timestamptz = v_existing.updated_at AND
       p_event->>'name' = v_existing.name AND
       (p_event->>'event_type') IS NOT DISTINCT FROM v_existing.event_type AND
       (p_event->>'location') IS NOT DISTINCT FROM v_existing.location AND
       (p_event->>'notes') IS NOT DISTINCT FROM v_existing.notes AND
       (p_event->>'start_utc')::timestamptz = v_existing.start_utc AND
       p_event->>'source_zone' = v_existing.source_zone AND
       p_event->>'reminder_minutes' = v_existing.reminder_minutes AND
       (p_event->>'deleted')::boolean = v_existing.deleted THEN
      UPDATE public.events SET server_updated_at=now() WHERE id=v_existing.id;
      RETURN 'accepted';
    END IF;
    RETURN 'stale';
  END IF;
  INSERT INTO public.events (id,user_id,name,event_type,location,notes,start_utc,source_zone,
    reminder_minutes,deleted,created_at,updated_at)
  VALUES ((p_event->>'id')::uuid,p_user_id,p_event->>'name',p_event->>'event_type',
    p_event->>'location',p_event->>'notes',(p_event->>'start_utc')::timestamptz,
    p_event->>'source_zone',p_event->>'reminder_minutes',(p_event->>'deleted')::boolean,
    (p_event->>'created_at')::timestamptz,(p_event->>'updated_at')::timestamptz)
  ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name,event_type=EXCLUDED.event_type,
    location=EXCLUDED.location,notes=EXCLUDED.notes,start_utc=EXCLUDED.start_utc,
    source_zone=EXCLUDED.source_zone,reminder_minutes=EXCLUDED.reminder_minutes,
    deleted=EXCLUDED.deleted,updated_at=EXCLUDED.updated_at,server_updated_at=now()
  WHERE public.events.user_id=p_user_id AND EXCLUDED.updated_at>public.events.updated_at;
  IF NOT FOUND THEN RETURN 'stale'; END IF;
  RETURN 'accepted';
END;
$$;

CREATE FUNCTION public.insert_sync_score(p_user_id uuid, p_score jsonb)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_owner uuid; v_same boolean;
BEGIN
  INSERT INTO public.game_scores(id,user_id,level,accuracy,stars,duration_s,played_at,created_at,updated_at)
  VALUES ((p_score->>'id')::uuid,p_user_id,(p_score->>'level')::integer,
    (p_score->>'accuracy')::double precision,(p_score->>'stars')::integer,
    (p_score->>'duration_s')::integer,(p_score->>'played_at')::timestamptz,
    (p_score->>'played_at')::timestamptz,(p_score->>'played_at')::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  IF FOUND THEN RETURN 'accepted'; END IF;
  SELECT user_id, level=(p_score->>'level')::integer AND accuracy=(p_score->>'accuracy')::double precision
    AND stars=(p_score->>'stars')::integer AND duration_s=(p_score->>'duration_s')::integer
    AND played_at=(p_score->>'played_at')::timestamptz
    INTO v_owner,v_same FROM public.game_scores WHERE id=(p_score->>'id')::uuid;
  IF v_owner <> p_user_id THEN RETURN 'not_owner'; END IF;
  RETURN CASE WHEN v_same THEN 'accepted' ELSE 'immutable' END;
END;
$$;

CREATE FUNCTION public.insert_sync_feedback(p_user_id uuid, p_feedback jsonb)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_owner uuid; v_same boolean;
BEGIN
  INSERT INTO public.feedback(id,user_id,suggestion,impression,created_at,updated_at)
  VALUES ((p_feedback->>'id')::uuid,p_user_id,p_feedback->>'suggestion',p_feedback->>'impression',
    (p_feedback->>'created_at')::timestamptz,(p_feedback->>'created_at')::timestamptz)
  ON CONFLICT (id) DO NOTHING;
  IF FOUND THEN RETURN 'accepted'; END IF;
  SELECT user_id, suggestion IS NOT DISTINCT FROM p_feedback->>'suggestion'
    AND impression IS NOT DISTINCT FROM p_feedback->>'impression'
    AND created_at=(p_feedback->>'created_at')::timestamptz
    INTO v_owner,v_same FROM public.feedback WHERE id=(p_feedback->>'id')::uuid;
  IF v_owner <> p_user_id THEN RETURN 'not_owner'; END IF;
  RETURN CASE WHEN v_same THEN 'accepted' ELSE 'immutable' END;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_sync_event(uuid,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.insert_sync_score(uuid,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.insert_sync_feedback(uuid,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_sync_event(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.insert_sync_score(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.insert_sync_feedback(uuid,jsonb) TO service_role;
