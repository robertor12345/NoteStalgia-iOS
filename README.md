# NoteStalgia — iOS

A person-centred **music-reminiscence and sensory-calm POC** for UK care homes. Built in SwiftUI
for **iPad** (also runs on iPhone with proportional scaling). Formerly “Mellority Flow”; product
name is **NoteStalgia** (“Sound that takes you back”).

| | |
|---|---|
| Bundle ID | `com.notestalgia.ios` |
| Display name | NoteStalgia |
| Deployment | iOS 17+ |
| Sibling | [`../NoteStalgia-Android`](../NoteStalgia-Android) (Kotlin + Jetpack Compose) |
| Generate project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` |

> **Agent handoff:** start with [`AGENTS.md`](AGENTS.md) and [`docs/HANDOFF_PLAN.md`](docs/HANDOFF_PLAN.md).
> Product/architecture decisions are catalogued below and in [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md).

---

## Quick start

```bash
cd NoteStalgia-iOS
brew install xcodegen   # if needed
xcodegen generate
open NoteStalgia-iOS.xcodeproj
```

Or CLI:

```bash
xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```

**Demo credentials (in-memory mock tenancy)**

| Email | PIN | Role |
|---|---|---|
| `max@sunrise-care.co.uk` | `123456` | Single-home supervisor |
| `alex@sunrise-care.co.uk` | `123456` | Multi-home lead → Home Admin dashboard |
| `claire@example.com` | `123456` | **Care at home** — family member caring for Harold T. (fortnight of history) |

Anyone can also create a Care at home account from the sign-in screen (any non-organisation email +
a chosen PIN); it is stored on the device.

Signing: Automatic. Local Xcode may set `DEVELOPMENT_TEAM` (e.g. `23CGZDXP4Q`); `project.yml` leaves it blank for regenerating machines.

---

## Product flow (POC)

```
Launch / splash
  → Email + 6-digit PIN  (care-home staff, or a Care at home account)
  → (multi-home) home picker
  → Welcome
  → Curated roster (pin / recent / due / wing / search / browse-all)
       ├─ Resident detail → session prep → resident calm surface → post-session sentiment → insight
       ├─ Discovery (new resident) → age + nationality → traffic-light clips → profile → calm surface
       ├─ Group activities → planner (suggested activities · staff suggestions · pick residents · engagement) → compiled playlist → group check-in
       └─ (home admin) Insights dashboard

Care at home (family member / private carer, one resident)
  Sign-in → "Caring for someone at home? Create an account"
  → name · email · family member / private carer · PIN
  → "Who are you caring for?" (name · age · nationality · optional photo)
       ├─ Start listening discovery → clips → calm surface → observation → summary → home
       └─ Set up without discovery → home
  → Home screen: Open calm surface · Insights & trends · Profile & preferences · Listening discovery
```

Everything is **on-device / in-memory** (mocked org, homes, roster, analytics). No backend yet.

---

## Repo layout

```
App/           App entry, Info.plist, Assets.xcassets, Resources/Music (bundled MP3s)
Core/          Domain models, stores, audio, orb, brand, caches
Flow/          FlowRootView — phase switch + ambient backdrop
Screens/       SwiftUI screens by surface
docs/          Implementation plan, pitch deck, handoff plan
project.yml    XcodeGen source of truth
AGENTS.md      Conventions for coding agents (Claude Code; imported by CLAUDE.md)
CLAUDE.md      Claude Code entry point (imports AGENTS.md)
```

`SessionPOCState` is a **coordinator** over domain stores (`SupervisorAuthStore`, `CareDataStore`,
`CareRosterUIStore`, `ResidentSurfaceStore`, `GroupSessionStore`, …) with selective
`objectWillChange` forwarding so keystroke/auth churn does not redraw 60fps orb/sparkle canvases.

---

## Catalogue of decisions (POC → now)

Decisions below are **locked for the POC** unless a product owner explicitly revises them.
Production cloud/auth/data decisions live in `docs/IMPLEMENTATION_PLAN.md` §2.

### Brand & naming

| Decision | Choice |
|---|---|
| Product name | **NoteStalgia** (not Mellority) |
| Visual identity | A luminous silk-and-energy orb (lilac · pink · periwinkle · teal, drawn on the GPU — see **Orb renderer** below) on a mid-indigo canvas (`#4A4488 → #32326E`, a lighter version of the reference clip's near-black navy), half-transparent dark cards with cyan icon headers, pastel accents (not traffic-light primaries on resident music surface). No ring around the orb |
| System appearance | App forces **dark** (`AppRootView.preferredColorScheme(.dark)`) so status bar, steppers, segmented pickers, menus and placeholders stay legible on the dark cards |
| Primary device | **iPad**; iPhone supported with `BrandLayout` compact scaling |
| Auth UX | Work email + **6-digit PIN** (not Face ID for staff in this build) |

### Care / tenancy model

| Decision | Choice |
|---|---|
| Hierarchy | Organisation → Care home (+ wings) → Supervisor accounts |
| Roles | `supervisor` / `homeLead` / `orgAdmin` (`isHomeAdmin` gates dashboard) |
| Roster | Curated: pinned, recent, due, search, browse-all (`CareRosterEngine`). A **wing chip filters every section** (and browse-all) to that wing; search always spans the whole home |
| Roster cards | Subtitle is "room · wing · Last visit {today/yesterday/N days ago} · N% at ease" — full sentiment averages live on the profile |
| Resident profile | **"Open resident calm surface" sits directly under the name** (primary action above the fold) |
| Group mode | Playlist only contains titles with bundled audio, and plays **the track it lists** (was always the ambient loop) |
| Nationality | Soft bias only — discovery order + genre candidates (`ResidentNationalityMusicBias`); **not** hard filtering |
| Resident portraits | **12 bundled photos** (`PortraitWoman01–06`, `PortraitMan01–06`, `App/Assets.xcassets`), assigned deterministically per resident by first-name gender + `StableHash(displayName) % 6` (`ResidentPortraitCatalog`). No network, no placeholder, nothing ever swaps; pre-decoded at launch. 12 faces across 37 mock residents → repeats are expected in the POC. A captured photo always wins. **Pool order is part of the resident→face contract** |
| Pinned section | Ordered **A–Z** (was recent-first, which reshuffled the cards every time one was opened) |
| Face ID linking | Present in code; **drop for v1 production** |
| IoT / Hue / HomeKit | Stubbed; **out of scope for v1** |

### Resident calm surface

| Decision | Choice |
|---|---|
| Genre UI | Floating **designer circular artwork** glyphs (not SF Symbols) — assets `GenreJazz` … `GenreSoul` |
| Comfort dock | Always-on **sun (like)** / **cloud (skip + remove from session queue)** while playing. The sun and cloud are flat shapes drawn in code (`Core/ComfortGlyphs.swift`: a disc with eight round-capped rays; three round bumps on a rounded base) in white with a hard-edged offset shadow, on the same yellow and grey pucks as before; the same glyphs mark "Enjoyed" / "Moved on from" in the session summary and Care at home insights instead of `sun.max.fill` / `cloud.fill` |
| Staff return | Corner button is **press-and-hold (0.8 s)** with a filling ring; a quick tap only shows "Staff: press and hold" so residents can't end their own session |
| Media | Mood-matched stills (`MusicVisualMood` + Wikimedia scene URLs); orb morphs circle → full-page on play — full-page covers the **whole screen** incl. status bar (sized from `flowSafeAreaInsets`) |
| Audio | Offline: bundled MP3s in `App/Resources/Music` via `BundledAudio` / `ResidentPlaybackTrackCatalog`. With a backend configured: Apple Music 30 s previews from the resolved catalogue, streamed from Apple's CDN (see **Backend, song catalogue & discovery model**) |
| Telemetry | Likes, skips, rage bursts, dwell → `ResidentSurfaceSessionMetrics` → session record + preference boosts; online, one signals batch per session to `/residents/{id}/signals` |
| Equalizer | Live PCM reactive spectrum (`MusicReactiveAnalyzer`) around the hero glyph and the discovery orb. With the GPU renderer it is a **glowing waveform that hugs the rim and sends wavefronts off it on the beat** (`waveFragment` in `OrbFlow.msl`; `Core/OrbWaveBursts.swift`: `OrbWaveModel` smooths the 32 bands — quick up, slower down — detects a hit in the low bands and keeps up to six live bursts, each carrying the spectrum it was born with; Reduce Motion keeps the level but sends no wavefronts). Without Metal it keeps the old radial bars |

### Track → genre → icon map (audible catalog)

Single source of truth: `Core/ResidentPlaylistVisuals.swift` (`ResidentPlaybackTrackCatalog`) and
Android `PlaybackCatalog.kt`. **One primary stem per genre** (no cross-genre duplicates).

| Track (bundled MP3) | Genre | Designer icon asset |
|---|---|---|
| Velvet Afterhours | Jazz | `GenreJazz` (sax) |
| Velvet Cadenza | Classical | `GenreClassical` (piano) |
| Echoes of Yesterday | Pop | `GenrePop` (solo mic) |
| Velvet Highway | Rock | `GenreRock` (jukebox) |
| Pine Smoke Drift | Country | `GenreCountry` (violin) |
| Pine Smoke Drift (1) | Gospel | `GenreGospel` (opera singer) — **interim** until a choir/gospel stem exists |
| Drift Between Rooms | Soul | `GenreSoul` (woman + mic) |

Discovery snippet order / moods must stay aligned with these stems (`DiscoveryEraMedia` /
`DiscoveryFlowPOC.snippetAudioStreamURLs`).
Discovery auditions **all 7 stems** (one snippet per genre: Pop, Rock, Classical, Jazz, Gospel,
Soul, Country) before age/nationality reordering. *Android `calibrationMoods` not yet aligned.*
With a backend configured the stems are the **offline fallback**: the audible catalogue is the
resolved iTunes seed and discovery plays seven catalogue previews chosen by the Worker (next section).

### Backend, song catalogue & discovery model (POC, Oct 2026)

| Decision | Choice |
|---|---|
| Backend | **Cloudflare Worker + D1 on the free tier**, sibling repo `../NoteStalgia-Backend` (Hono, TypeScript, vitest). It implements the v1 resource contract (`contracts/openapi.yaml`) that the production AWS/.NET stack will serve — a stepping stone, not a competing architecture (`docs/IMPLEMENTATION_PLAN.md` §0) |
| Switching it on | Launch argument `-NoteStalgiaAPIBaseURL http://localhost:8787` (or the deployed `workers.dev` URL; the client appends `/v1`). **No base URL = today's offline behaviour** (in-memory seed, bundled stems, on-device discovery heuristic), so the recorded demo never breaks |
| Offline-first sync | The iOS stores stay the UI's source of truth. `Core/Sync/SyncEngine` pulls each home by server **seq** cursor (never client time), observes the stores (0.8 s debounce) and pushes an on-disk outbox; residents are last-writer-wins by `updatedAt`, sessions / group sessions are immutable and deduped by id; portraits upload as ≤ 600 px JPEG. Works on the local cache offline and flushes when the API is back |
| Auth online | Email + 6-digit PIN verified server-side (PBKDF2 over a peppered PIN, lockout after 5 failures), 12 h JWT + rotating refresh token in the Keychain; an account that signed in online once can sign in offline on that device. PIN-reset codes are returned (`devCode`) only by the local dev Worker, never when deployed. Household sign-up / registration go through the API; `PrincipalCache` decides household vs staff before the stores load |
| Song catalogue | ~165 curated songs for residents born 1930–1960 (UK, Irish, Caribbean, South-Asian, West-African, European), resolved once through the **iTunes Search API** (UK storefront: 30 s previews, artwork, store link) + MusicBrainz original-release years, checked in as `seed/catalogue.resolved.json`. Search is D1-first, then one cached iTunes call (18/min token bucket, 7-day cache); ad-hoc results rank below curated ones. Apple answers the deployed Worker's shared egress with **429**, so after one refusal the Worker reports `upstream: blocked` for 10 min and the iPad searches iTunes itself and posts the results to `/music/tracks/ingest` (mapped and stored for every device). Previews are never re-hosted and every result links back to Apple Music (demo-only use; production uses the licensed provider) |
| Track identity | `ResidentTrackRef` (`bundled:<title>` or `itunes:<id>`) in playlists, metrics and session records; `trackTitles` kept for the insight text. Reggae / ska / calypso map to the **Soul** glyph (nearest of the seven) |
| Glyph queues | Profile playlists (family picks, discovery playlists) lead, then the backend's per-resident queue for that genre, then the bundled stem. Catalogue previews play once, auto-advance, prefetch two ahead and skip dead previews (reported as `previewFailed`); bundled stems still loop |
| Discovery online | The Worker plans seven previews (one per genre, the most familiar for the resident's era + nationality, slot 3 the most informative) with a small staff caption (title · artist · year); faces post to `/discovery/results`, which returns profile playlists (genres with value ≥ 0 plus the favourite) and surface queues (a red genre keeps a 3-track retry queue). Unsaved residents use the stateless cold routes until their first push |
| Taste model | Pure TypeScript in `worker/src/model` (unit-tested): evidence per genre / decade / track with shrinkage `(pos − neg)/(n + 2)` and a 12-week half-life; priors from birth year (peak at 22) and nationality (ported from `ResidentNationality`); greens / reds / sun-likes / cloud-skips / dwell ≥ 20 s / repeated genre taps / **staff picks** as signals, rage taps ignored. The favourite moves only to an evidenced genre that beats the current one on evidence **and** blended affinity by 0.12 |
| Song selection (real time) | Every queue is re-ranked on request from four inputs: **age** (era proximity to birth year + 22, decade evidence), **origin** (nationality genre prior + a lift for songs tagged for their country / region), **liked genres** (discovery greens and reds, sun-likes, skips, genre taps) and **songs like the ones they love** (`worker/src/model/similarity.ts`: same artist = full match, else same glyph genre + Apple sub-genre + same few years + shared home tag, capped at 0.8, weighted by how much they like the song). Liked songs and their artists always stay in the candidate pool whatever the era window, and a liked artist may take 3 of 8 slots instead of 2. **Real time**: a song filed on the profile goes to the backend at once as a `staffPick` signal (`staffPickRemoved` on the ×), the catalogue grows around the artist (`POST /music/artists/expand`, the device searching iTunes when Apple blocks the Worker), and the glyph queues are refreshed after every delivered signals batch — a staff pick or the end of a listening session — so the next tap plays the new ranking. Ad-hoc songs by a curated artist inherit that artist's curated genre and nationality tags (Apple's labels are unreliable for this era) |
| Family / staff picks | "Find a song they love" on the profile opens an iPad-first search sheet (preview, Add, Apple Music link); an added song becomes a suggested like **and** joins the resident's playlist for its genre so the glyph can play it |
| Cover art | Apple's artwork URL is stored with every catalogue track and is **the picture for that song** wherever it plays: it fills the discovery orb behind the three faces and is the full-page backdrop on the resident surface (1200 px variant via `ResidentTrackRef.artworkURL(side:)`, through `SceneImageCache` with the usual Ken Burns + mood colour grade), and it is the thumbnail on the search-sheet rows and the discovery caption (200 px, `Core/TrackArtworkView.swift`). Bundled stems and tracks without art keep the mood's era scene; the floating genre glyphs stay the designer `Genre*` images. The sleeve for the current ± 1 track is prefetched so swipes paint from cache |
| Group playlists (online) | `POST /homes/{id}/group/playlist` ranks the catalogue for the whole room: every candidate scored for every participant with the per-resident model, the group score is the mean plus a bonus when someone in the room loves the song, picks round-robin across the room's genres (the activity's genre when one was chosen) with two per artist, and each carries who it is for and a reason ("A song Irene K. loves"). On the iPad, Start shows a loading ring for about three seconds while the server's picks are merged in front of the roster-compiled list (residents' real songs with previews, else stems) and the sleeves are fetched, then the finished list appears in one piece and plays; previews play once with their sleeve and the room moves on. Offline: the same wait, the roster-compiled list only |
| Staff chrome | Back sits top-left, **Log out top-right** (`FlowTopStaffNavBar`, the group session's own bar) — navigation leads, the account action trails, and the two are no longer a mis-tap apart |
| Data display grammar | Every number, rating, chip and quoted note on staff screens uses `Core/BrandDataDisplay.swift`: card → inset tile (`surfaceInset` + `insetBorder`) → hairline rows; meters on a visible track (`meterTrack`); 1–10 ratings tinted by `BrandRatingTone` (attention < 4.5, caution < 6.5, positive) with the legend printed where the tints appear; status is always icon + word (`BrandStatusChip`), never a colour dot. Section titles are VoiceOver headers; meters read their value; segmented controls become a vertical list at accessibility text sizes (`BrandSegmentedChoice`). Review: `docs/UX_REVIEW_2026-10-28.md` |
| Handover notes | The session summary, the profile's session history, the Care at home last-session card and the dashboards share one layout: date / trend header, "% at ease" chip, the four observations as tone chips or rating rows, the insight on a tile, the suggested next step on an amber-edged tile with a lightbulb, context as a tag line, staff notes quoted |
| Planner Start | Pinned under the list (`safeAreaInset`), whole-home playlist as a text link beneath; zero-count chips are hidden ("Nobody overdue" instead); "fortnight" copy is "14 days" everywhere |
| Planner resident sections | *Would benefit most* (need score > 0) · *Seen recently* · *Better one-to-one today* (`betterServedOneToOne`, collapsed behind "Show N"), A–Z inside each — a score-ordered run read as random once scores tied |
| Group check-in, per resident | The last step adds **Who stood out?**: a chip per participant cycling engaged → unsettled → left early → clear. Optional; saved as `participantNotes` on the group record. The profile line says "they left early", the planner row "left early last time", per-person engagement takes the note over the room score for that session (engaged ≥ 7 · unsettled 3 · left early 2), and two difficult notes in a row become a one-to-one nudge |
| Activity log (held outside the app) | Not every good afternoon is a playlist. **Roster → Group sessions → Log an activity** (`Screens/ActivityLogScreens.swift`, phase `.careActivityLog`) writes up bingo, a class, a visit or a trip afterwards: the nearest of twelve categories (`OtherActivityKind`, or "Something else" with a name), when it started (not in the future) and for how long, who came, and **how each of them was** — enjoyed it · engaged · looked on · unsettled · left early (icon + word; each attendee needs a line, named in the message if missing), plus an optional note. It saves as an ordinary `GroupSessionRecord` with `kind = .otherActivity`, `activityCategory`, no playlist and no room ratings, and `engagementRating` = the mean of the attendees (enjoyed 9 · engaged 7 · looked on 5 · unsettled 3 · left early 2). Because it is a group record it syncs through the existing push (immutable, `group_sessions`), counts as "a group this fortnight" for the planner, sets each person's engagement from their own line, shows as the last activity on the profile ("they enjoyed it"), and adds an **Outside the app** count / attendance / engagement pair to the Home Admin programme card. "Last group session" ratings on the roster skip it (it has none). Two demo activities are seeded. **A mistake is corrected, not edited:** records are immutable once synced, so the screen's "Logged recently" card (the last five for the home) offers **Correct** — the form comes back filled in and saving writes a new record that `supersedes` the old one — and **Remove**, a withdrawal record (`withdrawn`) that supersedes it; `GroupSessionRecord.current(_:)` drops both at every read path and the history keeps everything. "Note the rest as…" fills in everyone not yet noted in one go. **Repeat** on the same card starts a new entry from an earlier one — same activity, length and people, as of now, with nobody yet noted (`ActivityLogDraft(repeating:)`; it is a new record, not a correction). **Care at home** accounts get a one-person version (`ActivityLogDraft.solo`): a "Log an activity" card on the home page opens the same screen with no list to pick from, just the person they look after and how they were; it saves a group record for that one resident in the household's own home, persisted with the household's data (`HouseholdCareStore.Data.activities`, optional so older files load) and shown on the insights page as an **Outside the app** card (`ActivityInsights`: count and how they were over 30 days, enjoyed / engaged / … chips, the last five with their notes). The Worker lets a household push `otherActivity` records about at most one resident (and their withdrawals) and nothing else of the group mode **One resident alone is a one-to-one visit, not a group** (`GroupSessionRecord.isOneToOneActivity`, exactly one participant): the resident profile has a **One-to-one activities** card (`profile.logActivity`) that opens the one-person form for them and returns to the profile; the entry clears "overdue a visit" and counts as a one-to-one in the planner (`daysSinceOneToOne`, `oneToOneCount14d`), shows as its own line on the profile (`oneToOneLine`), and is left out of "no group this fortnight", group engagement and the Home Admin group programme's sessions / reach (it still counts under **Outside the app**). The roster's "Last visit" text and the admin dashboard's "needs attention" days still look at music sessions only. |
| Home lead → roster | The dashboard ends with **Open the roster**; a home lead's Back from the roster returns to the dashboard. Profiles, the planner and group sessions are reachable for every home a lead oversees |
| PIN fields | Only the focused PIN field shows its caret cell; the Care at home forms focus their first field on arrival |
| Resident surface, VoiceOver | Glyphs read "<Genre> playlist" with "Now playing, <song>" as their value; the playing glyph has Next song / Previous song custom actions; the sleeve backdrop is hidden; sun / cloud carry hints; a song change is announced while VoiceOver runs |
| Playing glyph: size, transparency, drag | The playing glyph's disk is **60% of its former size** (`heroDiskScale`) at **60% opacity**, while the equaliser ring keeps the former diameter (`heroEqualizerDiameter`) and stays opaque; its bars reach **twice** as far as discovery's (`OrbRadialBarEqualizerView.HeroTuning.barReach`, canvas sized to match). The resident can **drag the playing glyph** anywhere on the surface (clamped so the ring stays on screen, clear of the staff button and the sun / cloud dock); the side glyphs re-arrange around where it was left; a drag that starts on the glyph never counts as a song swipe; the offset clears when the playlist stops or another genre takes over |
| Free-tier budget | Every route ≤ 1 D1 batch + a few reads; sync pulls page by seq; one signals row per session (not per event); nightly Cron enriches ≤ 15 ad-hoc tracks. Portraits live in D1 BLOBs (R2 needs a card on file). Only demo data may live on the POC backend (backend ADR 0001) |
| Organisation onboarding (Oct 2026) | A care organisation sets itself up from the sign-in screen when a backend is configured: **Request a workspace** (organisation, requester, work email, role, homes band, CQC provider ID, consent) → six-digit verification code → approval (operator script `npm run operator`, or at once with `AUTO_APPROVE=1`) → **ORG-** activation code → the org admin's six-step set-up (`.orgSetup`: organisation + verified domains + inherited settings · homes with wings and an optional home-lead invite · team invites with **INV-** codes, bulk paste, temporary-cover end dates, suspend / restore / remove / admin PIN reset · residents from a CSV (parsed on device, pushed through the normal sync) or the sample spreadsheet · shared-iPad guidance and "this iPad belongs to…" registration · a live checklist, first-week nudges and the append-only audit trail). Staff join on the same **I have an invite or activation code** screen (email must match, PIN chosen there, versioned consent). Codes are hashed at rest, single use, 7 days; wrong email and wrong code read the same; a domain another organisation verified is refused by name. Plan: `docs/ONBOARDING_PLAN.md`; Worker routes `onboarding.ts` / `org.ts`, migration `0004_onboarding.sql`; iOS `Core/Onboarding/`, `Screens/OnboardingScreens.swift` |
| Set-up wizard navigation (28 Oct 2026) | **One primary action, named for where it goes.** A single pinned bar holds a quiet text button for the previous step ("‹ Homes") and the primary "Next: Team"; the top-left control leaves the wizard and says where ("‹ Dashboard" / "‹ Home list") so no two buttons share a label. Every way out of a step (Next, previous, a stepper chip, the top-left exit, Finish) goes through one guard: unsent work on the step (an edited profile, a half-filled home or invite, a checked-but-unimported spreadsheet, an iPad label) asks **Save and continue / Discard / Keep editing** instead of being dropped. Feedback sits in the bar next to the buttons (errors stay until dismissed or the field is edited; notices clear after 6 s; both are announced to VoiceOver). The stepper ticks the steps that are done, opens on the first step still to do from the dashboard card, scrolls the current step into view, and each step starts at the top of its page. In-card actions (Add home, Send invite, Register, Import) are secondary; the bar owns the one primary |
| Set-up wizard is paged (28 Oct 2026) | The set-up is **six sections of short pages** (19 pages: organisation 4 — details, address, domains, defaults; homes; team; residents; iPads 2 — guidance, register; ready 2 — checklist, audit) rather than six long scrolls, so no field sits below the fold waiting to be missed. Pages are a straight line (previous / "Next: <page>"); **side journeys** (add a home: details → address → wings → lead; invite one person: who → access; invite several; check the spreadsheet) start from their overview, end with a commit button ("Add home", "Send invite", "Send all", "Import n residents") and return to the same overview with the confirmation. The header says where you are ("Team · 1 of 2"); a section of one page shows only its name. Resume opens on the first page still to do (an organisation without an address resumes on the address page). Code: `SetupSection` / `SetupPage` / `SetupDetour` in `Core/Onboarding/OnboardingStore.swift`, navigation in `OnboardingWizard.swift`, pages in `Screens/OrgSetupScreens.swift` |
| Input validation (28 Oct 2026) | **One set of rules in two places**: `Core/Onboarding/InputRules.swift` (app) and `../NoteStalgia-Backend/worker/src/lib/validate.ts` (server) share limits and wording, and both have tests (`Tests/InputRulesTests.swift`, `test/validate.test.ts`). Names are letters, spaces, hyphens, apostrophes and full stops (Unicode: Zoë, Łukasz, O’Brien), two letters at least; organisation / home / wing / iPad names add digits and `& ’ . , ( ) / + : · -`; addresses and towns have their own sets; a postcode is a UK postcode, normalised to `SK1 1AA`; phone numbers have 10–15 digits; beds are a whole number 1–2000; CQC ids are `1-` and 9–10 digits; emails are real addresses (no spaces, a dotted domain); domains are bare (`https://www.` and paths are stripped); notes carry no angle brackets or hidden characters. **Required** (set-up): organisation name and, on the address page, address line, town and postcode; home name, the home's own address (one tap reuses the head office's) and at least one wing; invite email, role and homes; the iPad's label; for activation codes the person's name when the invite doesn't carry one. Optional but checked when filled: trading name, CQC ids, beds, phones, notes, invitee and home-lead names. While typing, fields drop what can never be right (digits only for beds and the domain code, no spaces in emails, upper-case postcodes, no `<` `>` or control characters) and cap length; everything else is **checked, with a message under the field** (icon + words, red outline, cleared when the field is edited) and a banner that says the message, or counts them when several. Errors on another page of a journey take the person there; leaving a wizard page with a mistake on it (organisation details and address, home details, address and wings, the invite's email) is refused on that page, with the message under the field. The server refuses the same input with the same wording, so a hand-made request can't store what the app would refuse. Not covered: weak PINs (`111111`, `123456`) are still accepted |
| Admin and data screens are phone-first | Admin, set-up and data dashboards are designed for a phone first (tight vertical rhythm on a compact width, one column, 44 pt targets, the pinned bar steps aside while the keyboard is up and "Done" rides on the keyboard) and then open up on the iPad; the resident-facing and staff-session screens stay iPad-first. Chip rows wrap with even gaps (`InsightChipFlow`), dividers sit between rows only so a card's content has equal space top and bottom, and stand-alone callouts over the orb are full cards (`OnboardingCallout`), never bare inset tiles |
| Domains, export, plans | A further email domain is proved either by a six-digit code to `postmaster@` / `admin@` or by a **DNS TXT record** (`_notestalgia.<domain>`, checked over DNS-over-HTTPS; the record stays as proof). Every home can be **exported** from the set-up (residents CSV, sessions CSV, everything as JSON) through the share sheet; each export is audited. Self-onboarded organisations start on a 30-day **trial**; an ended trial blocks sign-in and token refresh until the operator moves the plan on (`npm run operator -- plan`). Seats per home are a soft limit: invites still go out, with a warning. CQC provider / location ids are checked against the register when the Worker has a `CQC_API_KEY`, otherwise stored as typed. The org admin's dashboard carries a **set-up card** (homes · staff · residents · iPads) that collapses to "Set-up complete" once everything is in place |
| Demo codes | The deployed POC Worker runs with `EXPOSE_CODES=1` + `AUTO_APPROVE=1`, so verification, activation and invite codes come back in the response and show on screen ("Demo code: …", code tiles) — for the walkthrough only. Production removes both and sends mail through Resend (`RESEND_API_KEY` + `EMAIL_FROM`); the operator approves with `scripts/org-requests.ts` |

### Staff UI (iPhone + iPad)

| Decision | Choice |
|---|---|
| Top chrome | Back + Log out flush under status bar via `safeAreaInset` — **do not** double-apply `safeTop` in `OrbNavigationStyle` |
| Scroll dissolve | Vertical edge fade on staff scroll screens; **horizontal** fade on wing chips + admin trend strip (row hugs content height — no measured fixed height) |
| Text-field placeholders | Always `BrandTheme.fieldPrompt(_:)` — system placeholder colour is unreadable on the dark fields |
| Suggested liked songs | Supervisor-seeded titles boost playlist scoring (+ dwell / likes) |
| Welcome gates | Supervisor / admin welcome screens wait for **real readiness** (roster seeded off-main, portraits decoded, presentation caches warm — `RosterWarmUp`) with a 2.2 s / 2.8 s minimum dwell and a 6 s cap; past 2.6 s a "Preparing the roster…" hint fades in. Roster shows "Loading residents…" only if the cap was hit |
| Loading fallbacks | Nothing spins forever: nature video → opaque calm gradient + "Video unavailable — resting with the music" after 8 s (or immediately on item failure); discovery media → mood gradient + genre artwork after 6 s; photo picker shows "Opening photo…" and a failure line, decoding off-main via ImageIO |
| Honest back buttons | Discarding a new resident asks first (Back reads **Discard**); back controls that save a record read **Skip** (ratings / group check-in step 1, "How that felt") |
| Copy terms | One term per concept: **Log out** · **% at ease** · **Session summary** · **carer observations** · **Day programme** · "Save observation" |
| Hit targets | Top chrome, search clear, pin stars and "Forgot PIN?" expose ≥44 pt hit areas with unchanged visuals (`expandedHitArea`); chips and mood orbs announce *Selected*; Forgot PIN / sign-in error use Dynamic Type |
| Horizontal rows | `HorizontalScrollEdgeFade` (wing filter pills, admin trend strip) **centres its content when it fits** the column and only scrolls from the leading edge when it overflows (phone) |
| Accessibility identifiers | Every interactive control has a stable `accessibilityIdentifier` (table in `tools/demo/README.md`) so scripted walkthroughs and UI tests never tap by coordinate |
| Mock residents | Every mock resident is an individual (`Core/ResidentProfileSeeds.swift`): own likes/dislikes, light/scent/touch notes, reminiscence themes, age, nationality, favourite + secondary genre with bundled-audio playlists and seeded liked songs. Named trio (Elena, James, Sam) unchanged |
| Press feedback | Every staff button (`SoftPressButtonStyle`, `ChimingPlainButtonStyle`) gives a soft press + **glowing halo pulse** (cyan; pink on primary buttons) and the button **chime**; toggles, segmented pickers, steppers and menus chime via `chimeOnChange`. Pulse and chime are skipped under Reduce Motion |
| Screen-tap ripple | A short tap anywhere (staff **and** resident surface) sends a small wave burst off the finger (`TouchRipple.swift`) — the same wavefront the music equaliser sends off the orb, smaller: the orb's palette round the ring (cyan, lilac, pink, peach), a white-hot crest, a soft shoulder and the light it drags behind it. It is the equaliser's shader (`tapFragment` in `OrbFlow.msl`) drawn once into a sprite (`OrbTapSprite`), then scaled, turned and faded by keyframes (blooms in over 70 ms, fades over the rest), so a tap costs no per-frame GPU work; until the shader is ready (the first moments after launch) a SwiftUI approximation is used. Observed by a window-level recogniser that never claims, cancels or delays touches; drags/scrolls and long presses don't ripple; off under Reduce Motion |
| Post-session summary | Supervisor sees **Session summary**: at-a-glance (trend vs usual, time with music, genres, liked · skipped, context chips) → carer ratings as 10-segment bars (≤4 in soft salmon) + note → what they responded to (genre artwork chips, sun / cloud / longest listening) → one highlighted next step → **one** write-up at a time (Handover · Family · Care plan) with a single Copy button. Copied texts are unchanged; handover shows as labelled sections with the narrative collapsed |

### Group activities (intelligent resident selection)

| Decision | Choice |
|---|---|
| Planner before the session | "Group activities" on the roster opens `GroupActivityPlannerView` (`careGroupPlanner`) instead of starting straight away. Staff pick residents; the whole-home playlist is one tap away for anyone who wants the old behaviour |
| Recommendations are heuristics, on device | `GroupActivityPlanner` (pure functions over roster + one-to-one history + group history): per-resident genre affinity (favourite ×3, playlists on file ×1.5, liked songs ×1, calm-surface plays ×0.5/play, sun-likes ×1), a *need* score (+2 overdue a visit ≥7 days, +1.5 no group this fortnight, +0.5 declining/unsettled, +0.5 groups visibly help, −2 prefers one-to-one, −0.5 small groups / regular), suggested activities per genre with ≥3 matching residents (title, reason, recommended list sorted by need) plus a "Shared favourites" mixed set, staff suggestions (nobody overlooked · organise the strongest activity · pairings who share a genre and haven't shared a session · better served one-to-one), and an engagement overview (regulars, needs encouragement, activities that land best by average engagement). Production ports the same rules as the Phase-A recommender (`docs/IMPLEMENTATION_PLAN.md` §10) |
| Staff keep control | Every suggestion is a tap to apply (activity → replaces the selection; "Add" → adds) and a tap to undo; residents marked **prefers one-to-one** are never auto-recommended and get a one-to-one nudge instead; **small groups** and **keep it gentle** are shown as flags, not enforced |
| Group comfort on the profile | `CarePatientProfile.groupComfort` (`GroupComfort`: enjoys groups / small groups / prefers one-to-one; optional so stored households still decode). Seeded for the mock roster by first name (`GroupActivityPlanner.seededGroupComfort`) and **staff-editable** on the resident profile's "Group activities" card ("In company" segmented picker: Not set / Enjoys groups / Small groups / One-to-one → `setResidentGroupComfort`, chime on change). The card is hidden for household accounts, which have no roster or group mode |
| Participation is recorded | `GroupSessionRecord` now carries `participantIds`, `activityTitle` and `theme`; the compiled playlist comes from the chosen residents only; the session header names the activity. A fortnight of demo group sessions (`GroupActivityMockData`) is seeded for Maple Lodge so the overview has history. Group records are one store across homes, so `GroupActivityPlanner.build` keeps only records that involved the residents it is given (a record with no participants on file counts as a legacy whole-home session) — Riverside House never sees Maple Lodge's history |
| Participation shows on the profile | The "Group activities" card (between carer observations and playlists) reads `GroupActivityReadModels.participation`: count in the last 14 days, last activity title, when, and its engagement rating ("3 group activities in the last 14 days · last: Jazz lounge, 2 days ago · engagement 8/10") |
| Home Admin sees the programme | `CareHomeAdminDashboardView` gains a **Group programme** card after the wing breakdown (`GroupActivityReadModels.programme`, cached like the dashboard in `CareRosterUIStore.groupProgrammeCache`): sessions / residents reached of active / average engagement / average morale over the same 14-day window, the activity that lands best, and how many residents who would welcome a group have had none (planner's `needEncouragementIds`, first three named). Whole-home playlists count as reaching every resident |

### Care at home (household accounts)

| Decision | Choice |
|---|---|
| Accounts | Same email + 6-digit PIN form as staff. A household email is matched **before** the organisation-domain rule (`SupervisorAuth`), so any personal address works; organisation addresses are refused at sign-up and pointed back to the staff sign-in. Accounts live in `UserDefaults` (`HouseholdCareStore`); PIN reset uses the same demo code and updates the stored account |
| Tenancy | Every household is a one-wing `CareHome` ("Care at home" / "At home") with its own `homeId`, so the roster engine, session records, portraits, dashboards and demo seeds work unchanged. `CareAccountDirectory` merges mock supervisors/homes with household accounts; `SupervisorRole.household` routes the flow |
| Registration | One resident per account: name, age (55–105), nationality, optional photo. Created as a real (non-provisional) resident with a starter playlist for the nationality's first genre; discovery is offered immediately and again from the home screen. No roster, no group mode |
| Home screen | Portrait + name, last session line, **Open calm surface**, then cards: Insights & trends · Profile & preferences (the full resident profile) · Listening discovery. Back from the profile, the session summary and the calm surface return here (`staffHubPhase()`) |
| Insights & trends | `CareHomeAnalytics.buildResidentInsights`: trend charts (sessions / avg at ease / observed wellbeing over 14 days — same `DashboardTrendGraphsStrip` as the home dashboard), KPIs (sessions, time with music, avg at ease, observed wellbeing), carer-observation averages as bars, what they respond to (genre plays from session summaries, liked / moved-on-from lines), latest suggested next step, recent sessions. Empty state until the first session |
| Persistence | Household residents, their history and photos are written to Application Support (`household-care.json`, `portrait-<id>.jpg`) on every change (debounced) and merged into the seed at launch; `CarePatientProfile` / `CareSessionRecord` are `Codable`. The demo household (Claire → Harold) is static and never persisted |

### Performance

| Decision | Choice |
|---|---|
| Ambient sparkles | ~450 particles; cull off-screen; tiered glow; pause on scroll / keyboard / reduce-motion |
| Orb / glyphs | Budgeted FPS (`OrbRenderBudget`); pause expensive loops while scrolling |
| Orb renderer (Metal) | `App/Resources/Shaders/OrbFlow.msl` draws the whole orb in one GPU pass: domain-warped 3-D marbling on a sphere (continuous in time, so no frame stepping), a vortex twist, silk threads, rim light, an energy corona and a heartbeat ripple. It is **compiled at runtime** (`MTLDevice.makeLibrary(source:)`, background queue, ~2 s on the simulator, fades the orb in when ready) so it needs **no Metal toolchain** at build time. `OrbMetalCanvas` is an `MTKView` on its own display link: the breathing (the same 6 s `OrbHeartbeat`, shell scale 0.965–1.055, glow 0.56–1.0, music blend) is computed in its draw loop, so the persistent orb has **no SwiftUI timeline** — the main thread only encodes one draw call. It pauses with the keyboard, a scrolling list and the background, as the CPU orb did. Orbs under 160 pt are rendered once into a cached image (`OrbSnapshotCache`) with a very slow turn, instead of a GPU view per roster row. If Metal or the compile is unavailable the previous CPU orb is used (`-NoteStalgiaOrbRenderer classic` forces it for A/B). Develop the look without rebuilding: `tools/orb/orbshot.swift` renders the shader to PNG on the Mac; `-NoteStalgiaOrbShaderPath <file>` loads a shader from disk in the simulator. `OrbShaderTests` compiles the shader on the test host |
| Orb tone per page | `OrbShellConfiguration.brightness` is a **luminance ceiling** on the orb's interior: 1 on pages that are the orb (calm surface, discovery, immersive), 0.62 behind text-on-orb pages (sign-in, welcome, pickers), 0.52 behind pages of cards and forms. Under a ceiling the shadows keep (and raise) their colour and only the luminous parts settle, so the orb stays a vivid jewel tone but light text over a 50 % card keeps ≥ 4.5:1 (relative luminance behind the card ≤ ~0.23). Eased with the 0.62 s page transition |
| Scene stills | `SceneImageCache` (memory + disk) + prefetch |
| Scroll pause | Refcounted `AmbientInteractionPause` |
| Orb glow sprites | Outer halo + inner glow are scale-invariant blurred gradients → rendered once (`OrbGlowSprites`) and drawn as images; exterior wisps flattened with `drawingGroup`; empty ripple-ring Canvas removed. Pixel diff vs live: max 8/255 |
| Full-page cover pause | While resident playlist media is fully expanded **and** decoded, sparkles + orb shell pause (`AmbientInteractionPause.beginFullPageCover`) — invisible behind the media; resumes as it collapses. Orb visuals themselves are never simplified for performance. The staff immersive screen (opaque video / poster / fallback) holds the same cover |
| Icon orbs | Self-driven small orbs (roster cards, mood orbs, picker labels, nav buttons; < 96 pt) run at **20 fps** (`OrbRenderBudget.iconFramesPerSecond`; sub-pixel drift) and **freeze** while the keyboard is up, a staff list scrolls or the app is backgrounded (`flowAmbientPaused` environment) |
| Motion as transforms | Resident glyph buttons (`ResidentGlyphButton`, `Equatable`) and mood orbs are built once; per-tick drift is applied as position/rotation/scale/offset transforms in the original order. Discovery orb no longer re-renders at audio-bus rate |
| Equalizer redraws | Live-only radial bars redraw when `MusicReactiveBus` publishes (≤48/s playing, 0 idle) rather than 60×/s; bar trig precomputed |
| Orb clock and interaction | `OrbClock` (`Core/OrbMetal.swift`) is the animation time of every GPU orb: it follows the wall clock only while an orb is drawing and never advances more than 50 ms per read, so an orb that pauses carries on from its last frame instead of snapping to wherever the wall clock got to (a 2 s pause is a third of the 6 s breath — it used to show as a jump in the swirl and the size). The GPU orb also **no longer pauses for scrolling or the keyboard**: that was inherited from the CPU orb, whose redraw competed with scrolling on the main thread; the GPU orb's encode is a fraction of a millisecond. `-NoteStalgiaOrbPauseOnInteraction YES` restores the pause for comparison; backgrounding still stops it |
| Orb edge | A **soft white glow at the orb's edge**, not a ring: the body brightens towards white over its last fifth (`edgeIn`) and the same glow continues just outside (`whiteEdge`), falling away within a few percent of the radius. Its strength follows the page's brightness tier (`edgeK`: 0.35 on text pages, 1 on resident and immersive pages) so it never brightens what light text sits over. The corona is cut away once, not twice, across the anti-aliased pixels — twice left a dark hairline at the edge |
| Sounds and haptics | One helper, `CalmExperienceFeedback`: **a press or choice** = quiet chime + light selection tick (every `ChimingPlainButtonStyle` / `SoftPressButtonStyle` button, chip, toggle and row); **a save or sign-in** = soft impact + rising success chime; **an error or a form that cannot be saved** = warning haptic + the lower "attention" chime (a minor third) + the message read out for VoiceOver; **session milestones** (discovery pick, like / skip, playlist start, settle) = soft impact. `BrandMessageTile` carries the cue itself (error → attention, success → saved), as does the set-up banner and the activity log's failed save. Two per-device switches, **Chimes** and **Haptics**, live on the roster and the Care at home page (`FeedbackPreferencesCard`, `FeedbackPreferences`); they are no longer tied to Reduce Motion, and music is never affected. iPads have no haptic motor, so on them the sounds carry the feedback |
| Cheap effects | Tap ripple pre-rendered as a sprite (scale/opacity only); `CalmCircularLoader` capped at 60 fps with rotation-invariant shadows; chime engine pauses after 20 s idle; `DemoAudioLog` builds nothing when disabled |
| Orb frame rate | The shell's timeline follows the display (`shellFramesPerSecond = 120`, so 60 on most panels and 120 on ProMotion; `CADisableMinimumFrameDurationOnPhone` set). The nebula field's two noise samples per cell are computed **one frame ahead on a background queue** (`NebulaDensityPrecompute`, same formula → identical values; synchronous fallback when a buffer isn't ready) so the main thread only fills splats (~1 ms → ~0.6–0.9 ms per frame). Every `.shadow` that sits in the breathing scene — orb-overlay text (4 shadows per label), primary-button labels, `BrandCard`, the shell's three radiance shadows — is **flattened into one texture** (`flattenedShadows`, padded `drawingGroup`): pixel-identical to the Core Animation shadows (frozen-orb diff: 0 in the orb, text and card), but one composited layer per frame instead of a blur pass each. On the iOS Simulator those passes are synchronous host-GPU round-trips and were the real cap on the breathing (render server 76% in `ShadowNode`); on device they are cheap either way |
| Launch warm-up | A blocked main thread is only invisible while nothing animates, so `LaunchWarmUp` is split: the main-thread-only steps (keyboard subsystem pre-load — ~1.7 s on the simulator because of a synchronous pasteboard round-trip — and the orb glow sprites) run in the root view's `onAppear`, **before the first frame**, under a brand-coloured static launch screen (`UILaunchScreen.UIColorName = LaunchBackground`, no white flash); the audio session, chime synthesis and `AVAudioEngine` creation/start run on a background queue; the remaining sprites/haptics are staged one per run-loop turn. The title orb never loses a frame; orb visuals are unchanged |

### Distribution / sharing

| Decision | Choice |
|---|---|
| Free share | GitHub clone + Xcode Simulator, or screen recording |
| Demo recording | `tools/demo/walkthrough.sh <scenario>` records a scripted walkthrough (`DemoUITests`) on the booted simulator with real audio via ffmpeg + BlackHole; demo-only launch arguments (`DemoLaunchOptions`: auto sign-in, skip title, jump to scene, freeze glyph drift) and `accessibilityIdentifier`s on the main controls make it deterministic. The narrated walkthrough (v6, nine flows incl. Care at home) is four chronological story takes whose scripted steps write timestamped markers; `pipeline/build_story.py` turns the markers into chapter cuts, captions, a neural voice-over (`pipeline/narration.py`, edge-tts with a macOS `say` fallback) and burned-in subtitles plus an `.srt` sidecar. See `tools/demo/README.md` |
| Installable share (TestFlight / App Store) | Requires **Apple Developer Program ($99/yr)** — not free |
| Production backend | Not in this repo yet — see implementation plan |

### Explicit non-goals (POC)

- Real licensed music API / streaming backend  
- Persistent server sync / multi-device session continuity  
- Production GDPR consent flows (mocked only)  
- Shipping Face ID or room IoT in v1  

---

## Docs map

| Doc | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | How coding agents should work in this repo |
| [`docs/HANDOFF_PLAN.md`](docs/HANDOFF_PLAN.md) | Prioritised pickup plan for the next agent (Claude) |
| [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) | Production architecture (AWS, Mongo, EKS, clients, GDPR) |
| [`docs/NoteStalgia-PitchDeck.md`](docs/NoteStalgia-PitchDeck.md) | Investor / stakeholder narrative |
| `../NoteStalgia-Backend/contracts/openapi.yaml` | v1 resource contract shared with Android and the production backend |
| `../NoteStalgia-Backend/README.md` | Run the POC API locally (`wrangler dev`) or deploy it to Cloudflare |

---

## Related repos

- **iOS (this):** feature-complete care path POC  
- **Android:** `../NoteStalgia-Android` — core-path parity; group sessions deferred; keep catalogs in sync when changing tracks/genres/icons; **no API client, sync, search or online discovery yet** (see `docs/HANDOFF_PLAN.md`)
- **Backend (POC):** `../NoteStalgia-Backend` — Cloudflare Worker + D1 implementing the v1 contract; catalogue seed + taste model; `npm run dev` for the simulator, `npm run deploy` for the user's Cloudflare account  
