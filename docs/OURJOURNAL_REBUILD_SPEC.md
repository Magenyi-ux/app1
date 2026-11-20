# OurJournal — Locked UI and Functional Specification

Status: implementation contract for the reference image supplied on 2026-11-19.

## Non-negotiable visual direction
- Use the supplied eight-screen reference as the visual source of truth.
- Brand: OurJournal; tagline: “Write. Understand. Grow.”
- Palette: dark plum / near-black plum, lavender, violet, and pale lavender paper.
- Use rounded cards and pills, restrained shadows, generous spacing, clean sans-serif headings, and consistent iconography.
- The welcome screen is dark; dashboard, writing, prompts, history, and settings use pale lavender surfaces; journal conversation and reflection views use dark plum surfaces.
- Mobile-first layout; no horizontal overflow on small phones; desktop should expand content without changing the visual language.
- Respect reduced-motion preferences and visible keyboard focus.

## Screen and navigation map
1. Welcome → Get Started / Sign In.
2. Home → latest entry, shared journal summary, daily prompt; bottom navigation to Home, Prompts, History, Profile.
3. Write an Entry → title, body, mood, optional prompt/tags, save as private draft or publish to shared journal.
4. Our Journal → chronological shared entries, reactions, bookmarks, replies, and entry details.
5. Thoughtful Prompts → prompt list and Surprise Me; selecting a prompt opens the editor with the prompt prefilled.
6. What I Heard You Say → selected entry plus partner reflection; reply creates a linked response.
7. Our History → All / Mine / Theirs filters and chronological timeline.
8. Profile and settings → profile, journal settings, privacy/security, notifications, About, export and logout.

## Required navigation relationships
- Welcome Get Started opens account creation; Sign In opens sign-in.
- Successful auth returns to the dashboard. Unauthenticated users cannot enter private journal routes.
- Home latest-entry cards open the matching entry/thread.
- Prompt cards open the editor with the selected prompt.
- Saving a shared entry returns to Home and updates the journal/timeline; saving a draft never publishes it.
- Selecting an entry opens its conversation; reflections and replies must retain the selected entry ID.
- History filters must change the actual displayed dataset, not just selected styling.
- Profile/settings controls must persist the corresponding preference.
- Logout must end the Supabase session and return to Welcome.

## Data and security contract
- Supabase Auth identifies each person. Never treat a display name or local writer toggle as authentication.
- A journal has members; each membership belongs to an authenticated user.
- Entries belong to a journal and author. Reflections and replies reference an entry and author. Reactions and bookmarks reference a user and entry.
- Row Level Security must restrict every read/write to journal membership. A user must not access another journal by changing an ID in the URL or client.
- Invite tokens must be high entropy, expiring, single-use, and validated server-side or through a constrained database function; never trust an arbitrary invite query parameter.
- Do not put service-role credentials in frontend code. Only the Supabase URL and anon/publishable key may be exposed in client configuration.
- Local storage may hold non-sensitive UI preferences and unsynced drafts only if clearly disclosed; it is not the source of truth for shared entries.
- Auth, membership, migrations, RLS policies, sync, and email confirmation must be tested before calling the application production-ready.

## Quality gates
- Build succeeds with the repository's documented production command.
- All eight screens render at mobile and desktop widths.
- All navigation actions above work; forms have validation, loading, success, and error states.
- Two separate accounts can join the same journal through a valid invite and see shared entries; unrelated accounts cannot.
- Reload and cross-device checks confirm cloud persistence.
- No production UI claims a local-only action is shared or secure.
