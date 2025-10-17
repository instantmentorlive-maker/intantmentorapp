# Supabase security fixes: scripts & guidance

This folder contains safe, reviewable SQL scripts and guidance to address the security warnings you saw in your Supabase project. Do NOT run these scripts directly on production without review and backups.

Overview
- `01_enable_rls_subjects.sql` — enables Row Level Security (RLS) on `public.subjects` and provides example starter policies. Adjust predicates to match your domain model.
- `02_restrict_views.sql` — revokes PUBLIC access on flagged admin views and grants select to a named admin role. You must replace `your_admin_role` with your real role name.
- `03_function_audit_and_set_search_path.sql` — helper queries to list function definitions and to generate `ALTER FUNCTION ... SET search_path = public, pg_temp` statements for functions in `public` schema. Review generated statements before executing.
- `99_summary_commands.sql` — short list of Inspector commands (view owners, function defs).

Recommended process
1. Create a full DB snapshot (Supabase snapshot or `pg_dump`) of your project.
2. Run these scripts in a staging copy of your DB first.
3. Review outputs carefully. Especially for `03_function_audit_and_set_search_path.sql` — it only generates statements for you to review; do not run generated ALTERs blindly.
4. After testing, run approved scripts during a maintenance window.
5. Enable HaveIBeenPwned password checks in the Supabase dashboard (Authentication → Settings → Security) — this cannot be done via SQL.
6. Plan Postgres engine upgrade via Supabase dashboard and support if necessary.

Notes & caveats
- The example RLS policies are conservative templates. Modify `USING` and `WITH CHECK` to match your ownership or role model.
- `ALTER FUNCTION ... SET search_path` requires the correct function signature. The provided helper generates ALTER statements using the function identity arguments — verify them.
- If your views depend on `SECURITY DEFINER` behaviour intentionally, consider limiting who can `SELECT` from the view rather than removing definer semantics.

If you want, I can produce a one-click SQL file that (after your approval) will: enable RLS on specific tables, revoke public access on listed views, and produce ALTER FUNCTION statements for specific functions. But I will **not** execute anything — you'll run it in your environment.

-- End README
