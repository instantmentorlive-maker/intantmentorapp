-- 99_summary_commands.sql
-- Quick inspector queries to run in Supabase SQL editor to gather context about flagged objects.

-- view owners and definitions
SELECT table_schema, table_name, table_owner, view_definition
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN ('admin_payouts_view','wallets','admin_refunds_view','transactions','earnings');

-- functions with SECURITY DEFINER or explicit search_path usage
SELECT n.nspname AS schema, p.proname AS function_name, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND (pg_get_functiondef(p.oid) ILIKE '%SECURITY DEFINER%' OR pg_get_functiondef(p.oid) ILIKE '%search_path%');

-- check whether public.subjects has an owner_id column (used by example policies)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'subjects';

-- check current policies on subjects
SELECT * FROM pg_policies WHERE tablename = 'subjects';
