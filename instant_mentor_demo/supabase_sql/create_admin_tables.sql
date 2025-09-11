-- Admin-related tables: mentor applications, call logs, disputes, refunds, bans, and GDPR helpers
-- Safe to run multiple times (uses IF NOT EXISTS where possible)

-- Mentor applications (applied by users who want to be mentors)
create table if not exists public.mentor_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null,
  qualifications text,
  subjects text[],
  experience_years int default 0,
  bio text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_notes text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Call logs (populated by clients upon call events)
create table if not exists public.call_logs (
  id uuid primary key default gen_random_uuid(),
  call_id text not null,
  caller_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  call_type text default 'video',
  status text not null check (status in ('ringing','accepted','rejected','ended')),
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds int,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Disputes (session/payment/content disputes)
create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  session_id uuid,
  created_by uuid not null references auth.users(id) on delete cascade,
  against_user_id uuid references auth.users(id) on delete set null,
  reason text not null,
  status text not null default 'open' check (status in ('open','in_review','resolved','rejected','refunded')),
  resolution text,
  refund_amount numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Admin-triggered refunds (links to wallet RPCs)
create table if not exists public.admin_refunds (
  id uuid primary key default gen_random_uuid(),
  session_id text,
  student_id uuid not null references auth.users(id) on delete cascade,
  mentor_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null,
  reason text,
  status text not null default 'pending' check (status in ('pending','processed','failed')),
  processed_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- User bans
create table if not exists public.user_bans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  active boolean not null default true,
  banned_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  lifted_at timestamptz
);

-- Triggers for updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_updated_at_mentor_applications on public.mentor_applications;
create trigger set_updated_at_mentor_applications
before update on public.mentor_applications
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_call_logs on public.call_logs;
create trigger set_updated_at_call_logs
before update on public.call_logs
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_disputes on public.disputes;
create trigger set_updated_at_disputes
before update on public.disputes
for each row execute function public.set_updated_at();

-- Indexes
create index if not exists idx_call_logs_call_id on public.call_logs(call_id);
create index if not exists idx_call_logs_created_at on public.call_logs(created_at desc);
create index if not exists idx_disputes_status on public.disputes(status);
create index if not exists idx_mentor_applications_status on public.mentor_applications(status);
create index if not exists idx_user_bans_user on public.user_bans(user_id) where active = true;

-- RLS
alter table public.mentor_applications enable row level security;
alter table public.call_logs enable row level security;
alter table public.disputes enable row level security;
alter table public.admin_refunds enable row level security;
alter table public.user_bans enable row level security;

-- By default, restrict; then open minimal policies
-- Mentor applications: applicants can insert/view their own; admins can select all and update
drop policy if exists mentor_applications_insert_own on public.mentor_applications;
create policy mentor_applications_insert_own on public.mentor_applications
  for insert with check (auth.uid() = applicant_id);

drop policy if exists mentor_applications_select_own on public.mentor_applications;
create policy mentor_applications_select_own on public.mentor_applications
  for select using (auth.uid() = applicant_id);

-- Call logs: participants can select; anyone can insert their own log row
drop policy if exists call_logs_insert_any on public.call_logs;
create policy call_logs_insert_any on public.call_logs
  for insert with check (auth.uid() = caller_id or auth.uid() = receiver_id);

drop policy if exists call_logs_select_participants on public.call_logs;
create policy call_logs_select_participants on public.call_logs
  for select using (auth.uid() = caller_id or auth.uid() = receiver_id);

-- Disputes: owner can insert/select; admin can update
drop policy if exists disputes_insert_owner on public.disputes;
create policy disputes_insert_owner on public.disputes
  for insert with check (auth.uid() = created_by);

drop policy if exists disputes_select_owner on public.disputes;
create policy disputes_select_owner on public.disputes
  for select using (auth.uid() = created_by or auth.uid() = against_user_id);

-- Admin refunds: admin creates/selects (app-only, expand as needed)
-- Leave no open policy for now to avoid abuse; admins should use service key or custom JWT claim

-- User bans: only admins should operate; end-users shouldn't see others' bans
drop policy if exists user_bans_select_self on public.user_bans;
create policy user_bans_select_self on public.user_bans
  for select using (auth.uid() = user_id);

-- GDPR helper RPCs: export and delete all user data
create or replace function public.export_user_data(p_user_id uuid)
returns json as $$
begin
  return json_build_object(
    'user_id', p_user_id,
    'mentor_profiles', coalesce((select json_agg(mp) from public.mentor_profiles mp where mp.user_id = p_user_id), '[]'::json),
    'wallet', coalesce((select row_to_json(w) from public.wallets w where w.user_id = p_user_id), '{}'),
    'wallet_transactions', coalesce((select json_agg(wt) from public.wallet_transactions wt where wt.user_id = p_user_id), '[]'::json),
    'mentor_applications', coalesce((select json_agg(ma) from public.mentor_applications ma where ma.applicant_id = p_user_id), '[]'::json),
    'call_logs', coalesce((select json_agg(cl) from public.call_logs cl where cl.caller_id = p_user_id or cl.receiver_id = p_user_id), '[]'::json),
    'disputes', coalesce((select json_agg(d) from public.disputes d where d.created_by = p_user_id or d.against_user_id = p_user_id), '[]'::json)
  );
end;
$$ language plpgsql security definer;

create or replace function public.delete_user_data(p_user_id uuid)
returns void as $$
begin
  delete from public.user_bans where user_id = p_user_id;
  delete from public.admin_refunds where student_id = p_user_id or mentor_id = p_user_id;
  delete from public.disputes where created_by = p_user_id or against_user_id = p_user_id;
  delete from public.call_logs where caller_id = p_user_id or receiver_id = p_user_id;
  delete from public.mentor_applications where applicant_id = p_user_id;
  -- Do not delete wallets by default (financial records); consider anonymization instead
end;
$$ language plpgsql security definer;
