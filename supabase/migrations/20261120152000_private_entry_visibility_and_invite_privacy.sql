-- Add per-entry visibility and ensure private entries cannot be read or reflected on by another member.
alter table public.journal_entries
  add column if not exists visibility text not null default 'shared';

alter table public.journal_entries
  drop constraint if exists journal_entries_visibility_check;

alter table public.journal_entries
  add constraint journal_entries_visibility_check
  check (visibility in ('shared', 'private'));

drop policy if exists "Members can view journal entries" on public.journal_entries;
create policy "Members can view visible journal entries"
on public.journal_entries
for select
to authenticated
using (
  (visibility = 'shared' or author_id = (select auth.uid()))
  and exists (
    select 1 from public.journal_members jm
    where jm.journal_id = journal_entries.journal_id
      and jm.user_id = (select auth.uid())
  )
);

create or replace function public.add_journal_entry_reflection(
  p_entry_id uuid, p_body text, p_question text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  entry_row public.journal_entries%rowtype;
  caller_name text;
  updated_reflections jsonb;
begin
  if caller_id is null then raise exception 'Authentication is required.'; end if;
  if p_body is null or length(trim(p_body)) < 1 or length(p_body) > 20000 then
    raise exception 'Write a reflection before saving.';
  end if;
  select * into entry_row
  from public.journal_entries je
  where je.id = p_entry_id
    and (je.visibility = 'shared' or je.author_id = caller_id)
    and exists (
      select 1 from public.journal_members jm
      where jm.journal_id = je.journal_id and jm.user_id = caller_id
    )
  for update;
  if not found then raise exception 'This entry is not available to your account.'; end if;
  select p.display_name into caller_name from public.profiles p where p.id = caller_id;
  updated_reflections := coalesce(entry_row.reflections, '[]'::jsonb) ||
    jsonb_build_array(jsonb_build_object(
      'writer', coalesce(caller_name, 'Member'),
      'body', trim(p_body),
      'question', nullif(trim(coalesce(p_question, '')), ''),
      'createdAt', now()
    ));
  update public.journal_entries set reflections = updated_reflections, updated_at = now()
  where id = p_entry_id;
  return updated_reflections;
end;
$function$;

create or replace function public.add_journal_entry_reply(
  p_entry_id uuid, p_body text
) returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  entry_row public.journal_entries%rowtype;
  caller_name text;
  updated_replies jsonb;
begin
  if caller_id is null then raise exception 'Authentication is required.'; end if;
  if p_body is null or length(trim(p_body)) < 1 or length(p_body) > 20000 then
    raise exception 'Write a response before saving.';
  end if;
  select * into entry_row
  from public.journal_entries je
  where je.id = p_entry_id
    and (je.visibility = 'shared' or je.author_id = caller_id)
    and exists (
      select 1 from public.journal_members jm
      where jm.journal_id = je.journal_id and jm.user_id = caller_id
    )
  for update;
  if not found then raise exception 'This entry is not available to your account.'; end if;
  select p.display_name into caller_name from public.profiles p where p.id = caller_id;
  updated_replies := coalesce(entry_row.replies, '[]'::jsonb) ||
    jsonb_build_array(jsonb_build_object(
      'writer', coalesce(caller_name, 'Member'),
      'body', trim(p_body),
      'createdAt', now()
    ));
  update public.journal_entries set replies = updated_replies, updated_at = now()
  where id = p_entry_id;
  return updated_replies;
end;
$function$;

-- Invitation previews are not used by the account-first onboarding flow.
revoke execute on function public.preview_journal_invitation(text) from anon;
grant execute on function public.preview_journal_invitation(text) to authenticated;
