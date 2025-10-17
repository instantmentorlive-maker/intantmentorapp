-- Generates ALTER POLICY statements that replace auth.some_function() with (select auth.some_function())
-- Run this in Supabase SQL editor. It will print ALTER POLICY statements you can review and execute.
-- NOTE: This script only generates statements; it does not execute them.

WITH policy_parts AS (
  SELECT
    nsp.nspname AS table_schema,
    cls.relname AS table_name,
    pol.polname AS policy_name,
    pol.polcmd AS command,
    pg_get_expr(pol.polqual, pol.polrelid) AS using_clause,
    pg_get_expr(pol.polwithcheck, pol.polrelid) AS with_check_clause
  FROM pg_policy pol
  JOIN pg_class cls ON cls.oid = pol.polrelid
  JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
  WHERE nsp.nspname = 'public'
    AND (pg_get_expr(pol.polqual, pol.polrelid) IS NOT NULL OR pg_get_expr(pol.polwithcheck, pol.polrelid) IS NOT NULL)
), replacements AS (
  SELECT
    table_schema,
    table_name,
    policy_name,
    command,
    using_clause,
    with_check_clause,
    -- simple regex to find auth.foo(...) and wrap it in select
    regexp_replace(using_clause, '(auth\.[a-zA-Z0-9_]+\s*\([^\)]*\))', '(select \1)', 'g') AS using_fixed,
    regexp_replace(with_check_clause, '(auth\.[a-zA-Z0-9_]+\s*\([^\)]*\))', '(select \1)', 'g') AS with_check_fixed
  FROM policy_parts
)
SELECT
  '-- ALTER POLICY for ' || table_schema || '.' || table_name || ' policy: ' || policy_name AS note,
  'ALTER POLICY "' || policy_name || '" ON ' || table_schema || '.' || table_name ||
    CASE WHEN command <> 'all' THEN ' FOR ' || command ELSE '' END ||
    ' USING (' || coalesce(using_fixed, 'TRUE') || ')' ||
    CASE WHEN with_check_fixed IS NOT NULL THEN ' WITH CHECK (' || with_check_fixed || ')' ELSE '' END ||
    ';' AS alter_statement
FROM replacements
WHERE using_clause IS DISTINCT FROM using_fixed OR with_check_clause IS DISTINCT FROM with_check_fixed
ORDER BY table_name, policy_name;

-- If nothing is returned, no policies needed automatic replacement by this simple regex.
