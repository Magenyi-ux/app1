-- Expose only the names of people who belong to the caller's active journal.
-- The caller must already be a member; no email addresses or auth metadata are returned.

create or replace function public.get_journal_member_profiles(p_journal_id uuid)
returns table(user_id uuid, display_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'Authentication is required.';
  end if;

  if not exists (
    select 1 from public.journal_members jm
     where jm.journal_id = p_journal_id
       and jm.user_id = caller_id
  ) then
    raise exception 'You do not have access to this journal.';
  end if;

  return query
    select jm.user_id, p.display_name
      from public.journal_members jm
      join public.profiles p on p.id = jm.user_id
     where jm.journal_id = p_journal_id
     order by jm.accepted_at asc;
end;
$$;

revoke all on function public.get_journal_member_profiles(uuid) from public, anon;
grant execute on function public.get_journal_member_profiles(uuid) to authenticated;
