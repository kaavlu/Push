-- 0001_profiles.sql
-- Profiles mirror Person + UserProfile. Row id == auth.users.id.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null default '',
  handle text not null unique,
  image_asset_path text,
  availability_choice text not null default 'free_now',
  visibility_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Owner can read and maintain only their own row (Day 1: no cross-user reads yet;
-- friend/group visibility is added in later migrations).
create policy profiles_select_self on public.profiles
  for select using ((select auth.uid()) = id);
create policy profiles_insert_self on public.profiles
  for insert with check ((select auth.uid()) = id);
create policy profiles_update_self on public.profiles
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Auto-create a profile row when a new auth user is created.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, first_name, handle)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'handle', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- The trigger runs as table owner; no API role should call this via RPC.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
