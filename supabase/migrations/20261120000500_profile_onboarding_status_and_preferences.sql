-- OurJournal profile onboarding fields.
alter table public.profiles
  add column if not exists first_name text not null default '',
  add column if not exists last_name text not null default '',
  add column if not exists status text not null default 'Getting to know myself',
  add column if not exists bio text not null default '',
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists profile_preferences jsonb not null default '{}'::jsonb;

alter table public.profiles
  drop constraint if exists profiles_first_name_length_check,
  add constraint profiles_first_name_length_check check (char_length(first_name) <= 80),
  drop constraint if exists profiles_last_name_length_check,
  add constraint profiles_last_name_length_check check (char_length(last_name) <= 80),
  drop constraint if exists profiles_status_length_check,
  add constraint profiles_status_length_check check (char_length(status) <= 120),
  drop constraint if exists profiles_bio_length_check,
  add constraint profiles_bio_length_check check (char_length(bio) <= 280),
  drop constraint if exists profiles_preferences_object_check,
  add constraint profiles_preferences_object_check check (jsonb_typeof(profile_preferences) = 'object');

update public.profiles
set first_name = coalesce(nullif(first_name, ''), split_part(display_name, ' ', 1)),
    last_name = coalesce(nullif(last_name, ''), nullif(trim(substr(display_name, length(split_part(display_name, ' ', 1)) + 1)), ''))
where first_name = '' or last_name = '';

create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_profile_updated_at();
