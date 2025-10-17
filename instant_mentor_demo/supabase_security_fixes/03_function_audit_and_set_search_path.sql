-- 03_function_audit_and_set_search_path.sql
-- Helper: list public functions that contain 'search_path' or SECURITY DEFINER or unqualified references,
-- and generate ALTER FUNCTION statements to set a fixed search_path.
-- Review generated ALTER statements before running them.

-- 1) Print functions in public schema that mention search_path or SECURITY DEFINER
SELECT n.nspname AS schema_name,
       p.proname AS function_name,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND (
    pg_get_functiondef(p.oid) ILIKE '%search_path%'
    OR pg_get_functiondef(p.oid) ILIKE '%SECURITY DEFINER%'
    OR pg_get_functiondef(p.oid) ILIKE '%public.%' = false -- heuristic: functions that might use unqualified names
  );

-- 2) Generate ALTER FUNCTION statements to set a safe search_path for functions in public.
-- This attempts to generate a SET clause using argument types to uniquely identify functions.
-- REVIEW the output carefully.

WITH funcs AS (
  SELECT p.oid,
         n.nspname,
         p.proname,
         pg_get_function_identity_arguments(p.oid) AS identity_args,
         pg_get_functiondef(p.oid) AS definition
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
)
SELECT 'ALTER FUNCTION public.' || quote_ident(proname) || '(' || identity_args || ') SET search_path = public, pg_temp;' AS alter_stmt,
       definition
FROM funcs
ORDER BY proname;

-- Usage: copy generated ALTER statements, inspect them, and then run them one-by-one in a safe environment.
-- Example generated output:
-- ALTER FUNCTION public.update_thread_updated_at(uuid) SET search_path = public, pg_temp;

-- 3) OPTIONAL: If you decide to apply the generated statements automatically, you could DO that after REVIEW.
-- The following block is commented out to avoid accidental execution. Uncomment only after manual verification.

-- DO $$
-- DECLARE
--   r record;
-- BEGIN
--   FOR r IN (
--     SELECT 'ALTER FUNCTION public.' || quote_ident(proname) || '(' || identity_args || ') SET search_path = public, pg_temp;' AS alter_stmt
--     FROM (
--       SELECT p.proname, pg_get_function_identity_arguments(p.oid) as identity_args
--       FROM pg_proc p
--       JOIN pg_namespace n ON p.pronamespace = n.oid
--       WHERE n.nspname = 'public'
--     ) t
--   ) LOOP
--     RAISE NOTICE 'Running: %', r.alter_stmt;
--     EXECUTE r.alter_stmt;
--   END LOOP;
-- END$$;
