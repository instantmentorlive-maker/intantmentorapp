-- Payments smoke tests (safe to run in Supabase SQL Editor)
-- This script creates ephemeral test users, initializes profiles/wallets,
-- runs top-up -> reserve -> capture -> partial refund, and prints balances.
-- It uses auth.admin.create_user which requires elevated privileges (SQL Editor has them).

-- Ensure required extension for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper: create a user via whichever Supabase auth function is available
-- Tries in order: auth."admin.create_user" (quoted dotted), auth.admin_create_user, auth.create_user
CREATE OR REPLACE FUNCTION create_test_user(p_email TEXT, p_password TEXT, p_role TEXT)
RETURNS UUID AS $$
DECLARE
  new_uid UUID;
BEGIN
  -- Try: auth."admin.create_user"(jsonb)
  BEGIN
    SELECT (auth."admin.create_user"(
      json_build_object(
        'email', p_email,
        'password', p_password,
        'email_confirm', true,
        'user_metadata', jsonb_build_object('role', p_role)
      )
    )).id INTO new_uid;
    RETURN new_uid;
  EXCEPTION WHEN undefined_function THEN
    -- Try: auth.admin_create_user(jsonb)
    BEGIN
      SELECT (auth.admin_create_user(
        json_build_object(
          'email', p_email,
          'password', p_password,
          'email_confirm', true,
          'user_metadata', jsonb_build_object('role', p_role)
        )
      )).id INTO new_uid;
      RETURN new_uid;
    EXCEPTION WHEN undefined_function THEN
      -- Try: auth.create_user(jsonb)
      BEGIN
        SELECT (auth.create_user(
          json_build_object(
            'email', p_email,
            'password', p_password,
            'email_confirm', true,
            'user_metadata', jsonb_build_object('role', p_role)
          )
        )).id INTO new_uid;
        RETURN new_uid;
      EXCEPTION WHEN undefined_function THEN
        RETURN NULL; -- Not available in this project/version
      END;
    END;
  END;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$
DECLARE
  s_uid UUID;  -- student
  m_uid UUID;  -- mentor
  sess_id UUID := gen_random_uuid();
  now_epoch BIGINT := FLOOR(EXTRACT(EPOCH FROM NOW()));
  student_email TEXT := 'student_' || now_epoch || '@test.local';
  mentor_email  TEXT := 'mentor_'  || now_epoch || '@test.local';
  wallet_avail INTEGER;
  wallet_lock  INTEGER;
  earn_avail   INTEGER;
  earn_lock    INTEGER;
BEGIN
  RAISE NOTICE 'Creating test users...';
  -- Create student & mentor (robust across Supabase versions)
  s_uid := create_test_user(student_email, 'Passw0rd!', 'student');
  m_uid := create_test_user(mentor_email,  'Passw0rd!', 'mentor');

  IF s_uid IS NULL OR m_uid IS NULL THEN
    RAISE NOTICE 'Admin user-creation not available, falling back to existing users.';
    -- Fallback: pick two existing users
    SELECT id INTO s_uid FROM auth.users ORDER BY created_at ASC LIMIT 1;
    SELECT id INTO m_uid FROM auth.users WHERE id <> s_uid ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF s_uid IS NULL OR m_uid IS NULL THEN
    RAISE EXCEPTION 'Could not obtain two user IDs. Create two users in Auth and rerun, or use a no-admin variant.';
  END IF;

  RAISE NOTICE 'Student: %, Mentor: %', s_uid, m_uid;

  -- Initialize profiles/wallets/earnings
  PERFORM public.initialize_payment_profile(s_uid, ARRAY['student']);
  PERFORM public.initialize_payment_profile(m_uid, ARRAY['mentor']);

  -- Top-up student wallet: 1000.00 (minor units)
  PERFORM public.process_wallet_topup(s_uid, 100000, jsonb_build_object('gatewayId','test_topup_001'));

  -- Reserve: 600.00 for a session
  PERFORM public.process_funds_reserve(s_uid, 60000, sess_id, NULL);

  -- Capture: total 600.00; 80% mentor (480.00), 20% platform (120.00)
  PERFORM public.process_session_completion(sess_id, s_uid, m_uid, 60000, 48000, 12000, NULL);

  -- Partial refund: 100.00 back to student; reverse shares 80/20
  PERFORM public.process_session_refund(sess_id, s_uid, m_uid, 10000, 8000, 2000);

  -- Show balances
  SELECT balance_available, balance_locked INTO wallet_avail, wallet_lock
  FROM enhanced_wallets WHERE user_uid = s_uid;

  SELECT earnings_available, earnings_locked INTO earn_avail, earn_lock
  FROM mentor_earnings WHERE mentor_uid = m_uid;

  RAISE NOTICE 'Student wallet -> available: %, locked: %', wallet_avail, wallet_lock;
  RAISE NOTICE 'Mentor earnings -> available: %, locked: %', earn_avail, earn_lock;
  RAISE NOTICE 'Session ID: %', sess_id;

  -- Optional: Mark capture time in past and release mentor earnings automatically
  UPDATE session_payments SET captured_at = NOW() - INTERVAL '25 hours' WHERE session_id = sess_id;
  PERFORM public.release_due_mentor_earnings();

  -- Final balances after release
  SELECT earnings_available, earnings_locked INTO earn_avail, earn_lock
  FROM mentor_earnings WHERE mentor_uid = m_uid;
  RAISE NOTICE 'Mentor earnings after release -> available: %, locked: %', earn_avail, earn_lock;

  RAISE NOTICE 'Smoke test complete.';

  -- OPTIONAL CLEANUP (commented): try one of the following depending on your Supabase version
  -- SELECT auth."admin.delete_user"(s_uid);
  -- SELECT auth.admin_delete_user(s_uid);
  -- SELECT auth.delete_user(s_uid);
  -- SELECT auth."admin.delete_user"(m_uid);
  -- SELECT auth.admin_delete_user(m_uid);
  -- SELECT auth.delete_user(m_uid);
END $$ LANGUAGE plpgsql;
