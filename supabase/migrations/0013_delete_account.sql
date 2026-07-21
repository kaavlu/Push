-- 0013_delete_account.sql
-- Permanent self-service account deletion (Issue #48).
-- No parameters: only auth.uid() may be deleted (prevents IDOR).
-- Order: storage best-effort → group ownership transfer/delete →
-- remaining memberships + friendships → auth.users (cascades profiles + FKs).

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  owned_group uuid;
  successor uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  -- Best-effort avatar cleanup. Storage prefers API deletes; removing
  -- storage.objects rows is best-effort so Auth deletion still proceeds.
  begin
    delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = me::text;
  exception when others then
    null;
  end;

  -- Transfer ownership when another active member exists; otherwise delete
  -- the group (memberships cascade; pushes.group_id is ON DELETE SET NULL).
  for owned_group in
    select m.group_id
    from public.group_memberships m
    where m.person_id = me
      and m.role = 'owner'
      and m.membership_status = 'active'
  loop
    select om.person_id into successor
    from public.group_memberships om
    where om.group_id = owned_group
      and om.person_id <> me
      and om.membership_status = 'active'
    order by om.joined_at asc, om.person_id asc
    limit 1;

    if successor is not null then
      update public.group_memberships
      set role = 'owner'
      where group_id = owned_group and person_id = successor;
    else
      delete from public.groups where id = owned_group;
    end if;
  end loop;

  delete from public.group_memberships where person_id = me;

  delete from public.friendships
  where user_low = me or user_high = me;

  delete from auth.users where id = me;
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
