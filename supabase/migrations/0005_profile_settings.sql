-- 0005_profile_settings.sql
-- Day-1 profile settings overrides: per-toggle enabled/disabled state for the
-- Activity visibility, Map preferences, and Close Friends screens. Toggle copy
-- (title/subtitle/icon) stays client-side in ProfileScaffolding; only the
-- boolean state a user has changed is persisted here, keyed by toggle id
-- (e.g. {"place": true, "activity": false}). Null means "no overrides yet" —
-- the client falls back to ProfileScaffolding defaults for every id.
alter table public.profiles
  add column settings_activity_visibility jsonb,
  add column settings_map_preferences jsonb,
  add column settings_close_friends jsonb;
