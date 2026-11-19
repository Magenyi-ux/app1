# OurJournal by SphereLearn

A purple-and-grey, mobile-first journal concept for couples: write an entry, reflect before responding, explore thoughtful prompts, and revisit the shared history.

## Current prototype status

- Cloud-only enforcement: no offline journal storage or service-worker caching.
- Journal writes are blocked until authenticated Supabase persistence is connected; this build does not pretend local saves are cloud saves.
- Capacitor configuration for Android package name: name.spherelearn.ourjournal.
- Important: local prototype data is cleared and offline caching is disabled. Authenticated cloud persistence, private invitations, database access rules and cross-device sync must be implemented and tested before journal writing is enabled.

## Run locally

1. Install Node.js and npm.
2. Run npm install.
3. Run npm run dev for development or npm run build for production output.

## Android 10–15

Capacitor 7 supports Android projects targeting current Android SDKs; configure Android 10/API 29 as the minimum supported version and test API 29 through API 35. Install Android Studio and the Android SDK, then run npm install, npm run build, npx cap add android, npx cap sync android, and npx cap open android. A signed APK/AAB requires Android SDK setup and signing configuration; signing keys must not be committed to this repository.

## Hosting

Deploy the repository root to Vercel with build command npm run build and output directory dist. Proposed dedicated address: ourjournal.spherelearn.name.ng. Add the domain in Vercel and configure DNS only after the project is linked and ready.

## Product roadmap

1. Supabase Auth with per-person accounts and private journal membership.
2. Secure invite acceptance and prevent anyone outside the pair from reading entries.
3. Postgres tables and row-level security for journals, members, entries, and reflections.
4. Cross-device sync, notifications without sensitive entry previews, account export and deletion.
5. Android testing and signed release.
