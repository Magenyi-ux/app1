-- Notification inbox for Thought & Feelings.
-- User-scoped rows and RLS ensure notification content is visible only to its recipient.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('journal_invite','invite_accepted','journal_entry','journal_reply','reflection','reminder','system')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null default '' check (char_length(body) <= 240),
  journal_id uuid references public.journals(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action_path text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_created_idx
  on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_unread_idx
  on public.notifications (recipient_id, created_at desc)
  where read_at is null;

alter table public.notifications enable row level security;
revoke all on public.notifications from anon;
grant select, update on public.notifications to authenticated;

drop policy if exists "Recipients can read their notifications" on public.notifications;
create policy "Recipients can read their notifications"
  on public.notifications for select to authenticated
  using ((select auth.uid()) = recipient_id);

drop policy if exists "Recipients can mark their notifications read" on public.notifications;
create policy "Recipients can mark their notifications read"
  on public.notifications for update to authenticated
  using ((select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = recipient_id);

-- Inserts are intentionally not granted to clients. Trusted database functions/triggers
-- will create notifications; clients cannot forge notifications for other accounts.

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  in_app_enabled boolean not null default true,
  journal_activity_enabled boolean not null default true,
  reminders_enabled boolean not null default false,
  quiet_hours_enabled boolean not null default true,
  quiet_hours_start time not null default '22:00',
  quiet_hours_end time not null default '08:00',
  updated_at timestamptz not null default now(),
  constraint quiet_hours_valid check (
    quiet_hours_start >= time '00:00' and quiet_hours_start < time '24:00'
    and quiet_hours_end >= time '00:00' and quiet_hours_end < time '24:00'
  )
);

alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from anon;
grant select, insert, update on public.notification_preferences to authenticated;

drop policy if exists "Users can read their notification preferences" on public.notification_preferences;
create policy "Users can read their notification preferences"
  on public.notification_preferences for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their notification preferences" on public.notification_preferences;
create policy "Users can create their notification preferences"
  on public.notification_preferences for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their notification preferences" on public.notification_preferences;
create policy "Users can update their notification preferences"
  on public.notification_preferences for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter table public.notifications replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
