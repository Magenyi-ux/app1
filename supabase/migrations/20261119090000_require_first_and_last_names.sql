alter table public.profiles
  add constraint profiles_display_name_requires_first_and_last_name
  check (display_name ~ '^\S+\s+\S+.*$');

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text;
begin
  supplied_name := regexp_replace(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '\s+', ' ', 'g');
  if supplied_name !~ '^\S+\s+\S+.*$' then
    raise exception 'Please provide your first name and surname.';
  end if;
  insert into public.profiles (id, display_name)
  values (new.id, supplied_name)
  on conflict (id) do update set display_name = excluded.display_name;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;