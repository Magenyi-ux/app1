-- Secure journal bootstrap and invitation lifecycle for Thought & Feelings.
-- All RPCs derive the caller from auth.uid(); callers cannot nominate another user.

create or replace function public.get_or_create_private_journal()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  selected_journal_id uuid;
begin
  if caller_id is null then
    raise exception 'Authentication is required.';
  end if;

  select jm.journal_id
    into selected_journal_id
    from public.journal_members jm
   where jm.user_id = caller_id
   order by jm.accepted_at desc, case when jm.role = 'owner' then 0 else 1 end
   limit 1;

  if selected_journal_id is not null then
    return selected_journal_id;
  end if;

  insert into public.journals (title, created_by)
  values ('Thought & Feelings', caller_id)
  returning id into selected_journal_id;

  insert into public.journal_members (journal_id, user_id, role)
  values (selected_journal_id, caller_id, 'owner');

  return selected_journal_id;
end;
$$;

create or replace function public.create_journal_invitation(p_journal_id uuid)
returns table(invite_token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  generated_token text;
  invitation_expiry timestamptz;
  member_count integer;
begin
  if caller_id is null then
    raise exception 'Authentication is required.';
  end if;

  if not exists (
    select 1 from public.journal_members jm
     where jm.journal_id = p_journal_id and jm.user_id = caller_id
  ) then
    raise exception 'You do not have access to this journal.';
  end if;

  select count(*) into member_count
    from public.journal_members jm
   where jm.journal_id = p_journal_id;

  if member_count >= 2 then
    raise exception 'This journal already has two members.';
  end if;

  update public.journal_invitations ji
     set revoked_at = now()
   where ji.journal_id = p_journal_id
     and ji.accepted_at is null
     and ji.revoked_at is null
     and ji.expires_at > now();

  generated_token := encode(extensions.gen_random_bytes(32), 'hex');
  invitation_expiry := now() + interval '7 days';

  insert into public.journal_invitations
    (journal_id, created_by, token_hash, expires_at)
  values
    (p_journal_id, caller_id, encode(extensions.digest(generated_token, 'sha256'), 'hex'), invitation_expiry);

  return query select generated_token, invitation_expiry;
end;
$$;

create or replace function public.accept_journal_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  invitation public.journal_invitations%rowtype;
  member_count integer;
begin
  if caller_id is null then
    raise exception 'Authentication is required.';
  end if;

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

  if invitation.accepted_at is not null then
    if invitation.accepted_by = caller_id then
      return invitation.journal_id;
    end if;
    raise exception 'This invitation has already been accepted.';
  end if;

  if invitation.created_by = caller_id then
    raise exception 'You cannot accept your own invitation.';
  end if;

  if exists (
    select 1 from public.journal_members jm
     where jm.journal_id = invitation.journal_id and jm.user_id = caller_id
  ) then
    update public.journal_invitations
       set accepted_by = caller_id, accepted_at = now()
     where id = invitation.id;
    return invitation.journal_id;
  end if;

  select count(*) into member_count
    from public.journal_members jm
   where jm.journal_id = invitation.journal_id;

  if member_count >= 2 then
    raise exception 'This journal already has two members.';
  end if;

  insert into public.journal_members (journal_id, user_id, role)
  values (invitation.journal_id, caller_id, 'member');

  update public.journal_invitations
     set accepted_by = caller_id, accepted_at = now()
   where id = invitation.id;

  return invitation.journal_id;
end;
$$;

create or replace function public.revoke_journal_invitation(p_journal_id uuid)
returns boolean
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

  update public.journal_invitations
     set revoked_at = now()
   where journal_id = p_journal_id
     and created_by = caller_id
     and accepted_at is null
     and revoked_at is null;

  return found;
end;
$$;

revoke all on function public.get_or_create_private_journal() from public, anon;
revoke all on function public.create_journal_invitation(uuid) from public, anon;
revoke all on function public.accept_journal_invitation(text) from public, anon;
revoke all on function public.revoke_journal_invitation(uuid) from public, anon;

grant execute on function public.get_or_create_private_journal() to authenticated;
grant execute on function public.create_journal_invitation(uuid) to authenticated;
grant execute on function public.accept_journal_invitation(text) to authenticated;
grant execute on function public.revoke_journal_invitation(uuid) to authenticated;
