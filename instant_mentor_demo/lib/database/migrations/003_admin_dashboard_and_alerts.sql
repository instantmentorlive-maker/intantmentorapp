-- Admin Dashboard and Alerting Migration
-- Creates admin-only helpers, views, RPCs, and alerting table

-- Ensure pgcrypto for UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Admin helper: check if current user is admin via user_payment_profiles.roles
CREATE OR REPLACE FUNCTION is_admin(p_uid uuid)
RETURNS boolean AS $$
DECLARE v boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM user_payment_profiles upp
    WHERE upp.uid = p_uid AND 'admin' = ANY(upp.roles)
  ) INTO v;
  RETURN COALESCE(v, false);
END;
$$ LANGUAGE plpgsql STABLE;

-- Ensure roles column exists for admin gating
ALTER TABLE user_payment_profiles
  ADD COLUMN IF NOT EXISTS roles text[] NOT NULL DEFAULT ARRAY[]::text[];

-- Alerts table (admin-readable, system-writable)
CREATE TABLE IF NOT EXISTS admin_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('info','warning','error','critical')),
  message text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE admin_alerts ENABLE ROW LEVEL SECURITY;

-- RLS: only admins can read alerts
DROP POLICY IF EXISTS "Admins can read alerts" ON admin_alerts;
CREATE POLICY "Admins can read alerts" ON admin_alerts
  FOR SELECT USING (is_admin(auth.uid()));

-- No direct inserts from clients
DROP POLICY IF EXISTS "No direct writes to alerts" ON admin_alerts;
CREATE POLICY "No direct writes to alerts" ON admin_alerts
  FOR ALL USING (false);

-- Function to log an alert (SECURITY DEFINER), callable by backend or authenticated
CREATE OR REPLACE FUNCTION admin_log_alert(
  p_type text,
  p_severity text,
  p_message text,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void AS $$
BEGIN
  INSERT INTO admin_alerts(alert_type, severity, message, details)
  VALUES (p_type, p_severity, p_message, p_details);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Admin views and RPCs

-- Payouts view (latest first)
CREATE OR REPLACE VIEW admin_payouts_view AS
SELECT pr.* FROM payout_requests pr ORDER BY pr.created_at DESC;

-- Refunds view from ledger (latest first)
CREATE OR REPLACE VIEW admin_refunds_view AS
SELECT lt.*
FROM ledger_transactions lt
WHERE lt.transaction_type = 'refund'
ORDER BY lt.created_at DESC;

-- Balances summary (wallets + mentor earnings + platform revenue net)
CREATE OR REPLACE FUNCTION admin_balances_summary()
RETURNS jsonb AS $$
DECLARE
  j jsonb;
  w_avail bigint; w_lock bigint;
  e_avail bigint; e_lock bigint;
  platform_debits bigint; -- entries to platformRevenue
  platform_refunds bigint; -- reversals from platformRevenue
  platform_net bigint;
BEGIN
  SELECT COALESCE(SUM(balance_available),0), COALESCE(SUM(balance_locked),0)
  INTO w_avail, w_lock FROM enhanced_wallets;

  SELECT COALESCE(SUM(earnings_available),0), COALESCE(SUM(earnings_locked),0)
  INTO e_avail, e_lock FROM mentor_earnings;

  SELECT COALESCE(SUM(amount),0) INTO platform_debits
  FROM ledger_transactions
  WHERE to_account = 'platformRevenue' AND transaction_type IN ('fee');

  SELECT COALESCE(SUM(amount),0) INTO platform_refunds
  FROM ledger_transactions
  WHERE from_account = 'platformRevenue' AND transaction_type = 'refund';

  platform_net := platform_debits - platform_refunds;

  j := jsonb_build_object(
    'wallet_total_available', w_avail,
    'wallet_total_locked', w_lock,
    'earnings_total_available', e_avail,
    'earnings_total_locked', e_lock,
    'platform_revenue_net', platform_net
  );
  RETURN j;
END;
$$ LANGUAGE plpgsql STABLE;

-- Reconciliation stats (simple counts/sums)
CREATE OR REPLACE FUNCTION admin_reconciliation_stats()
RETURNS jsonb AS $$
DECLARE
  j jsonb;
  tx_count bigint; tx_sum bigint;
  refund_count bigint; refund_sum bigint;
  payout_count bigint; payout_sum bigint;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(amount),0) INTO tx_count, tx_sum FROM ledger_transactions;
  SELECT COUNT(*), COALESCE(SUM(amount),0) INTO refund_count, refund_sum FROM ledger_transactions WHERE transaction_type='refund';
  SELECT COUNT(*), COALESCE(SUM(amount),0) INTO payout_count, payout_sum FROM payout_requests WHERE status IN ('pending','paid');

  j := jsonb_build_object(
    'transactions', jsonb_build_object('count', tx_count, 'amount_sum', tx_sum),
    'refunds', jsonb_build_object('count', refund_count, 'amount_sum', refund_sum),
    'payouts', jsonb_build_object('count', payout_count, 'amount_sum', payout_sum)
  );
  RETURN j;
END;
$$ LANGUAGE plpgsql STABLE;

-- Admin RPCs that enforce role check
CREATE OR REPLACE FUNCTION admin_list_payouts(p_limit int DEFAULT 100, p_offset int DEFAULT 0)
RETURNS SETOF payout_requests AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM payout_requests ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION admin_list_refunds(p_limit int DEFAULT 100, p_offset int DEFAULT 0)
RETURNS SETOF ledger_transactions AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM ledger_transactions WHERE transaction_type='refund' ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION admin_get_balances_summary()
RETURNS jsonb AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN admin_balances_summary();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grants for authenticated role (RLS still applies)
DO $$
BEGIN
  BEGIN
    GRANT SELECT ON admin_alerts TO authenticated;
  EXCEPTION WHEN undefined_object THEN NULL; END;
  BEGIN
    GRANT EXECUTE ON FUNCTION admin_log_alert(text, text, text, jsonb) TO authenticated;
  EXCEPTION WHEN undefined_function THEN NULL; END;
  BEGIN
    GRANT EXECUTE ON FUNCTION admin_list_payouts(int, int) TO authenticated;
  EXCEPTION WHEN undefined_function THEN NULL; END;
  BEGIN
    GRANT EXECUTE ON FUNCTION admin_list_refunds(int, int) TO authenticated;
  EXCEPTION WHEN undefined_function THEN NULL; END;
  BEGIN
    GRANT EXECUTE ON FUNCTION admin_get_balances_summary() TO authenticated;
  EXCEPTION WHEN undefined_function THEN NULL; END;
  BEGIN
    GRANT EXECUTE ON FUNCTION admin_get_reconciliation_stats() TO authenticated;
  EXCEPTION WHEN undefined_function THEN NULL; END;
END $$;

CREATE OR REPLACE FUNCTION admin_get_reconciliation_stats()
RETURNS jsonb AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN admin_reconciliation_stats();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
