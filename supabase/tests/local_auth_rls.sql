-- Run against a disposable database after migrations: psql -v ON_ERROR_STOP=1 -f supabase/tests/local_auth_rls.sql
-- The transaction rolls back all fixture rows and changes.
BEGIN;

INSERT INTO public.users (id, username, password_hash, salt, iterations, algo)
VALUES
  ('00000000-0000-4000-8000-000000000001', 'rls_test_one', 'fixture', 'fixture', 600000, 'pbkdf2-hmac-sha256'),
  ('00000000-0000-4000-8000-000000000002', 'rls_test_two', 'fixture', 'fixture', 600000, 'pbkdf2-hmac-sha256');

INSERT INTO public.sessions (id, user_id, token_hash, expires_at)
VALUES
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'rls_token_one', now() + interval '1 day'),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000002', 'rls_token_two', now() + interval '1 day');

SET LOCAL ROLE anon;
SET LOCAL request.headers = '{}';

DO $$
DECLARE row_count integer;
BEGIN
  SELECT count(*) INTO row_count FROM public.users;
  IF row_count <> 0 THEN RAISE EXCEPTION 'users visible without header'; END IF;
  SELECT count(*) INTO row_count FROM public.sessions;
  IF row_count <> 0 THEN RAISE EXCEPTION 'sessions visible without header'; END IF;

  BEGIN
    EXECUTE 'SELECT * FROM public.sessions';
    RAISE EXCEPTION 'sessions wildcard SELECT unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    EXECUTE 'DELETE FROM public.sessions WHERE token_hash = ''rls_token_one''';
    RAISE EXCEPTION 'session DELETE unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    EXECUTE 'DELETE FROM public.users WHERE username = ''rls_test_one''';
    RAISE EXCEPTION 'user DELETE unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    EXECUTE 'UPDATE public.users SET username = ''changed'' WHERE username = ''rls_test_one''';
    RAISE EXCEPTION 'user UPDATE unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

SET LOCAL request.headers = '{"x-login-username":"wrong","x-token-hash":"wrong"}';
DO $$
DECLARE row_count integer;
BEGIN
  SELECT count(*) INTO row_count FROM public.users;
  IF row_count <> 0 THEN RAISE EXCEPTION 'users visible with wrong header'; END IF;
  SELECT count(*) INTO row_count FROM public.sessions;
  IF row_count <> 0 THEN RAISE EXCEPTION 'sessions visible with wrong header'; END IF;
  UPDATE public.sessions SET revoked = true WHERE token_hash = 'rls_token_one';
  GET DIAGNOSTICS row_count = ROW_COUNT;
  IF row_count <> 0 THEN RAISE EXCEPTION 'session changed with wrong header'; END IF;
END $$;

SET LOCAL request.headers = '{"x-login-username":"rls_test_one","x-token-hash":"rls_token_one"}';
DO $$
DECLARE row_count integer;
BEGIN
  SELECT count(*) INTO row_count FROM public.users;
  IF row_count <> 1 THEN RAISE EXCEPTION 'own user not uniquely visible'; END IF;
  SELECT count(*) INTO row_count FROM public.sessions;
  IF row_count <> 1 THEN RAISE EXCEPTION 'own session not uniquely visible'; END IF;

  UPDATE public.sessions SET revoked = true WHERE token_hash = 'rls_token_two';
  GET DIAGNOSTICS row_count = ROW_COUNT;
  IF row_count <> 0 THEN RAISE EXCEPTION 'other session changed'; END IF;

  BEGIN
    UPDATE public.sessions SET revoked = false WHERE token_hash = 'rls_token_one';
    RAISE EXCEPTION 'revoked=false unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  UPDATE public.sessions SET revoked = true WHERE token_hash = 'rls_token_one';
  GET DIAGNOSTICS row_count = ROW_COUNT;
  IF row_count <> 1 THEN RAISE EXCEPTION 'own session not revoked'; END IF;
END $$;

-- Registration constraints and the SELECT policy needed by PostgREST return=representation.
DO $$
DECLARE new_id uuid;
BEGIN
  PERFORM set_config('request.headers', '{"x-login-username":"invalid-name"}', true);
  BEGIN
    INSERT INTO public.users (username, password_hash, salt, iterations, algo)
    VALUES ('invalid-name', 'fixture', 'fixture', 600000, 'pbkdf2-hmac-sha256');
    RAISE EXCEPTION 'invalid username unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('request.headers', '{"x-login-username":"rls_bad_algo"}', true);
  BEGIN
    INSERT INTO public.users (username, password_hash, salt, iterations, algo)
    VALUES ('rls_bad_algo', 'fixture', 'fixture', 600000, 'other');
    RAISE EXCEPTION 'invalid algorithm unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('request.headers', '{"x-login-username":"rls_bad_iterations"}', true);
  BEGIN
    INSERT INTO public.users (username, password_hash, salt, iterations, algo)
    VALUES ('rls_bad_iterations', 'fixture', 'fixture', 1, 'pbkdf2-hmac-sha256');
    RAISE EXCEPTION 'invalid iterations unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('request.headers', '{"x-login-username":"wrong"}', true);
  BEGIN
    INSERT INTO public.users (username, password_hash, salt, iterations, algo)
    VALUES ('rls_return_mismatch', 'fixture', 'fixture', 600000, 'pbkdf2-hmac-sha256')
    RETURNING id INTO new_id;
    RAISE EXCEPTION 'RETURNING unexpectedly succeeded with wrong header';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('request.headers', '{"x-login-username":"rls_return_match"}', true);
  INSERT INTO public.users (username, password_hash, salt, iterations, algo)
  VALUES ('rls_return_match', 'fixture', 'fixture', 600000, 'pbkdf2-hmac-sha256')
  RETURNING id INTO new_id;
  IF new_id IS NULL THEN RAISE EXCEPTION 'RETURNING failed with matching header'; END IF;
END $$;

-- Session inserts: revoked must stay false and expiry must be within seven days.
DO $$
DECLARE row_count integer;
BEGIN
  BEGIN
    INSERT INTO public.sessions (user_id, token_hash, expires_at, revoked)
    VALUES ('00000000-0000-4000-8000-000000000001', 'rls_insert_revoked', now() + interval '1 day', true);
    RAISE EXCEPTION 'revoked session unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.sessions (user_id, token_hash, expires_at)
    VALUES ('00000000-0000-4000-8000-000000000001', 'rls_insert_late', now() + interval '8 days');
    RAISE EXCEPTION 'late session unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.sessions (user_id, token_hash, expires_at)
    VALUES ('00000000-0000-4000-8000-000000000001', 'rls_insert_past', now() - interval '1 minute');
    RAISE EXCEPTION 'expired session unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  INSERT INTO public.sessions (user_id, token_hash, expires_at)
  VALUES ('00000000-0000-4000-8000-000000000001', 'rls_insert_valid', now() + interval '1 day');
  GET DIAGNOSTICS row_count = ROW_COUNT;
  IF row_count <> 1 THEN RAISE EXCEPTION 'valid session insert failed'; END IF;
END $$;

RESET ROLE;
DO $$
BEGIN
  IF NOT (SELECT revoked FROM public.sessions WHERE token_hash = 'rls_token_one') THEN
    RAISE EXCEPTION 'own session revoke not persisted';
  END IF;
  IF (SELECT revoked FROM public.sessions WHERE token_hash = 'rls_token_two') THEN
    RAISE EXCEPTION 'other session changed';
  END IF;
  IF NOT has_table_privilege('service_role', 'public.sessions', 'SELECT') THEN
    RAISE EXCEPTION 'service_role lost session read access';
  END IF;
END $$;

ROLLBACK;
