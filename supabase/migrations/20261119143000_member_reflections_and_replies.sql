-- Concurrency guards and member-safe reflection/reply operations.
-- These RPCs let either journal member respond without granting broad UPDATE
-- access to another member's entry body or metadata.

create or replace function public.add_journal_entry_reflection(
  p_entry_id uuid,
  p_body text,
  p_question text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
     and exists (select 1 from public.journal_members jm where jm.journal_id = je.journal_id and jm.user_id = caller_id)
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

  update public.journal_entries
     set reflections = updated_reflections, updated_at = now()
   where id = p_entry_id;

  return updated_reflections;
end;
$$;

create or replace function public.add_journal_entry_reply(
  p_entry_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
     and exists (select 1 from public.journal_members jm where jm.journal_id = je.journal_id and jm.user_id = caller_id)
   for update;

  if not found then raise exception 'This entry is not available to your account.'; end if;

  select p.display_name into caller_name from public.profiles p where p.id = caller_id;
  updated_replies := coalesce(entry_row.replies, '[]'::jsonb) ||
    jsonb_build_array(jsonb_build_object(
      'writer', coalesce(caller_name, 'Member'),
      'body', trim(p_body),
      'createdAt', now()
    ));

  update public.journal_entries
     set replies = updated_replies, updated_at = now()
   where id = p_entry_id;

  return updated_replies;
end;
$$;

revoke all on function public.add_journal_entry_reflection(uuid, text, text) from public, anon;
revoke all on function public.add_journal_entry_reply(uuid, text) from public, anon;
grant execute on function public.add_journal_entry_reflection(uuid, text, text) to authenticated;
grant execute on function public.add_journal_entry_reply(uuid, text) to authenticated;
