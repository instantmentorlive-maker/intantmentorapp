-- Wallet tables and helper function for Supabase/Postgres

-- wallets table: tracks per-user balance
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id uuid PRIMARY KEY,
  balance numeric DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

-- wallet_transactions table: recording each top-up/withdrawal
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_id text UNIQUE NOT NULL,
  user_id uuid NOT NULL,
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending, success, failed
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- withdrawal_requests table: for payout handling
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount numeric NOT NULL,
  bank_account_id text,
  status text NOT NULL DEFAULT 'pending',
  requested_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- Example RPC to add money atomically
CREATE OR REPLACE FUNCTION public.add_money_to_wallet(
  user_id uuid,
  amount numeric,
  txn_id text
) RETURNS void AS $$
BEGIN
  LOOP
    -- try to update existing wallet
    UPDATE public.wallets
    SET balance = balance + amount,
        updated_at = now()
    WHERE user_id = add_money_to_wallet.user_id;

    IF FOUND THEN
      RETURN;
    END IF;

    -- if not found, insert new wallet row
    BEGIN
      INSERT INTO public.wallets (user_id, balance)
      VALUES (add_money_to_wallet.user_id, amount);
      RETURN;
    EXCEPTION WHEN unique_violation THEN
      -- concurrent insert, retry loop
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
