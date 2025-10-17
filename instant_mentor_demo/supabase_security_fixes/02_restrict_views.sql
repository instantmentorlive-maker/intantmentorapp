-- 02_restrict_views.sql
-- Revoke PUBLIC access on flagged admin views and grant SELECT to an admin role.
-- Replace 'your_admin_role' with the role that should have access (e.g. "service_role" or a custom role).

BEGIN;

-- Revoke public access for a set of admin views
REVOKE ALL ON public.admin_payouts_view FROM PUBLIC;
REVOKE ALL ON public.wallets FROM PUBLIC;
REVOKE ALL ON public.admin_refunds_view FROM PUBLIC;
REVOKE ALL ON public.transactions FROM PUBLIC;
REVOKE ALL ON public.earnings FROM PUBLIC;

-- Grant select to an admin role (replace with your real role)
GRANT SELECT ON public.admin_payouts_view TO your_admin_role;
GRANT SELECT ON public.wallets TO your_admin_role;
GRANT SELECT ON public.admin_refunds_view TO your_admin_role;
GRANT SELECT ON public.transactions TO your_admin_role;
GRANT SELECT ON public.earnings TO your_admin_role;

COMMIT;

-- Note: If these views must remain publicly selectable for application reasons,
-- consider creating a restricted API or function that enforces access checks, or
-- limit which role the view is owned by.
