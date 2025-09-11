-- Scheduling tables for mentor availability and sessions
-- idempotent-ish: use create table if not exists

create table if not exists public.mentor_availability (
  mentor_id uuid not null references auth.users(id) on delete cascade,
  day_of_week int2 not null check (day_of_week between 0 and 6), -- 0=Mon .. 6=Sun
  start_time time not null,
  end_time time not null,
  is_enabled boolean not null default true,
  timezone text default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (mentor_id, day_of_week)
);

create table if not exists public.mentor_time_off (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references auth.users(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now()
);

-- Ensure mentoring_sessions table exists with needed columns
create table if not exists public.mentoring_sessions (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  scheduled_time timestamptz not null,
  duration_minutes int not null,
  subject text,
  description text,
  status text not null default 'scheduled' check (status in ('pending','accepted','declined','scheduled','completed','cancelled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Simple updated_at trigger
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_updated_at_mentor_availability on public.mentor_availability;
create trigger set_updated_at_mentor_availability
before update on public.mentor_availability
for each row execute function public.set_updated_at();

-- Indexes for faster lookups
create index if not exists idx_sessions_mentor_time on public.mentoring_sessions(mentor_id, scheduled_time);
create index if not exists idx_sessions_status on public.mentoring_sessions(status);
