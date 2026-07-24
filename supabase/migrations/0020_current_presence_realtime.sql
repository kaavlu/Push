-- 0020_current_presence_realtime.sql
-- Issue #84: enable postgres_changes for friend-visible presence updates.
-- RLS on current_presence still filters which rows each JWT receives.
--
-- Rollback (manual):
--   alter publication supabase_realtime drop table public.current_presence;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'current_presence'
  ) then
    alter publication supabase_realtime add table public.current_presence;
  end if;
end $$;
