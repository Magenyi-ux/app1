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
