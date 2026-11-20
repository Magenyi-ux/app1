-- Multiple personal/shared journals and safe multi-journal invitation acceptance.
-- Apply this migration to the linked Supabase project before enabling the UI in production.

alter table public.journals
  add column if not exists journal_type text not null default 'shared'
  check (journal_type in ('personal', 'shared'));

create index if not exists journals_created_by_updated_at_idx
  on public.journals (created_by, updated_at desc);

create or replace function public.create_journal(
  p_title text default 'Untitled journal',
  p_type text default 'shared'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  new_journal_id uuid;
  clean_title text := left(btrim(coalesce(p_title, '')), 120);
  clean_type text := lower(btrim(coalesce(p_type, 'shared')));
begin
  if caller_id is null then
    raise exception 'Authentication is required.';
  end if;
  if clean_type not in ('personal', 'shared') then
    raise exception 'Choose a personal or shared journal.';
  end if;
  if clean_title = '' then clean_title := 'Untitled journal'; end if;

  insert into public.journals(title, created_by, journal_type)
  values (clean_title, caller_id, clean_type)
  returning id into new_journal_id;

  insert into public.journal_members(journal_id, user_id, role)
  values (new_journal_id, caller_id, 'owner');

  return new_journal_id;
end;
$function$;

revoke all on function public.create_journal(text, text) from public;
revoke all on function public.create_journal(text, text) from anon;
grant execute on function public.create_journal(text, text) to authenticated;

create or replace function public.accept_journal_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  invitation public.journal_invitations%rowtype;
  member_count integer;
begin
  if caller_id is null then raise exception 'Authentication is required.'; end if;
  if p_token is null or length(p_token) <> 64 then
    raise exception 'This invitation link is invalid or expired.';
  end if;

  select * into invitation
  from public.journal_invitations ji
  where ji.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;

  if not found or invitation.revoked_at is not null or invitation.expires_at <= now() then
    raise exception 'This invitation link is invalid or expired.';
  end if;
  if invitation.accepted_at is not null then raise exception 'This invitation has already been used.'; end if;
  if invitation.created_by = caller_id then raise exception 'You cannot accept your own invitation.'; end if;
  if exists (
    select 1 from public.journal_members jm
    where jm.journal_id = invitation.journal_id and jm.user_id = caller_id
  ) then raise exception 'You are already a member of this journal.'; end if;

  perform 1 from public.journals j where j.id = invitation.journal_id for update;
  if not found then raise exception 'This journal is no longer available.'; end if;

  -- Remove only an unused signup placeholder; preserve any real personal journals.
  delete from public.journal_members jm
  using public.journals j
  where jm.journal_id = j.id
    and jm.user_id = caller_id
    and j.created_by = caller_id
    and j.title = 'Our Journal'
    and not exists (
      select 1 from public.journal_entries je where je.journal_id = j.id
    )
    and not exists (
      select 1 from public.journal_members other
      where other.journal_id = j.id and other.user_id <> caller_id
    );

  delete from public.journals j
  where j.created_by = caller_id
    and j.title = 'Our Journal'
    and not exists (select 1 from public.journal_members jm where jm.journal_id = j.id)
    and not exists (select 1 from public.journal_entries je where je.journal_id = j.id);

  select count(*) into member_count
  from public.journal_members jm where jm.journal_id = invitation.journal_id;
  if member_count >= 2 then raise exception 'This journal already has two members.'; end if;

  insert into public.journal_members(journal_id, user_id, role)
  values (invitation.journal_id, caller_id, 'member');

  update public.journal_invitations
  set accepted_by = caller_id, accepted_at = now()
  where id = invitation.id;

  return invitation.journal_id;
end;
$function$;

revoke all on function public.accept_journal_invitation(text) from public;
grant execute on function public.accept_journal_invitation(text) to authenticated;

-- Invitation RPC must enforce the personal/shared boundary server-side.
create or replace function public.create_journal_invitation(p_journal_id uuid)
returns table(invite_token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  caller_id uuid := auth.uid();
  generated_token text;
  invitation_expiry timestamptz;
  member_count integer;
begin
  if caller_id is null then raise exception 'Authentication is required.'; end if;
  if not exists (
    select 1 from public.journal_members jm
    where jm.journal_id = p_journal_id and jm.user_id = caller_id and jm.role = 'owner'
  ) then raise exception 'Only the journal owner can create an invitation.'; end if;
  if exists (
    select 1 from public.journals j
    where j.id = p_journal_id and j.journal_type = 'personal'
  ) then raise exception 'Personal journals cannot be shared. Create a shared journal to invite someone.'; end if;

  select count(*) into member_count from public.journal_members jm where jm.journal_id = p_journal_id;
  if member_count >= 2 then raise exception 'This journal already has two members.'; end if;

  update public.journal_invitations ji
  set revoked_at = now()
  where ji.journal_id = p_journal_id and ji.accepted_at is null
    and ji.revoked_at is null and ji.expires_at > now();

  generated_token := encode(extensions.gen_random_bytes(32), 'hex');
  invitation_expiry := now() + interval '20 minutes';
  insert into public.journal_invitations(journal_id, created_by, token_hash, expires_at)
  values (p_journal_id, caller_id, encode(extensions.digest(generated_token, 'sha256'), 'hex'), invitation_expiry);
  return query select generated_token, invitation_expiry;
end;
$function$;

revoke all on function public.create_journal_invitation(uuid) from public;
revoke all on function public.create_journal_invitation(uuid) from anon;
grant execute on function public.create_journal_invitation(uuid) to authenticated;
