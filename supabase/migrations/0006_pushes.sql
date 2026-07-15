-- 0006_pushes.sql
-- Coordination objects ("Pushes"). Unlike the reads-only social graph, pushes
-- are multi-actor: the creator writes the push and seeds invitee responses;
-- each recipient writes their own RSVP row. RLS below reflects that split.
create table public.pushes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  group_id uuid references public.groups (id) on delete set null,
  creator_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  starts_at timestamptz not null,
  has_explicit_time boolean not null default true,
  is_approximate_time boolean not null default false,
  expires_at timestamptz not null,
  cancelled_at timestamptz,
  place_id text,
  place_is_suggested boolean not null default false,
  state text not null default 'collecting'
    check (state in ('collecting', 'locked', 'happening')),
  audience text not null default 'invitees_only'
    check (audience in ('group', 'invitees_only')),
  note text,
  location_text text
);
create index pushes_creator_idx on public.pushes (creator_id);

create table public.push_responses (
  id uuid primary key default gen_random_uuid(),
  push_id uuid not null references public.pushes (id) on delete cascade,
  person_id uuid not null references public.profiles (id) on delete cascade,
  response text not null default 'pending'
    check (response in ('in', 'maybe', 'out', 'pending')),
  responded_at timestamptz,
  ready_state text not null default 'unknown'
    check (ready_state in ('ready_now', 'ready_later', 'needs_ride', 'not_ready', 'unknown')),
  constraint push_responses_unique unique (push_id, person_id)
);
create index push_responses_push_idx on public.push_responses (push_id);
create index push_responses_person_idx on public.push_responses (person_id);

alter table public.pushes enable row level security;
alter table public.push_responses enable row level security;

-- Hardened helper: true when viewer is the push's creator.
create function private.is_push_creator(viewer uuid, push uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pushes p
    where p.id = push and p.creator_id = viewer
  );
$$;
revoke execute on function private.is_push_creator(uuid, uuid) from public, anon;
grant execute on function private.is_push_creator(uuid, uuid) to authenticated;

-- Hardened helper: creator, an invited recipient (has a response row), or a
-- member of the push's backing group (single-group audience) can view it.
create function private.can_view_push(viewer uuid, push uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pushes p
    where p.id = push
      and (
        p.creator_id = viewer
        or exists (
          select 1 from public.push_responses r
          where r.push_id = push and r.person_id = viewer
        )
        or (p.group_id is not null and private.is_group_member(viewer, p.group_id))
      )
  );
$$;
revoke execute on function private.can_view_push(uuid, uuid) from public, anon;
grant execute on function private.can_view_push(uuid, uuid) to authenticated;

-- pushes: read if you can see it; only the creator can insert/update
-- (edit and soft-cancel both go through update, so no delete policy).
create policy pushes_select_visible on public.pushes
  for select using (private.can_view_push((select auth.uid()), id));
create policy pushes_insert_creator on public.pushes
  for insert with check (creator_id = (select auth.uid()));
create policy pushes_update_creator on public.pushes
  for update using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()));

-- push_responses: read if you can see the push; a recipient writes their own
-- RSVP, and the creator may seed pending invitee rows (never a non-pending
-- response) or drop invitees removed during an edit.
create policy push_responses_select_visible on public.push_responses
  for select using (private.can_view_push((select auth.uid()), push_id));
create policy push_responses_insert_self_or_creator on public.push_responses
  for insert with check (
    person_id = (select auth.uid())
    or (private.is_push_creator((select auth.uid()), push_id) and response = 'pending')
  );
create policy push_responses_update_self on public.push_responses
  for update using (person_id = (select auth.uid()))
  with check (person_id = (select auth.uid()));
create policy push_responses_delete_self_or_creator on public.push_responses
  for delete using (
    person_id = (select auth.uid())
    or private.is_push_creator((select auth.uid()), push_id)
  );
