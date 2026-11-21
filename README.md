# Thought & Feelings by SphereLearn

A mobile-first shared journal for two people. The app uses Supabase Auth, Postgres row-level security, secure one-time invitations, and private profile storage.

## Implemented application flows

- Welcome-first onboarding, email/password registration and sign-in.
- Email confirmation and password recovery redirects back to the app.
- Profile display name, compressed profile photo, appearance and reminder preferences.
- Create a journal, then generate a single-use invitation link.
- Accept an invitation after account creation or sign-in; invitation context is retained through email confirmation.
- Share/copy a link or prepare an email invitation in the user's email app.
- Shared entries and author-only private entries, with database RLS enforcing visibility.
- Shared reflections and replies through authenticated RPCs.
- Profile and preference persistence; shared journal entries load from Supabase across devices.
- Local-only private drafts and export.

## Required Vercel environment variables

Set these for Preview and Production:

- `VITE_SUPABASE_URL` — the Supabase project URL.
- `VITE_SUPABASE_PUBLISHABLE_KEY` — the project's publishable key (or the legacy `VITE_SUPABASE_ANON_KEY`).

Never put a Supabase service-role key in frontend environment variables.

## Authentication configuration

In Supabase Auth URL configuration, allow the app's actual production origin (intended domain: `https://tf.spherelearn.name.ng`) and any preview URLs needed for testing. Configure the email templates and SMTP sender so confirmation and password-reset emails return to the requested redirect URL.

## Invitation behaviour

Invitation tokens are random, single-use, hashed in the database, and expire after 20 minutes. Opening an invitation link shows the welcome/account flow, not a journal preview. After authentication and any required email confirmation, the invitee must accept the invitation. The creator can share the link or open an email draft containing it; this email-draft option uses the device's mail app and is not a server-sent email service.

## Privacy and limitations

- RLS restricts journal data to members; private entries are visible only to their author.
- Profile photos are resized before upload to the private `profile-avatars` bucket.
- Private drafts are stored locally on the current device and do not sync.
- Reminder preferences are stored, but push notifications are not implemented.
- A complete production release still requires end-to-end testing of confirmation/reset redirects on the live domain, both participant accounts, private-entry isolation, and invitation expiry/revocation.

## Local development

1. Install Node.js and npm.
2. Set the two Vite environment variables above.
3. Run `npm install`.
4. Run `npm run dev` or `npm run build`.

## Android

Capacitor is configured for Android package `name.spherelearn.ourjournal`. Run `npm run android:sync` after installing dependencies and configuring the Android SDK. A signed APK/AAB requires signing configuration; never commit signing keys.


## Journal library implementation (branch: `feat/journal-library-offline-editor`)

This branch adds a multi-journal library with personal/shared types, journal selection, entry search, a local autosaving Notes-style editor draft, queued offline entry writes, cached journal entries, and app-shell caching through the existing `sw.js` service worker. Supabase client code is bundled with Vite so the app shell does not depend on loading the client from a CDN at runtime.

### Database migration required

Before using the new journal-creation action in any deployed environment, apply `supabase/migrations/20261120180000_multiple_journals.sql` to the matching Supabase project. It adds the `journal_type` column, the authenticated `create_journal(p_title, p_type)` RPC, prevents personal journals from issuing invitations, and updates invitation acceptance so an account can join another journal without losing existing journals. This migration has **not** been applied by this branch workflow.

### Verification checklist

- [ ] Build with `npm install` then `npm run build`.
- [ ] Create two personal journals, switch between them, and verify entries remain scoped to the selected journal.
- [ ] Verify personal journals cannot issue invitations; shared journals can invite by link or prepared email.
- [ ] Create a shared journal, invite a second account, accept the invitation, and verify both accounts can access only their memberships.
- [ ] Create a private entry and confirm it is absent from the other member's query results and UI.
- [ ] Search by title and body text.
- [ ] Type a draft, refresh the app, and verify the draft restores on the same device.
- [ ] With network disabled after the app has loaded once, verify cached entries remain readable and new entries are queued locally.
- [ ] Restore connectivity and verify queued entries sync once, without duplicate entries.
- [ ] Test invite expiry, reused invite links, and account sign-out.
- [ ] Perform end-to-end tests with two real accounts before production deployment.


## Web push notifications (setup required)

The app now includes an opt-in device notification panel and a service worker handler for notifications while the PWA is backgrounded or closed. The user must enable browser permission on each device. Web Push is not supported by every browser/device combination.

Before this can deliver notifications, configure the Supabase project:

1. Apply `supabase/migrations/20261121123000_push_subscriptions.sql` after the notification inbox migration.
2. Generate a VAPID key pair using a trusted Web Push key generator or the `web-push` package. Store **only** the public key in `VAPID_PUBLIC_KEY`; store the private key in Supabase Edge Function secrets as `VAPID_PRIVATE_KEY`. Set `VAPID_SUBJECT` to a valid `mailto:` contact. Never place the private key in Vite/frontend variables.
3. Deploy `supabase/functions/push-notifications/index.ts` as the `push-notifications` Edge Function with JWT verification enabled. Confirm the standard `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` Edge Function secrets are available.
4. Build and test on HTTPS. Sign in, open Profile/Settings, enable notifications, then use “Send test notification”. Verify the notification arrives with the app backgrounded.

The current Edge Function supports secure subscription registration and a self-test. Automated push delivery for journal invitations, replies, reflections, and reminders must be connected to their trusted server-side event handlers before those events will send device notifications. The app does not send private journal text in push previews. Do not deploy until the migration, Edge Function secrets, and end-to-end tests are complete.
