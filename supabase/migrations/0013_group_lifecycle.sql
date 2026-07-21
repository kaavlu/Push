-- 0013_group_lifecycle.sql
-- Complete group management after 0011's create + invite accept/deny:
-- rename, photo path, invite/cancel, remove, leave, transfer, delete — all via
-- SECURITY DEFINER RPCs (no broad client write policies on groups/memberships).
-- Public `group-photos` bucket mirrors avatars (0012/0012b): owner-only writes
-- under `{group_id}/…`; select-own for upsert without listable public SELECT.
--
-- Design:
-- - `private.is_group_owner` — active membership with role = owner (private schema).
-- - Hard-delete memberships on cancel/remove/leave so re-invite inserts cleanly
--   (same rationale as resolve_group_invite deny + remove_friend).
-- - Owner leave with other active members requires transfer first; sole active
--   owner leave deletes the group. `delete_group` hard-deletes groups (cascades
--   memberships; pushes.group_id SET NULL).

-- Active owner of group g?
create or replace function private.is_group_owner(u uuid, g uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_memberships m
    where m.group_id = g
      and m.person_id = u
      and m.membership_status = 'active'
      and m.role = 'owner'
  );
$$;

revoke execute on function private.is_group_owner(uuid, uuid) from public, anon;
grant execute on function private.is_group_owner(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- rename_group
-- ---------------------------------------------------------------------------
create or replace function public.rename_group(
  p_group_id uuid,
  p_name text
)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  trimmed_name text := trim(p_name);
  result public.groups;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_owner(me, p_group_id) then
    raise exception 'not owner';
  end if;
  if length(trimmed_name) = 0 then
    raise exception 'group name required';
  end if;

  update public.groups
  set name = trimmed_name
  where id = p_group_id
  returning * into result;

  if not found then
    raise exception 'not found';
  end if;

  return result;
end;
$$;

revoke all on function public.rename_group(uuid, text) from public, anon;
grant execute on function public.rename_group(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- set_group_image (null path clears)
-- ---------------------------------------------------------------------------
create or replace function public.set_group_image(
  p_group_id uuid,
  p_image_path text
)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  result public.groups;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_owner(me, p_group_id) then
    raise exception 'not owner';
  end if;

  update public.groups
  set image_asset_path = p_image_path
  where id = p_group_id
  returning * into result;

  if not found then
    raise exception 'not found';
  end if;

  return result;
end;
$$;

revoke all on function public.set_group_image(uuid, text) from public, anon;
grant execute on function public.set_group_image(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- invite_to_group
-- ---------------------------------------------------------------------------
create or replace function public.invite_to_group(
  p_group_id uuid,
  p_invitee_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  invitee uuid;
  existing public.group_memberships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_owner(me, p_group_id) then
    raise exception 'not owner';
  end if;

  if p_invitee_ids is null or array_length(p_invitee_ids, 1) is null then
    return;
  end if;

  foreach invitee in array p_invitee_ids loop
    if invitee is null or invitee = me then
      continue;
    end if;

    if not private.is_friend(me, invitee) then
      raise exception 'invitee % is not a friend', invitee;
    end if;

    select * into existing
    from public.group_memberships m
    where m.group_id = p_group_id and m.person_id = invitee;

    if found then
      -- Active or already invited: skip (re-invite only after hard-delete).
      continue;
    end if;

    insert into public.group_memberships (person_id, group_id, role, membership_status)
    values (invitee, p_group_id, 'member', 'invited');
  end loop;
end;
$$;

revoke all on function public.invite_to_group(uuid, uuid[]) from public, anon;
grant execute on function public.invite_to_group(uuid, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- cancel_group_invite
-- ---------------------------------------------------------------------------
create or replace function public.cancel_group_invite(
  p_membership_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.group_memberships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into existing
  from public.group_memberships m
  where m.id = p_membership_id
  for update;

  if not found then
    raise exception 'not found';
  end if;
  if not private.is_group_owner(me, existing.group_id) then
    raise exception 'not owner';
  end if;
  if existing.membership_status <> 'invited' then
    raise exception 'not pending';
  end if;

  delete from public.group_memberships where id = existing.id;
end;
$$;

revoke all on function public.cancel_group_invite(uuid) from public, anon;
grant execute on function public.cancel_group_invite(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- remove_group_member
-- ---------------------------------------------------------------------------
create or replace function public.remove_group_member(
  p_group_id uuid,
  p_person_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.group_memberships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_owner(me, p_group_id) then
    raise exception 'not owner';
  end if;
  if p_person_id is null or p_person_id = me then
    raise exception 'cannot remove self';
  end if;

  select * into existing
  from public.group_memberships m
  where m.group_id = p_group_id and m.person_id = p_person_id
  for update;

  if not found then
    raise exception 'not found';
  end if;
  if existing.membership_status <> 'active' then
    raise exception 'not active';
  end if;
  if existing.role = 'owner' then
    raise exception 'cannot remove owner';
  end if;

  delete from public.group_memberships where id = existing.id;
end;
$$;

revoke all on function public.remove_group_member(uuid, uuid) from public, anon;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- leave_group
-- ---------------------------------------------------------------------------
create or replace function public.leave_group(
  p_group_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  existing public.group_memberships;
  active_count integer;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into existing
  from public.group_memberships m
  where m.group_id = p_group_id and m.person_id = me
  for update;

  if not found or existing.membership_status <> 'active' then
    raise exception 'not a member';
  end if;

  if existing.role = 'member' then
    delete from public.group_memberships where id = existing.id;
    return;
  end if;

  -- Owner path.
  select count(*)::integer into active_count
  from public.group_memberships m
  where m.group_id = p_group_id and m.membership_status = 'active';

  if active_count > 1 then
    raise exception 'transfer ownership first';
  end if;

  -- Sole active member (owner): delete the group (cascades memberships).
  delete from public.groups where id = p_group_id;
end;
$$;

revoke all on function public.leave_group(uuid) from public, anon;
grant execute on function public.leave_group(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- transfer_group_ownership
-- ---------------------------------------------------------------------------
create or replace function public.transfer_group_ownership(
  p_group_id uuid,
  p_new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  target public.group_memberships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_owner(me, p_group_id) then
    raise exception 'not owner';
  end if;
  if p_new_owner_id is null or p_new_owner_id = me then
    raise exception 'invalid target';
  end if;

  select * into target
  from public.group_memberships m
  where m.group_id = p_group_id and m.person_id = p_new_owner_id
  for update;

  if not found then
    raise exception 'not found';
  end if;
  if target.membership_status <> 'active' then
    raise exception 'not active';
  end if;

  -- Single transaction: demote self then promote target (never zero owners).
  update public.group_memberships
  set role = 'member'
  where group_id = p_group_id and person_id = me and role = 'owner';

  update public.group_memberships
  set role = 'owner'
  where id = target.id;
end;
$$;

revoke all on function public.transfer_group_ownership(uuid, uuid) from public, anon;
grant execute on function public.transfer_group_ownership(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- delete_group
-- ---------------------------------------------------------------------------
create or replace function public.delete_group(
  p_group_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not private.is_group_owner(me, p_group_id) then
    raise exception 'not owner';
  end if;

  delete from public.groups where id = p_group_id;

  if not found then
    raise exception 'not found';
  end if;
end;
$$;

revoke all on function public.delete_group(uuid) from public, anon;
grant execute on function public.delete_group(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: group-photos bucket + owner-only policies
-- Object keys: {group_id}/{uuid}.jpg
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'group-photos',
  'group-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Owner-only SELECT for upsert (not listable for non-owners / public).
drop policy if exists "group_photos_select_own" on storage.objects;
create policy "group_photos_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'group-photos'
    and private.is_group_owner(
      (select auth.uid()),
      ((storage.foldername(name))[1])::uuid
    )
  );

drop policy if exists "group_photos_insert_own" on storage.objects;
create policy "group_photos_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'group-photos'
    and private.is_group_owner(
      (select auth.uid()),
      ((storage.foldername(name))[1])::uuid
    )
  );

drop policy if exists "group_photos_update_own" on storage.objects;
create policy "group_photos_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'group-photos'
    and private.is_group_owner(
      (select auth.uid()),
      ((storage.foldername(name))[1])::uuid
    )
  )
  with check (
    bucket_id = 'group-photos'
    and private.is_group_owner(
      (select auth.uid()),
      ((storage.foldername(name))[1])::uuid
    )
  );

drop policy if exists "group_photos_delete_own" on storage.objects;
create policy "group_photos_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'group-photos'
    and private.is_group_owner(
      (select auth.uid()),
      ((storage.foldername(name))[1])::uuid
    )
  );
