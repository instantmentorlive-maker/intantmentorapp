-- 01_enable_rls_subjects.sql
-- Enables RLS on public.subjects and creates starter policies.
-- REVIEW and ADJUST predicates before running. Run in staging first.

BEGIN;

-- 1) Enable RLS
ALTER TABLE IF EXISTS public.subjects ENABLE ROW LEVEL SECURITY;

-- 2) Revoke broad privileges and then grant explicit ones
REVOKE ALL ON public.subjects FROM PUBLIC;

-- Example policy: allow anyone to SELECT (if you want public read access)
-- Replace with a stricter USING predicate if needed (e.g., owner_id = auth.uid())
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE polname = 'subjects_select_public' AND tablename = 'subjects'
  ) THEN
    CREATE POLICY subjects_select_public
      ON public.subjects
      FOR SELECT
      USING (true);
  END IF;
END$$;

-- Example policy: only authenticated users can INSERT
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE polname = 'subjects_insert_authenticated' AND tablename = 'subjects'
  ) THEN
    CREATE POLICY subjects_insert_authenticated
      ON public.subjects
      FOR INSERT
      WITH CHECK (auth.uid() IS NOT NULL);
  END IF;
END$$;

-- Example policy: only owners (owner_id) can UPDATE/DELETE
-- Make sure your table actually has an owner_id column before enabling this policy
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'subjects'
      AND column_name = 'owner_id'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE polname = 'subjects_owner_modify' AND tablename = 'subjects'
    ) THEN
      CREATE POLICY subjects_owner_modify
        ON public.subjects
        FOR UPDATE, DELETE
        USING (owner_id = auth.uid())
        WITH CHECK (owner_id = auth.uid());
    END IF;
  END IF;
END$$;

COMMIT;

-- IMPORTANT: If you don't want public reads, remove the "subjects_select_public" policy and
-- create a more restrictive SELECT policy (for example, auth.uid() IS NOT NULL, or owner-based).
