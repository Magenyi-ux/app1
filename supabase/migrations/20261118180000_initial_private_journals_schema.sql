create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(display_name) <= 80)
);
create table public.journals (
  id uuid primary key default gen_random_uuid(),
  title text not null default 'Thought & Feelings',
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint journals_title_length check (char_length(title) between 1 and 120)
);
create table public.journal_members (
  journal_id uuid not null references public.journals(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  accepted_at timestamptz not null default now(),
  primary key (journal_id, user_id)
);
create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.journals(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null,
  mood text,
  prompt text,
  reflections jsonb not null default '[]'::jsonb,
  replies jsonb not null default '[]'::jsonb,
  is_saved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint journal_entries_body_length check (char_length(body) between 1 and 50000),
  constraint journal_entries_title_length check (char_length(title) <= 200),
  constraint journal_entries_reflections_array check (jsonb_typeof(reflections) = 'array'),
  constraint journal_entries_replies_array check (jsonb_typeof(replies) = 'array')
);
create table public.journal_invitations (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.journals(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint journal_invitations_acceptance_consistent check ((accepted_by is null and accepted_at is null) or (accepted_by is not null and accepted_at is not null))
);
create index journal_members_user_id_idx on public.journal_members(user_id);
create index journal_entries_journal_created_idx on public.journal_entries(journal_id, created_at desc);
create index journal_invitations_journal_id_idx on public.journal_invitations(journal_id);

alter table public.profiles enable row level security;
alter table public.journals enable row level security;
alter table public.journal_members enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_invitations enable row level security;

create policy "Users can view their own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "Users can create their own profile" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "Users can update their own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "Journal members can view journals" on public.journals for select to authenticated using (exists (select 1 from public.journal_members jm where jm.journal_id = journals.id and jm.user_id = (select auth.uid())));
create policy "Authenticated users can create journals" on public.journals for insert to authenticated with check (created_by = (select auth.uid()));
create policy "Journal owners can update journals" on public.journals for update to authenticated using (created_by = (select auth.uid()) and exists (select 1 from public.journal_members jm where jm.journal_id = journals.id and jm.user_id = (select auth.uid()) and jm.role = 'owner')) with check (created_by = (select auth.uid()));

create policy "Users can view their own memberships" on public.journal_members for select to authenticated using (user_id = (select auth.uid()));
create policy "Creators can add themselves as owner" on public.journal_members for insert to authenticated with check (user_id = (select auth.uid()) and role = 'owner' and exists (select 1 from public.journals j where j.id = journal_id and j.created_by = (select auth.uid())));

create policy "Members can view journal entries" on public.journal_entries for select to authenticated using (exists (select 1 from public.journal_members jm where jm.journal_id = journal_entries.journal_id and jm.user_id = (select auth.uid())));
create policy "Members can create entries as themselves" on public.journal_entries for insert to authenticated with check (author_id = (select auth.uid()) and exists (select 1 from public.journal_members jm where jm.journal_id = journal_entries.journal_id and jm.user_id = (select auth.uid())));
create policy "Authors can update their entries" on public.journal_entries for update to authenticated using (author_id = (select auth.uid()) and exists (select 1 from public.journal_members jm where jm.journal_id = journal_entries.journal_id and jm.user_id = (select auth.uid()))) with check (author_id = (select auth.uid()) and exists (select 1 from public.journal_members jm where jm.journal_id = journal_entries.journal_id and jm.user_id = (select auth.uid())));
create policy "Authors can delete their entries" on public.journal_entries for delete to authenticated using (author_id = (select auth.uid()) and exists (select 1 from public.journal_members jm where jm.journal_id = journal_entries.journal_id and jm.user_id = (select auth.uid())));

create policy "Journal owners can view invitations" on public.journal_invitations for select to authenticated using (created_by = (select auth.uid()));
create policy "Journal owners can create invitations" on public.journal_invitations for insert to authenticated with check (created_by = (select auth.uid()) and exists (select 1 from public.journal_members jm where jm.journal_id = journal_invitations.journal_id and jm.user_id = (select auth.uid()) and jm.role = 'owner'));
create policy "Journal owners can revoke invitations" on public.journal_invitations for update to authenticated using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.journals to authenticated;
grant select, insert on public.journal_members to authenticated;
grant select, insert, update, delete on public.journal_entries to authenticated;
grant select, insert, update on public.journal_invitations to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
