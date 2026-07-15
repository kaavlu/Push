-- 0008_pushes_delete_policy.sql
-- Adds a hard-delete path for pushes: the trash button on Start Push /
-- Manage Push lets the creator permanently remove a push (not just
-- soft-cancel it). `push_responses.push_id` already cascades on delete
-- (see 0006_pushes.sql), so removing the push row cleans up its RSVPs too.
create policy pushes_delete_creator on public.pushes
  for delete using (creator_id = (select auth.uid()));
