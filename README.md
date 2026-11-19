# Thought & Feelings

Thought & Feelings is a private, two-person journaling app by SphereLearn. The app requires an authenticated account before journal pages are accessible.

## Account and journal flows

- Email/password sign-up requires a first name and surname.
- Sign-in, password reset, session persistence, and sign-out use Supabase Auth.
- Each account opens a private journal by default.
- Entries are stored in Postgres and loaded for the active journal; journal text is not persisted to browser local storage.
- Journal members can reflect on entries and reply through security-definer RPCs. Direct row-level update access to another member's entry is not granted.
- Invitation links are token-based, stored as hashes, expire after seven days, and can be accepted by one other account.
- Journal membership and entry access are restricted by PostgreSQL row-level security.
- The old single-device writer switch, skip-onboarding path, and private-draft preview flow have been removed.

## Supabase setup

The repository includes migrations under `supabase/migrations/`. Apply them to the dedicated Thought & Feelings Supabase project before deploying this branch:

```bash
npm install
npx supabase login
npx supabase link --project-ref qkgzfizenhysoyixmzng
npx supabase db push
```

Confirm that the project's Auth email-confirmation settings and allowed redirect URLs include the production domain and its sign-in callback path. Never use the Examply Supabase project for Thought & Feelings.

The frontend currently initializes Supabase with the project's public publishable key. A publishable/anon key is expected to be exposed to the browser; database security must rely on RLS and restricted RPCs, never on secrecy of that key.

## Local development and build

```bash
npm install
npm run dev
npm run build
```

Deploy the repository root to Vercel with build command `npm run build` and output directory `dist`. The Vercel deployment and real account/journal flows must be verified after applying migrations; a source commit alone does not mean the production app is ready.

## Current boundaries

- Email/password authentication is implemented; Apple and Google OAuth are not configured.
- Notification settings are preferences only; push delivery is not implemented.
- Profile-picture upload is not implemented.
- Legacy entries saved by the previous local-only version are not automatically migrated into an account. They remain in the old browser storage key and are not shown in the authenticated journal.
- Apply migrations and test sign-up, email confirmation, sign-in, password reset, invite acceptance, RLS isolation, and cross-device entry visibility before treating the release as production-ready.

## Android

Capacitor 7 configuration is retained. After web build verification, run `npx cap sync android` and test the Android app before creating a signed release. Signing keys must not be committed to this repository.
