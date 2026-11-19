-- Enforce single-use invitation tokens with a 20-minute lifetime.
alter table public.journal_invitations
  alter column expires_at set default (now() + interval '20 minutes');

create or replace function public.create_journal_invitation(p_journal_id uuid)
returns table(invite_token text, expires_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  generated_token text;
  invitation_expiry timestamptz;
  member_count integer;
begin
  if caller_id is null then raise exception 'Authentication is required.'; end if;
  if not exists (select 1 from public.journal_members jm where jm.journal_id=p_journal_id and jm.user_id=caller_id and jm.role='owner') then
    raise exception 'Only the journal owner can create an invitation.';
  end if;
  select count(*) into member_count from public.journal_members jm where jm.journal_id=p_journal_id;
  if member_count >= 2 then raise exception 'This journal already has two members.'; end if;
  update public.journal_invitations set revoked_at=now()
  where journal_id=p_journal_id and accepted_at is null and revoked_at is null and expires_at>now();
  generated_token := encode(extensions.gen_random_bytes(32),'hex');
  invitation_expiry := now()+interval '20 minutes';
  insert into public.journal_invitations(journal_id,created_by,token_hash,expires_at)
  values(p_journal_id,caller_id,encode(extensions.digest(generated_token,'sha256'),'hex'),invitation_expiry);
  return query select generated_token,invitation_expiry;
end; $$;

create or replace function public.accept_journal_invitation(p_token text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  invitation public.journal_invitations%rowtype;
  member_count integer;
begin
  if caller_id is null then raise exception 'Authentication is required.'; end if;
  if p_token is null or length(p_token)<>64 then raise exception 'This invitation link is invalid or expired.'; end if;
  select * into invitation from public.journal_invitations ji
  where ji.token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
  if not found or invitation.revoked_at is not null or invitation.expires_at<=now() then raise exception 'This invitation link is invalid or expired.'; end if;
  if invitation.accepted_at is not null then raise exception 'This invitation has already been used.'; end if;
  if invitation.created_by=caller_id then raise exception 'You cannot accept your own invitation.'; end if;
  perform 1 from public.journals j where j.id=invitation.journal_id for update;
  if not found then raise exception 'This journal is no longer available.'; end if;
  if exists(select 1 from public.journal_members jm where jm.user_id=caller_id) then raise exception 'This account already belongs to a journal.'; end if;
  select count(*) into member_count from public.journal_members jm where jm.journal_id=invitation.journal_id;
  if member_count>=2 then raise exception 'This journal already has two members.'; end if;
  insert into public.journal_members(journal_id,user_id,role) values(invitation.journal_id,caller_id,'member');
  update public.journal_invitations set accepted_by=caller_id,accepted_at=now() where id=invitation.id;
  return invitation.journal_id;
end; $$;

revoke all on function public.create_journal_invitation(uuid) from public,anon;
revoke all on function public.accept_journal_invitation(text) from public,anon;
grant execute on function public.create_journal_invitation(uuid) to authenticated;
grant execute on function public.accept_journal_invitation(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.journals enable row level security;
alter table public.journal_members enable row level security;
alter table public.journal_invitations enable row level security;
alter table public.journal_entries enable row level security;
revoke all on public.profiles,public.journals,public.journal_members,public.journal_invitations,public.journal_entries from anon;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update on public.journals to authenticated;
grant select,insert on public.journal_members to authenticated;
grant select,insert,update on public.journal_invitations to authenticated;
grant select,insert,update,delete on public.journal_entries to authenticated;
