# Admin Dashboard & Alerts

This adds:
- SQL migration `lib/database/migrations/003_admin_dashboard_and_alerts.sql` for admin-only RPCs and an `admin_alerts` table.
- Flutter UI `lib/admin/ui/admin_dashboard_page.dart` with Riverpod providers in `lib/admin/data/admin_providers.dart`.

## Run the migration

Run migrations in order:
1. `lib/database/migrations/001_enhanced_payments_schema.sql`
2. `lib/database/migrations/002_payments_smoke_tests.sql` (optional)
3. `lib/database/migrations/003_admin_dashboard_and_alerts.sql`

## Make yourself admin

Update your profile roles array:

```
update user_payment_profiles
set roles = array_append(roles, 'admin')
where uid = '<YOUR-USER-UUID>' and not ('admin' = any(roles));
```

Then sign out/in in the app.

## Wire the Flutter page

Add a route to `AdminDashboardPage()` only for admins. The page uses RPCs:
- `admin_list_payouts`
- `admin_list_refunds`
- `admin_get_balances_summary`
- `admin_get_reconciliation_stats`

If not admin, the page shows "Access denied."

## Alerts

Backend can call `admin_log_alert(p_type, p_severity, p_message, p_details)` to record alerts (visible to admins via SQL/DB browser or an optional UI extension).

Suggested alert types: `webhook_verification_failed`, `payout_failure`, `reconciliation_mismatch`.
