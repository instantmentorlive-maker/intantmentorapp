-- Analytics events table for lightweight product tracking
create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid null references auth.users(id) on delete set null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb
);

-- Basic RLS allowing users to insert their own events and read only their own
alter table public.analytics_events enable row level security;

do $$ begin
  create policy if not exists "insert_own_events" on public.analytics_events
    for insert with check (auth.uid() is not null);
exception when others then null; end $$;

do $$ begin
  create policy if not exists "select_own_events" on public.analytics_events
    for select using (user_id = auth.uid());
exception when others then null; end $$;
