-- 0017_oauth_profile_handle.sql
-- Harden handle_new_user for OAuth providers (Apple/Google):
-- - Prefer provider name metadata keys when first_name is absent.
-- - Sanitize handle to [a-z0-9_], enforce min length, suffix on unique collision.
-- Email/password sign-up continues to pass first_name + handle in raw_user_meta_data.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  base_handle text;
  candidate text;
  display_name text;
  suffix int := 0;
begin
  display_name := coalesce(
    nullif(trim(meta ->> 'first_name'), ''),
    nullif(trim(meta ->> 'full_name'), ''),
    nullif(trim(meta ->> 'name'), ''),
    nullif(
      trim(
        concat_ws(
          ' ',
          nullif(trim(meta ->> 'given_name'), ''),
          nullif(trim(meta ->> 'family_name'), '')
        )
      ),
      ''
    ),
    ''
  );

  base_handle := lower(
    coalesce(
      nullif(trim(meta ->> 'handle'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'user'
    )
  );
  base_handle := regexp_replace(base_handle, '[^a-z0-9_]', '', 'g');
  if length(base_handle) < 3 then
    base_handle := 'user' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;
  base_handle := left(base_handle, 20);
  candidate := base_handle;

  loop
    begin
      insert into public.profiles (id, first_name, handle)
      values (new.id, display_name, candidate)
      on conflict (id) do nothing;
      exit;
    exception
      when unique_violation then
        suffix := suffix + 1;
        candidate := left(base_handle, 16) || suffix::text;
        if suffix > 100 then
          candidate := 'user' || substr(replace(new.id::text, '-', ''), 1, 12);
          insert into public.profiles (id, first_name, handle)
          values (new.id, display_name, candidate)
          on conflict (id) do nothing;
          exit;
        end if;
    end;
  end loop;

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
