-- 0007_pushes_select_direct_owner_check.sql
-- Fixes a real RLS bug found in end-to-end verification of 0006: `can_view_push`
-- and `push_responses`'s invited-check both resolve visibility via a fresh
-- subquery against the same table being written to. Postgres can't see a
-- row's own not-yet-committed tuple through that kind of subquery during
-- `INSERT ... RETURNING` (what `.select().single()` sends), so a creator's
-- own `INSERT INTO pushes ... RETURNING` failed RLS even though they
-- unambiguously own the row. UPDATE...RETURNING is unaffected (the row
-- already exists in a prior snapshot), only INSERT...RETURNING is.
--
-- Fix: short-circuit each SELECT policy with a direct, subquery-free column
-- comparison (`creator_id = auth.uid()` / `person_id = auth.uid()`) ahead of
-- the helper-backed check, so "can I see my own row" never needs a self-table
-- lookup. This is also strictly more correct: a response row is always about
-- you, so you should see your own regardless of `can_view_push`.
drop policy pushes_select_visible on public.pushes;
create policy pushes_select_visible on public.pushes
  for select using (
    creator_id = (select auth.uid())
    or private.can_view_push((select auth.uid()), id)
  );

drop policy push_responses_select_visible on public.push_responses;
create policy push_responses_select_visible on public.push_responses
  for select using (
    person_id = (select auth.uid())
    or private.can_view_push((select auth.uid()), push_id)
  );
