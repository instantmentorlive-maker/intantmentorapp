-- Migration: Mentor profiles schema, indexes, RLS, and search helper
-- Creates mentor_profiles table to support discovery & matching

create table if not exists public.mentor_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  profile_image text,
  bio text,
  specializations text[] default '{}', -- e.g., ['Mathematics','Organic Chemistry']
  exams text[] default '{}',           -- e.g., ['JEE','NEET','UPSC','SSC']
  subjects text[] default '{}',        -- normalized subjects list
  years_of_experience int default 0,
  hourly_rate numeric(10,2) default 0,
  rating numeric(3,2) default 0,
  rating_count int default 0,
  total_sessions int default 0,
  is_available boolean default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Updated at trigger
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_mentor_profiles_updated_at on public.mentor_profiles;
create trigger set_mentor_profiles_updated_at
before update on public.mentor_profiles
for each row execute function public.set_updated_at();

-- Indexes for fast filtering/search
create index if not exists idx_mentor_profiles_rating on public.mentor_profiles (rating desc, rating_count desc);
create index if not exists idx_mentor_profiles_experience on public.mentor_profiles (years_of_experience desc);
create index if not exists idx_mentor_profiles_available on public.mentor_profiles (is_available, updated_at desc);
create index if not exists idx_mentor_profiles_exams on public.mentor_profiles using gin (exams);
create index if not exists idx_mentor_profiles_subjects on public.mentor_profiles using gin (subjects);
create index if not exists idx_mentor_profiles_specializations on public.mentor_profiles using gin (specializations);

-- RLS: allow read to anon, write to authenticated owner (by user_id)
alter table public.mentor_profiles enable row level security;

-- Read for anyone (listing discovery)
drop policy if exists "mentor_profiles_read_all" on public.mentor_profiles;
create policy "mentor_profiles_read_all"
  on public.mentor_profiles for select
  using (true);

-- Insert/Update/Delete only by the mentor themselves
drop policy if exists "mentor_profiles_write_own" on public.mentor_profiles;
create policy "mentor_profiles_write_own"
  on public.mentor_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Optional search helper: allows filtering with optional params
create or replace function public.search_mentors(
  p_query text default null,
  p_exam text default null,
  p_subject text default null,
  p_min_rating numeric default null,
  p_min_experience int default null,
  p_available boolean default null,
  p_limit int default 20,
  p_offset int default 0,
  p_sort text default 'rating_desc'
)
returns setof public.mentor_profiles
language sql
stable
as $$
  with base as (
    select *
    from public.mentor_profiles mp
    where
      (p_query is null or (
        mp.name ilike '%'||p_query||'%' or
        mp.bio ilike '%'||p_query||'%' or
        (p_query) = any(mp.exams) or
        (p_query) = any(mp.subjects) or
        (p_query) = any(mp.specializations)
      ))
      and (p_exam is null or p_exam = any(mp.exams))
      and (p_subject is null or p_subject = any(mp.subjects))
      and (p_min_rating is null or mp.rating >= p_min_rating)
      and (p_min_experience is null or mp.years_of_experience >= p_min_experience)
      and (p_available is null or mp.is_available = p_available)
  )
  select * from base
  order by 
    case when p_sort = 'rating_desc' then 0 else 1 end,
    rating desc, rating_count desc,
    case when p_sort = 'experience_desc' then 0 else 1 end,
    years_of_experience desc,
    case when p_sort = 'price_asc' then 0 else 1 end,
    hourly_rate asc,
    created_at desc
  limit p_limit offset p_offset;
$$;

comment on function public.search_mentors is 'Flexible mentor search with optional filters and sort options: rating_desc, experience_desc, price_asc.';
