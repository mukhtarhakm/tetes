CREATE TABLE public.beans (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  name text NOT NULL,
  species text NOT NULL,
  bean_type text,
  arabica_percent integer,
  roastery text,
  is_self_roasted boolean NOT NULL DEFAULT false,
  origin text,
  process text,
  process_custom text,
  roast_level text,
  roast_date date,
  pack_size_g double precision,
  price_original double precision,
  currency text,
  fx_rate double precision,
  fx_date date,
  price_idr_per_kg double precision,
  initial_stock_g double precision NOT NULL DEFAULT 0,
  roastery_notes_tags text,
  roastery_notes_text text,
  best_brew_id uuid,
  archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE public.brews (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  seq integer NOT NULL,
  bean_id uuid NOT NULL REFERENCES public.beans(id),
  brewed_at_utc timestamptz NOT NULL,
  brewed_at_text text NOT NULL,
  dose_g double precision NOT NULL,
  ratio double precision NOT NULL,
  water_temp_c integer NOT NULL,
  grind text NOT NULL,
  total_time_s integer NOT NULL,
  taste_score integer NOT NULL,
  taste_tags text NOT NULL,
  notes text,
  ai_advice text,
  cost_idr double precision,
  status text NOT NULL DEFAULT 'aktif',
  prev_hash text NOT NULL,
  hash text NOT NULL,
  created_at timestamptz NOT NULL,
  UNIQUE (user_id, seq)
);

CREATE TABLE public.brew_stages (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  brew_id uuid NOT NULL REFERENCES public.brews(id),
  position integer NOT NULL,
  name text NOT NULL,
  target_start_s integer NOT NULL,
  target_duration_s integer NOT NULL,
  target_water_cum_g double precision NOT NULL,
  target_pour_g double precision NOT NULL,
  actual_start_s integer,
  actual_duration_s integer,
  actual_water_g double precision,
  drawdown_s integer
);

CREATE INDEX idx_brews_bean ON public.brews(bean_id);
CREATE INDEX idx_stages_brew ON public.brew_stages(brew_id, position);
ALTER TABLE public.beans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brew_stages ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.upsert_sync_bean(p_user_id uuid, p_bean jsonb)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_owner uuid;
BEGIN
  SELECT user_id INTO v_owner FROM public.beans WHERE id = (p_bean->>'id')::uuid FOR UPDATE;
  IF v_owner IS NOT NULL AND v_owner <> p_user_id THEN RETURN 'not_owner'; END IF;
  INSERT INTO public.beans (
    id,user_id,name,species,bean_type,arabica_percent,roastery,is_self_roasted,origin,process,
    process_custom,roast_level,roast_date,pack_size_g,price_original,currency,fx_rate,fx_date,
    price_idr_per_kg,initial_stock_g,roastery_notes_tags,roastery_notes_text,best_brew_id,
    archived,created_at,updated_at
  ) VALUES (
    (p_bean->>'id')::uuid,p_user_id,p_bean->>'name',p_bean->>'species',p_bean->>'bean_type',
    (p_bean->>'arabica_percent')::integer,p_bean->>'roastery',(p_bean->>'is_self_roasted')::boolean,
    p_bean->>'origin',p_bean->>'process',p_bean->>'process_custom',p_bean->>'roast_level',
    (p_bean->>'roast_date')::date,(p_bean->>'pack_size_g')::double precision,
    (p_bean->>'price_original')::double precision,p_bean->>'currency',
    (p_bean->>'fx_rate')::double precision,(p_bean->>'fx_date')::date,
    (p_bean->>'price_idr_per_kg')::double precision,(p_bean->>'initial_stock_g')::double precision,
    p_bean->>'roastery_notes_tags',p_bean->>'roastery_notes_text',
    (p_bean->>'best_brew_id')::uuid,(p_bean->>'archived')::boolean,
    (p_bean->>'created_at')::timestamptz,(p_bean->>'updated_at')::timestamptz
  ) ON CONFLICT (id) DO UPDATE SET
    name=EXCLUDED.name,species=EXCLUDED.species,bean_type=EXCLUDED.bean_type,
    arabica_percent=EXCLUDED.arabica_percent,roastery=EXCLUDED.roastery,
    is_self_roasted=EXCLUDED.is_self_roasted,origin=EXCLUDED.origin,process=EXCLUDED.process,
    process_custom=EXCLUDED.process_custom,roast_level=EXCLUDED.roast_level,
    roast_date=EXCLUDED.roast_date,pack_size_g=EXCLUDED.pack_size_g,
    price_original=EXCLUDED.price_original,currency=EXCLUDED.currency,fx_rate=EXCLUDED.fx_rate,
    fx_date=EXCLUDED.fx_date,price_idr_per_kg=EXCLUDED.price_idr_per_kg,
    initial_stock_g=EXCLUDED.initial_stock_g,roastery_notes_tags=EXCLUDED.roastery_notes_tags,
    roastery_notes_text=EXCLUDED.roastery_notes_text,best_brew_id=EXCLUDED.best_brew_id,
    archived=EXCLUDED.archived,updated_at=EXCLUDED.updated_at
  WHERE public.beans.user_id = p_user_id AND EXCLUDED.updated_at >= public.beans.updated_at;
  IF NOT FOUND AND EXISTS (SELECT 1 FROM public.beans WHERE id=(p_bean->>'id')::uuid AND user_id<>p_user_id)
    THEN RETURN 'not_owner';
  END IF;
  RETURN 'accepted';
END;
$$;

CREATE FUNCTION public.insert_brew_with_stages(p_user_id uuid, p_brew jsonb, p_stages jsonb)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_seq integer; v_hash text;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 0));
  SELECT seq, hash INTO v_seq, v_hash FROM public.brews WHERE user_id=p_user_id ORDER BY seq DESC LIMIT 1;
  IF (p_brew->>'seq')::integer <> COALESCE(v_seq,0)+1
     OR p_brew->>'prev_hash' <> COALESCE(v_hash,'0') THEN RETURN 'chain_broken'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.beans WHERE id=(p_brew->>'bean_id')::uuid AND user_id=p_user_id)
    THEN RETURN 'not_owner'; END IF;
  INSERT INTO public.brews (
    id,user_id,seq,bean_id,brewed_at_utc,brewed_at_text,dose_g,ratio,water_temp_c,grind,
    total_time_s,taste_score,taste_tags,notes,ai_advice,cost_idr,status,prev_hash,hash,created_at
  ) VALUES (
    (p_brew->>'id')::uuid,p_user_id,(p_brew->>'seq')::integer,(p_brew->>'bean_id')::uuid,
    (p_brew->>'brewed_at_utc')::timestamptz,p_brew->>'brewed_at_utc',
    (p_brew->>'dose_g')::double precision,(p_brew->>'ratio')::double precision,
    (p_brew->>'water_temp_c')::integer,p_brew->>'grind',(p_brew->>'total_time_s')::integer,
    (p_brew->>'taste_score')::integer,p_brew->>'taste_tags',p_brew->>'notes',
    p_brew->>'ai_advice',(p_brew->>'cost_idr')::double precision,p_brew->>'status',
    p_brew->>'prev_hash',p_brew->>'hash',(p_brew->>'created_at')::timestamptz
  );
  INSERT INTO public.brew_stages (
    id,user_id,brew_id,position,name,target_start_s,target_duration_s,target_water_cum_g,
    target_pour_g,actual_start_s,actual_duration_s,actual_water_g,drawdown_s
  ) SELECT
    (stage.value->>'id')::uuid,p_user_id,(p_brew->>'id')::uuid,(stage.value->>'position')::integer,stage.value->>'name',
    (stage.value->>'target_start_s')::integer,(stage.value->>'target_duration_s')::integer,
    (stage.value->>'target_water_cum_g')::double precision,(stage.value->>'target_pour_g')::double precision,
    (stage.value->>'actual_start_s')::integer,(stage.value->>'actual_duration_s')::integer,
    (stage.value->>'actual_water_g')::double precision,(stage.value->>'drawdown_s')::integer
  FROM pg_catalog.jsonb_array_elements(p_stages) AS stage(value);
  RETURN 'accepted';
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_sync_bean(uuid,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.insert_brew_with_stages(uuid,jsonb,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_sync_bean(uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.insert_brew_with_stages(uuid,jsonb,jsonb) TO service_role;
