ALTER TABLE public.brews
  ADD COLUMN custom_taste_tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD CONSTRAINT brews_custom_taste_tags_check CHECK (
    CASE WHEN jsonb_typeof(custom_taste_tags) = 'array'
      THEN jsonb_array_length(custom_taste_tags) <= 3
      ELSE false
    END
  );

CREATE OR REPLACE FUNCTION public.insert_brew_with_stages(p_user_id uuid, p_brew jsonb, p_stages jsonb)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_seq integer; v_hash text; v_custom jsonb;
BEGIN
  v_custom := COALESCE(p_brew->'custom_taste_tags', '[]'::jsonb);
  IF jsonb_typeof(v_custom) <> 'array' THEN
    RAISE EXCEPTION 'invalid custom_taste_tags' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(v_custom) > 3 OR EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_array_elements(v_custom) AS tag(value)
    WHERE jsonb_typeof(tag.value) <> 'string'
      OR pg_catalog.char_length(tag.value #>> '{}') NOT BETWEEN 1 AND 20
  ) THEN
    RAISE EXCEPTION 'invalid custom_taste_tags' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 0));
  SELECT seq, hash INTO v_seq, v_hash FROM public.brews WHERE user_id=p_user_id ORDER BY seq DESC LIMIT 1;
  IF (p_brew->>'seq')::integer <> COALESCE(v_seq,0)+1
     OR p_brew->>'prev_hash' <> COALESCE(v_hash,'0') THEN RETURN 'chain_broken'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.beans WHERE id=(p_brew->>'bean_id')::uuid AND user_id=p_user_id)
    THEN RETURN 'not_owner'; END IF;
  INSERT INTO public.brews (
    id,user_id,seq,bean_id,brewed_at_utc,brewed_at_text,dose_g,ratio,water_temp_c,grind,
    total_time_s,taste_score,taste_tags,custom_taste_tags,notes,ai_advice,cost_idr,status,prev_hash,hash,created_at
  ) VALUES (
    (p_brew->>'id')::uuid,p_user_id,(p_brew->>'seq')::integer,(p_brew->>'bean_id')::uuid,
    (p_brew->>'brewed_at_utc')::timestamptz,p_brew->>'brewed_at_utc',
    (p_brew->>'dose_g')::double precision,(p_brew->>'ratio')::double precision,
    (p_brew->>'water_temp_c')::integer,p_brew->>'grind',(p_brew->>'total_time_s')::integer,
    (p_brew->>'taste_score')::integer,p_brew->>'taste_tags',v_custom,p_brew->>'notes',
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

REVOKE ALL ON FUNCTION public.insert_brew_with_stages(uuid,jsonb,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.insert_brew_with_stages(uuid,jsonb,jsonb) TO service_role;
