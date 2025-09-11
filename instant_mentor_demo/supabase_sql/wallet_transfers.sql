-- Atomic wallet transfers for sessions: charge student, split commission, credit mentor
-- Safe to run on Supabase/Postgres with pgcrypto for gen_random_uuid

create or replace function public.charge_session_wallet(
  p_session_id text,
  p_student_id uuid,
  p_mentor_id uuid,
  p_amount numeric,
  p_commission_rate numeric default 0.15,
  p_unit text default 'total',
  p_quantity int default 1
)
returns json as $$
declare
  v_gross numeric := p_amount * p_quantity;
  v_commission numeric := round(v_gross * p_commission_rate, 2);
  v_mentor_net numeric := v_gross - v_commission;
begin
  -- ensure wallet rows exist
  insert into public.wallets(user_id, balance) values (p_student_id, 0)
    on conflict (user_id) do nothing;
  insert into public.wallets(user_id, balance) values (p_mentor_id, 0)
    on conflict (user_id) do nothing;

  -- deduct from student
  update public.wallets set balance = balance - v_gross, updated_at = now()
  where user_id = p_student_id;
  insert into public.wallet_transactions(txn_id, user_id, amount, status, created_at)
  values (concat('sess_', p_session_id, '_', gen_random_uuid()), p_student_id, -v_gross, 'completed', now());

  -- credit mentor
  update public.wallets set balance = balance + v_mentor_net, updated_at = now()
  where user_id = p_mentor_id;
  insert into public.wallet_transactions(txn_id, user_id, amount, status, created_at)
  values (concat('earn_', p_session_id, '_', gen_random_uuid()), p_mentor_id, v_mentor_net, 'completed', now());

  return json_build_object(
    'session_id', p_session_id,
    'student_id', p_student_id,
    'mentor_id', p_mentor_id,
    'gross_amount', v_gross,
    'commission', v_commission,
    'mentor_net', v_mentor_net,
    'status', 'completed'
  );
end;
$$ language plpgsql security definer;


create or replace function public.refund_session_wallet(
  p_session_id text,
  p_student_id uuid,
  p_mentor_id uuid,
  p_amount numeric,
  p_reason text default 'refund'
)
returns json as $$
begin
  -- ensure wallet rows exist
  insert into public.wallets(user_id, balance) values (p_student_id, 0)
    on conflict (user_id) do nothing;
  insert into public.wallets(user_id, balance) values (p_mentor_id, 0)
    on conflict (user_id) do nothing;

  -- refund to student
  update public.wallets set balance = balance + p_amount, updated_at = now()
  where user_id = p_student_id;
  insert into public.wallet_transactions(txn_id, user_id, amount, status, created_at)
  values (concat('rf_', p_session_id, '_', gen_random_uuid()), p_student_id, p_amount, 'completed', now());

  -- reverse mentor earning (debit)
  update public.wallets set balance = balance - p_amount, updated_at = now()
  where user_id = p_mentor_id;
  insert into public.wallet_transactions(txn_id, user_id, amount, status, created_at)
  values (concat('rev_', p_session_id, '_', gen_random_uuid()), p_mentor_id, -p_amount, 'completed', now());

  return json_build_object(
    'session_id', p_session_id,
    'student_id', p_student_id,
    'mentor_id', p_mentor_id,
    'amount', p_amount,
    'status', 'refunded'
  );
end;
$$ language plpgsql security definer;
