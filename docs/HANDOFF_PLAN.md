# Handoff plan — Claude / next agent pickup

**Status:** iOS care-path POC is feature-rich and runnable. Uncommitted local work (as of handoff)
includes designer genre icons + 1:1 track↔genre remapping — **commit that before starting new
features** if still dirty.

**Sibling:** `../NoteStalgia-Android` — keep catalogs in sync.

**Backend (Oct 2026):** `../NoteStalgia-Backend` — Cloudflare Worker + D1 (free tier) implementing the v1
contract; the app uses it when launched with `-NoteStalgiaAPIBaseURL`, and behaves exactly as before without it.

---

## 0. First 15 minutes (setup)

```bash
cd NoteStalgia-iOS
git status
xcodegen generate
xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Optional — run against the POC backend (same data on every iPad/iPhone that signs in):

```bash
cd ../NoteStalgia-Backend/worker && npm install && cp -n .dev.vars.example .dev.vars
npm run migrate:local && npm run dev          # http://localhost:8787
npm run seed:local                            # in a second shell: demo homes, accounts, catalogue
xcrun simctl launch booted com.notestalgia.ios -NoteStalgiaAPIBaseURL http://localhost:8787
```

Smoke-test in Simulator:

1. Sign in as `alex@sunrise-care.co.uk` / `123456` → home picker → admin or roster  
2. Open a resident → start session → tap each genre glyph → confirm **distinct** tracks  
3. Sun = keep/like; cloud = skip off queue  
4. Scroll roster — top fade under back/logout; wing chips horizontal fade on phone  

Read `README.md` decision catalogue + `AGENTS.md` before coding.

---

## 1. Immediate backlog (POC polish)

Ordered by impact / risk.

### P0 — Land WIP if uncommitted

- [ ] Stage & commit genre `Genre*` imagesets + catalog remaps (`ResidentPlaylistVisuals`,
      `MusicVisualMood`, `DiscoveryEraMedia`, `CareStaffModels`, Android `PlaybackCatalog` /
      drawables) if not already on `main`.
- [ ] Verify Android still builds after gospel raw `pine_smoke_drift_1`.

### P0 — Gospel audio honesty

- [ ] Replace interim **Pine Smoke Drift (1)** under Gospel with a real gospel/choir stem when
      available; keep icon `GenreGospel`; update iOS Music folder + Android `res/raw` + catalogs
      together.
- [ ] Until then, do **not** silently reassign other genres’ primaries to “fix” gospel.

### P1 — Catalog / discovery consistency

- [x] Audit `DiscoveryFlowPOC.snippetAudioStreamURLs` vs `snippetMoods` vs
      `ResidentPlaybackTrackCatalog` — iOS: added missing **Country** (`Pine Smoke Drift` →
      `.countryAmericana`) as snippet 6, so discovery now covers all 7 genres.
- [ ] **Android TODO:** `calibrationMoods` in `DiscoveryScreens.kt` is 5 moods (Classical, Jazz,
      Pop, Country, Gospel — no Rock / Soul) in a different order. Mirror the iOS 7-snippet order.
- [ ] Staff “suggested liked songs” menus should only offer `allUniqueTitles` from the catalog
      (already filtered in places — verify after remap).

### Done — Set-up wizard UX review (28 Oct 2026)

Reviewed on the iPad and iPhone simulators against the deployed Worker. Found and fixed: two buttons both labelled
"Back" (top-left left the wizard, bottom-left went to the previous step), a tick on the *current* step, "Continue
set-up" always restarting at step 1, errors rendered at the top of a long page where the button that raised them
was off screen, errors that stayed after the field was fixed, stepper clipped at the iPad's edge, stand-alone inset
tiles that washed out over the orb, dividers after the last row (unequal space inside cards), fixed-width chip grids
with ragged gaps, the keyboard covering the bar and the focused field on a phone, and work silently dropped when
moving between steps. Now: one guarded navigation path (`Core/Onboarding/OnboardingWizard.swift`), a single pinned
bar (previous as text, "Next: <step>" as the primary, banner above it), resume at the first step still to do,
`OnboardingCallout`, `InsightChipFlow` for chip rows, hairlines between rows only, a keyboard-aware bar with
"Done" in the keyboard accessory row, and the admin / data screens designed phone-first (rule in `AGENTS.md`).
Not re-reviewed yet under the new phone-first rule: the roster, profile history, Care at home insights and the
group planner; the home admin dashboard itself looked sound on a phone but was not restructured.
Known limit: the final keyboard clearance under the last field on a phone was not re-verified by screenshot (the
simulator kept flipping to hardware-keyboard mode); the earlier software-keyboard capture showed the bar stepping
aside correctly.

### Done — Paged set-up wizard and input validation (28 Oct 2026)

Two requests from the admin review. **Less scrolling, more pages:** the six long steps became six sections of
19 short pages with four side journeys (add a home, invite one, invite several, check the spreadsheet); see the
README rows "Set-up wizard is paged" and "Set-up wizard navigation". Phone-first fixes that came with it: captions
can no longer truncate (`fixedSize`), a field and its button stack on a phone and sit side by side on the iPad
(`OnboardingFieldWithAction`), buttons beside fields match the field's height, the Organisation set-up button on
the home picker lines up with the home rows, the spreadsheet template is a sentence instead of a raw CSV, the
review rows stack name over details, toggle rows no longer reserve 44 pt of empty space (the hit area is
expanded instead). **Input validation:** one rule set in the app (`Core/Onboarding/InputRules.swift`, with
`OnboardingValidation.swift` building each form's problems and `OnboardingField` showing them) and the Worker
(`src/lib/validate.ts`), both tested; required fields, character filters, length caps, inline messages. Worker
deployed; 107 Worker tests and 16 Swift tests (`NoteStalgiaTests`, a new unit-test target) pass. Walkthrough Part
I (`testStoryPartI_Onboarding`) and its narration were rewritten for the paged flow and the new required fields
(address page, iPad label).
A home now has its own address (page 2 of the four-page add-a-home journey, required, with a "Use the head-office
address" shortcut; shown on the home's card). A partly failed bulk invite keeps only the faulty lines in the box.
The v7 walkthrough was re-recorded for all of this (`NoteStalgia-Walkthrough-v7.mp4`, ten flows, about 32 minutes,
narration in `tools/demo/pipeline/narration_v7.py`, paced by the voice). A second film of every onboarding and admin
screen on the iPhone is scripted but **not recorded yet** (`build_v7_mobile.py`, six `testMobile*` takes, narration in
`narration_mobile.py`; the takes were checked individually at fast pace). `tools/demo/record-v7.sh ipad|mobile|all`
redoes either; see the demo README for what breaks a take (never touch the simulator during one; disk space; run
headless — with Simulator.app open the iPad shows a number-pad popover, which is still visible in the sign-in and
onboarding PIN entry of the current iPad film).
UX/UI pass (30 Oct, round 10, section H of the same review: contrast fixes on the pink primary action and Log out, Reduce Motion, 12 pt minimum, accessibility-size tile stacking, search empty state, cards at 50 % opacity with Reduce Transparency fallback — the v7 films are stale again and need re-recording). UI consistency pass (28 Oct, round 9, `docs/UX_REVIEW_2026-10-28.md` section G): the roster, the signed-in start
screen, session prep, entry mode and the profile's history heading now use the card grammar (icon headers, status chips,
Log out only in the top bar). The v7 films must be re-recorded to show it — see the demo README.
Open: weak PINs are accepted (`111111`, `123456`); a home's address can't be edited after creation (the Worker's
`PUT /homes/:id` takes it, the app has no edit screen); validation messages are English only; Android has none of
this (see the parity checklist in `AGENTS.md`).

### Done — Organisation & home onboarding (28 Oct 2026; plan slice A + most of B)

`docs/ONBOARDING_PLAN.md` implemented on the Worker and the iPad (backend only — the links are hidden without
`-NoteStalgiaAPIBaseURL`):

- **Worker** (`../NoteStalgia-Backend/worker`): migration `0004_onboarding.sql` (tenant / home / account status
  and profile columns; `org_requests`, `invites`, `domain_claims`, `consents`, `audit_log`, `devices`);
  `src/routes/onboarding.ts` (public `POST /auth/org-request`, `/org-request/verify`, `/org-activate`,
  `GET /auth/invite/preview`, `POST /auth/invite/accept`; operator `/operator/org-requests` list / approve /
  decline, `/operator/tenants/:id/suspend|restore` behind the seed-token guard); `src/routes/org.ts`
  (`/orgs/me` GET/PUT, domains by email code, `/homes` GET/POST/PUT/archive, `/invites` + bulk / resend / revoke,
  `/orgs/me/accounts`, `/accounts/:id` PUT / suspend / restore / remove / pin-reset, `/devices`,
  `/orgs/me/audit`); `lib/codes.ts` (ORG-/INV- human codes, sha256 at rest), `lib/email.ts` (Resend or no-op;
  `exposeCodes`), `lib/ratelimit.ts`, `lib/audit.ts`, `lib/onboarding.ts`; sign-in refuses suspended / removed
  accounts, lapsed temporary cover and suspended tenants; `scripts/org-requests.ts` (`npm run operator`);
  `POST /admin/seed { reset: { onboardingDemo: true } }` removes self-onboarded organisations (the demo reset
  does this); contract paths + schemas in `contracts/openapi.yaml`; `test/onboarding.test.ts` (17 tests).
- **iOS**: `Core/Onboarding/` (`OnboardingModels` DTOs, `OnboardingClient`, `OnboardingStore` — not forwarded by
  the coordinator, `OnboardingFlow` coordinator extension, `ResidentCSVImport`), `Screens/OnboardingScreens.swift`
  (`OrgRequestView`, `OrgCodeView`, `OrgSetupView` with six sections of short pages and a pinned previous / Next bar), phases
  `.orgRequest` / `.orgCode` / `.orgSetup`, two sign-in links, an org admin with no homes lands in set-up,
  "Organisation set-up" on the home picker and the admin dashboard, `AuthSession.activateOrganisation` /
  `acceptInvite` / `refreshCurrentSession` (new homes reach the claims through a token refresh, then
  `sync.activate` watches them), `APIClient.delete`.
- **Deployed**: migration applied and Worker deployed with `EXPOSE_CODES=1` + `AUTO_APPROVE=1` (demo only).
  Verified on the iPad simulator against it: request → code → approved → activate → set-up (organisation, home,
  invite with code tile, this iPad, ready, audit) → dashboard.
- **Walkthrough**: `testStoryPartI_Onboarding` (`i_onboarding`, flow 10 "A new organisation", narration
  `v7_onb_*`) added to the v7 pipeline; `reset-backend.sh` removes the demo organisation first.

Closed on 28 Oct 2026 (second pass): DNS-TXT domain verification (`lib/dns.ts`, DoH lookup, record shown in the
set-up and in `/orgs/me` pending domains), per-home export (`GET /orgs/me/export`, JSON / residents CSV / sessions
CSV, share sheet on the iPad, audited), the real-mail deployment path (`npm run deploy -- --live` stores
`RESEND_API_KEY`, optional `CQC_API_KEY`, deploys with `EXPOSE_CODES` / `AUTO_APPROVE` off and `EMAIL_FROM` set),
CQC register checks when a key exists (`lib/cqc.ts`), seat warnings on invites, trial expiry at sign-in and
refresh plus `POST /operator/tenants/:id/plan` (`npm run operator -- plan`), refresh refused for suspended /
removed / lapsed accounts and blocked tenants, 403 messages shown on the sign-in screen, and the dashboard
set-up card (`OrgSetupDashboardCard`) that collapses to "Set-up complete". 86 Worker tests.

Deliberately left for production (not POC work): session **retention** enforcement (deleting server-side needs
session tombstones in the sync contract — today only residents carry `deleted_at`), DSAR export across tenants,
SSO / SCIM, MDM integration, the operator web console. **Android**: nothing — invite acceptance (`INV-` code →
PIN → roster) is the first piece when Android gets an API client; see the parity checklist in `AGENTS.md`.
**Phase fade guard** (found by the Part I recording, which stalled four times at "log out → I have an invite
or activation code": the new screen's tree was built and reported visible, yet nothing was drawn or exposed to
accessibility). Three layers of protection now: the phase layer in `FlowRootView` uses `.transition(.identity)`
(the old `.asymmetric(insertion: .opacity, …)` insertion could be caught mid-flight by the fade's own animation
under recording load), `ScreenFadeIn` re-asserts its reveal 0.7 s after appearing if the state write was dropped,
and `transitionToPhase` always restores `phaseContentVisible` once it has swapped the phase, with a 1.5 s
watchdog (`ensurePhaseContentVisible`) after every phase change. With demo logging on, `visible`, `watchdog`,
`fadeInFallback` and `keyboard` events land in `demo-audio-log.jsonl` for the next investigation. **Recording**:
the v7 video (`NoteStalgia-Walkthrough-v7.mp4`, ~20.8 min, ten flows) is rebuilt from the `i_onboarding` take;
`edge-tts` had to be upgraded again before the narration would synthesise; the previous nine-flow cut is kept
at `.demo-work/NoteStalgia-Walkthrough-v7-before-partI.mp4`.

### Done — Usable POC backend (Cloudflare free tier), song catalogue search, discovery model (Oct 2026)

- [x] **`../NoteStalgia-Backend`**: Hono Worker + D1 + nightly Cron, 55 vitest tests on the Workers runtime,
      `contracts/openapi.yaml` (v1, shared with Android / production), ADR 0001 (POC deviations: PBKDF2 +
      pepper, no email verification, dev-only reset codes, Apple previews demo-only, EU D1, demo data only).
- [x] **Auth / tenancy / seed**: sign-in, refresh rotation with families, sign-out, household sign-up (org
      domains refused), PIN reset (`devCode` only in dev), `/me`; `seed/demo.json` exported from the app
      (`-NoteStalgiaExportSeed YES`) and loaded through `POST /v1/admin/seed` so PINs hash with the live pepper.
- [x] **Sync**: `GET /homes/{id}/sync?since=seq` (one UNION over residents / sessions / group sessions, blobs
      concatenated, tombstones) + `POST /sync/push` (one batch, residents LWW by `updatedAt`, sessions / groups
      insert-or-ignore, per-item status) + portraits (JPEG in D1). iOS `Core/Sync/SyncEngine` observes the
      stores, keeps an on-disk outbox (incl. signals + portraits), pulls on sign-in / foreground / ≥ 60 s,
      `LocalCache` per home, `CareDataStore.isSeeded` readiness, `AuthSession` + Keychain + `PrincipalCache`.
- [x] **Catalogue + search**: `seed/catalogue-seed.yaml` (~155 curated songs, 7 genres, decades, nationality
      tags) → `scripts/seed-catalogue.ts` (iTunes GB + MusicBrainz, seed year wins) → `catalogue.resolved.json`
      (167 playable tracks). `GET /music/search` D1-first then one cached iTunes call (token bucket, 7-day cache,
      curated rows rank first); `browse`, `tracks/{id}`; reggae / ska / calypso → Soul. iOS `SongSearchSheet`
      ("Find a song they love"), `ResidentTrackRef` everywhere a title was, previews auto-advance / prefetch /
      skip dead previews, mood resolved by genre for catalogue tracks.
- [x] **Discovery + taste model** (`worker/src/model`, pure TS): priors (birth year + nationality), evidence
      with shrinkage + 12-week decay, seeded exploration, diversity, explainable reasons; `discovery/plan`,
      `discovery/results`, `signals`, `recommendations`, `taste` + stateless cold routes for unsaved residents.
      iOS plays the plan with a staff caption, posts picks, writes `Discovery · <Genre>` playlists, caches
      per-genre queues, batches listening signals per session.
- [x] **Verified live on the iPad simulator against `wrangler dev`** (27 Oct 2026): sign-in → pull → search
      → Add → push → calm surface playing Apple previews with auto-advance → sun-like → staff return → signals
      batch → session pushed → discovery pass (7 catalogue previews, captions) → results → playlists + queues.
      Fixed on the way: Add / Apple-Music link firing together in the List row, double outbox flush, family
      picks missing from the glyph queue, favourite flipping on an evidence tie, ad-hoc upstream rows
      outranking curated ones.
- [x] **Deployed (27 Oct 2026)**: `npm run deploy -- --seed` on the user's Cloudflare account → worker
      `notestalgia-api`, D1 `notestalgia-poc` (`weur`), secrets set, demo + catalogue seeded. Run the app with
      `-NoteStalgiaAPIBaseURL https://notestalgia-api.fitraclesub.workers.dev`. Re-running the deploy is a
      no-op; `NODE_EXTRA_CA_CERTS` must point at the macOS system roots on this Mac (see the backend README).
      The Xcode scheme's run action (`project.yml` → `schemes.NoteStalgia-iOS.run.commandLineArguments`) now
      carries that argument enabled, so ⌘R hits the deployed backend; untick it in Edit Scheme to run offline.
      The UI-test action and the demo scripts set their own arguments and are unaffected. Verified 27 Oct
      19:02: real sign-in as Max → roster 31 residents / 92 sessions / 6 group sessions from the server cache.
- [x] Apple refuses the deployed Worker's upstream searches with **429** (seen in `wrangler tail`; the curated
      catalogue was unaffected). Built the designed fallback: the Worker marks its upstream `blocked` for
      10 min after a 403/429 (`rate_limits` key `itunes:blocked`), the iPad queries iTunes itself
      (`Core/API/ITunesDirectSearch.swift`) and posts the raw results to `POST /music/tracks/ingest`, which
      maps and stores them like an upstream hit. Verified from the iPad against the deployed Worker
      (sign-in → pull → "ronnie hilton" in the search sheet → results via the device → ingested → served to
      the next search). Ad-hoc tracks arrive with Apple's compilation years; the nightly Cron corrects
      ≤ 15 per run through MusicBrainz. Android needs the same two steps.
- [x] **Cover art (27 Oct 2026)**: the Apple artwork the Worker returns with every track / snippet is now the
      song's picture everywhere. Discovery: `DiscoveryEraListeningOrb` takes the plan snippet and fills the orb
      with its sleeve (`imagePosterOverride`, video suppressed) — the era scene remains for the bundled clips.
      Resident surface: `ResidentPlaylistBackdropView.artworkURL` makes the sleeve the full-page backdrop
      (bundled stems keep the mood scene). Both ask Apple's CDN for the 1200 px variant
      (`ResidentTrackRef.artworkURL(side:)` rewrites the `600x600bb` path segment; verified the CDN serves
      1200 and 200) and go through `SceneImageCache`, with the current ± 1 sleeve prefetched. Staff thumbnails
      (`Core/TrackArtworkView.swift`, 200 px, 80-entry memory cache) sit on the search-sheet rows and the
      discovery caption. Fixed on the way: `DiscoverySnippetMediaFill` left `posterReady` stuck at true on a
      cold image switch, so the orb's equaliser never re-armed once a sleeve loaded after the switch —
      readiness now follows the new poster (the previous still stays on screen meanwhile). Verified on the
      iPad against the deployed Worker (Kathleen Ferrier in the orb with the equaliser, Louis Armstrong
      full-page behind the Jazz glyph). Android: same three spots once it has online discovery / previews.
- [x] **Real-time song selection (27 Oct 2026)**: the recommender now combines age, origin, liked genres and
      "songs like the ones they love". New `worker/src/model/similarity.ts` (same artist = 1; else genre +
      Apple sub-genre + era closeness + shared nationality tag, capped at 0.8; × how much they like the
      song, where one staff pick ≈ 0.8, one sun-like ≈ 0.6, a green = 1), a `similar` term in `scoring.ts`
      (weight 0.9; a liked song is its own best match so it always leads its genre), liked songs / liked
      artists always in `candidatesForGenre` regardless of the era window, `MAX_PER_LIKED_ARTIST = 3`,
      `staffPick` / `staffPickRemoved` signals (track +0.8 / −0.8, genre +0.3, decade +0.2), reasons
      "A song they like" / "More from X, whom they like" / "Close to “Y”, which they enjoyed". New
      `POST /music/artists/expand {artist}` grows the catalogue around a loved artist (catalogue first,
      one cached upstream artist search per week, device fallback through `/music/tracks/ingest` with
      `artist`); ad-hoc songs by a curated artist inherit the curated genre + tags
      (`inheritFromCuratedArtists`), and `expand` heals rows ingested earlier. iOS: `noteStaffPick`
      (DiscoveryFlow.swift) sends the signal and expands the artist when a song is filed / unfiled;
      `enqueueListeningSignals` expands up to two sun-liked artists per session; `SyncEngine.
      onSignalsDelivered` → `refreshRecommendations`, so queues re-rank after every staff pick and every
      session. Fixed on the way: `bump` in taste.ts mutated the previous profile's evidence objects when
      no decay applied (chained profiles shared state). Verified on the deployed Worker from the iPad:
      filing "We'll Meet Again" for Irene (UK, 83) → signal applied within seconds, Vera Lynn grew from 2
      to 13 songs via the device, her Pop queue became We'll Meet Again · There'll Always Be an England ·
      The White Cliffs of Dover · then 1958–67 British pop. 63 Worker tests. Android: same signal kinds,
      expand call and post-signal refresh once it has the API client.
- [x] **UUID case fixed on the Worker (27 Oct 2026)**: Swift's `uuidString` is uppercase, so the seed export and
      every push stored uppercase ids for residents whose UUID contains a hex letter (`…00000000000A`, the
      `AAAAAAAA-…` additions), while the client's paths and bodies are lowercase and SQLite compares TEXT
      case-sensitively — signals, discovery, recommendations and the new room playlist silently missed about
      a third of the roster. Migration `0003_lowercase_ids.sql` lowercases every stored id and the Worker now
      lowercases ids at every boundary (seed, push, home middleware, resident loaders, portraits); the test
      `resolves ids whatever their case` covers it. Existing refresh tokens for letter-id accounts are invalid
      after the migration (the demo accounts have digit-only ids).
- [x] **Group sessions on the model (27 Oct 2026)**: `worker/src/model/group.ts` + `routes/group.ts`
      (`POST /homes/{id}/group/playlist`, staff only, two reads + catalogue): every candidate is scored for every
      participant with `scoreTrack`, group score = mean + 0.3 × share who love it + 0.15 × share with a similar
      liked song, round-robin across the room's genres (or the activity's genre), two per artist, reasons +
      champions per track. iOS: `GroupSessionTrack` carries a `ResidentTrackRef` and a reason; the compiler
      takes residents' real songs (playlist refs with previews) before bundled titles; `prepareGroupPlaylist`
      (DiscoveryFlow.swift) fetches the room's picks when a session starts and puts them in front of the roster
      list; the group screen plays previews once with the sleeve, prefetches the next, shows "for <resident>" +
      the reason; `GroupActivityPlanner.genreAffinity` credits liked catalogue songs via the profile's refs.
      Android: none of this yet.
- [x] **Group playlist arrives in one piece (28 Oct 2026)**: Start now opens the group screen on a `CalmCircularLoader`
      ("Choosing songs for the room…", `group.preparing`) while `prepareGroupPlaylist` runs — backend picks
      (8 s cap) merged with the roster list, the first eight sleeves decoded (4 s cap) and the first preview
      prefetched, never shorter than 3 s — then the finished list fades in and playback starts with it
      (`GroupSessionStore.isPreparingGroupPlaylist`, `groupSessionPreparationID` discards a late result).
      Songs and artwork no longer pop into the list one by one. The top-bar button reads "Back" while
      preparing and returns to the planner with the selection intact; the session clock starts at the reveal.
      The v7 Part H take predates this and shows the picks arriving live (left as is by choice).
      Android: no group sessions on the model yet.
- [x] **UX / accessibility round 6, every page (28 Oct 2026)**: `docs/UX_REVIEW_2026-10-28.md`. Log out moved
      top-right (`FlowTopStaffNavBar` + the group session bar). New `Core/BrandDataDisplay.swift` (section
      header, inset tile, stat tile, meter + rating row, rating tone + legend, status chip, hairline, quote
      block, key/value row, accessible segmented choice, selectable chip) and the `BrandTheme` data tokens
      (`cardBorder`, `surfaceInset`, `insetBorder`, `hairline`, `meterTrack`, `status*`). Applied to the session
      summary, observation steps, context tags, feedback sliders, group check-in, roster and profile observation
      tiles, comfort notes, "for next time" meters, session history cards, admin dashboard (KPI accent, group
      programme tiles, wing meters + chips, trend chips, hairlines, trend charts in a grid on iPad), Care at home
      home + insights, planner (pinned Start, zero chips hidden, tiles, hairlines, glyph label), group session
      (headers, hairlines, reason icon, transport label halos), search sheet (44 pt Add, labels), immersive
      vitals tiles, discovery / mood captions with the orb halo. Android: the status tints,
      pinned Start, zero-chip hiding and "14 days" copy are behaviour the Android app mirrors — TODO there.
- [x] **Round 6b — the review's open items (28 Oct 2026)**: PIN caret only on the focused field + first-field
      focus on the Care at home forms; roster display-mode picker on `BrandSegmentedChoice`; home leads get
      **Open the roster** on the dashboard (`openRosterFromAdminDashboard`, Back returns via
      `returnToAdminDashboardFromRoster`); planner residents in three sections (benefit · seen recently ·
      better one-to-one, collapsed); **Who stood out?** on the last group check-in step →
      `GroupSessionRecord.participantNotes` (`GroupParticipantNote` / `GroupParticipantState`, optional on the
      wire, documented in `contracts/openapi.yaml`; `WireSchema.version` unchanged — additive) read by the
      profile line, planner status line, per-person engagement and the one-to-one nudge; VoiceOver on the
      resident surface (glyph label/value/hint, Next/Previous song custom actions, hidden backdrop, dock hints,
      "Now playing" announcement). Android TODO: planner sections, participant notes in the record and the
      heuristics above, plus the round-6 items.
- [ ] **Organisation & home onboarding — planned, not started (28 Oct 2026)**: `docs/ONBOARDING_PLAN.md`.
      Request a workspace → email code → operator approval → activation (org admin + PIN + DPA) → iPad wizard
      (organisation + domains · homes + wings · staff invites by single-use code · residents by CSV through the
      existing sync push · device guidance · ready checklist) → ongoing team / audit / export. Data model,
      contract routes, phases A/B/C and the open product questions are in the doc. Android after iOS slice A.
- [x] **Playing glyph: smaller, translucent, draggable (28 Oct 2026)**: `ResidentProfileView.heroDiskScale`
      (0.6) shrinks the hero disk while `ResidentGlyphButton.equalizerDiameter` keeps the ring at the former
      154 × hull-scale; the disk draws at 60% opacity (ring outside the modifier, opaque). `heroDragGesture`
      (simultaneous on the hero, global coordinates) commits `heroDragOffset`, live drag in `heroDragLive`,
      both clamped by the ring's canvas; `heroDragInProgress` makes the surface's song swipe stand aside; the
      periphery is laid out around `hub + heroDragOffset`; the offset resets on genre change / stop. The hero's
      bars reach twice discovery's (`HeroTuning.barReach`, `outwardPad(for:barReach:)` sizes the canvas; the
      drag clamp and the periphery clear that canvas). Android TODO: same behaviours on the resident surface.
- [x] **v7 demo video (27 Oct 2026)**: `NoteStalgia-Walkthrough-v7.mp4` + `.srt` (13 min, nine flows) — what's new
      since v6, recorded against the deployed Worker with ≥ 3 s after every tap: live sign-in and sync, the
      Group activities card, Find a song they love, real-time re-ranking after a staff pick, cover art on the
      calm surface, online discovery, a group session ranked for the room, the Group programme card. Scenarios `testStoryPartE/F/H/G…`, narration
      keys `v7_*`, builder `tools/demo/pipeline/build_v7.py`, demo reset `tools/demo/reset-backend.sh`
      (`POST /admin/seed {reset}`), takes video-only with Apple previews rebuilt from the log. Recorder
      lessons are in `tools/demo/README.md` (absolute output path, writes on stop, disk vs typed takes).
- [x] **Resident-surface swipe fixed (27 Oct 2026)**: the next / previous-song swipe never fired — the gesture sat on
      a container whose only child (the backdrop) is not hit-testable, so SwiftUI had nothing to hit; a
      `.contentShape(Rectangle())` on the container makes the empty space swipeable while the glyphs and the
      comfort dock above still take their taps first. Found while scripting the v7 demo (the next song only
      ever started when the preview ran out).
- [ ] A device that switches base URLs keeps its per-home sync cache and cursor (`LocalCache` is keyed by
      home id only): reset the app data (or key the cache by API host) before pointing an installed app at
      a different backend.
- [ ] **Android TODO (parity)**: API client (`contracts/openapi.yaml`), Keychain-equivalent token store,
      seq-cursor sync + outbox, `ResidentTrackRef` / preview playback with Media3, song search sheet, online
      discovery plan / results / signals, household sign-up through the API. Until then Android stays
      offline on its mock data.

### Done — UI / crash / performance pass (Oct 2026)

- [x] **Crash:** audio tap read past the end of non-interleaved stereo buffers (`MusicReactiveAnalyzer.ingest`).
- [x] **Crash:** tap context was unretained → use-after-free when AVFoundation finalised the tap after
      the view/analyzer died; tap now retains in `tapInit`, releases in `tapFinalize`.
- [x] **Race:** smoothing state reset from main while the audio thread wrote it — reset is now
      requested and applied on the audio thread.
- [x] Admin dashboard: trend strip overflowed its card on iPhone (horizontal fade row height).
- [x] Resident full-page media left a strip under the status bar.
- [x] Dark system appearance; readable placeholders; stale sign-in error clears on edit; copy fixes.
- [x] Perf: ambient sparkles + orb shell pause while full-page media covers them (~60% → ~15% CPU
      in simulator while a song plays); per-frame glyph lookups hoisted; roster sentiment card cached;
      iOS 18+ skips the per-frame scroll-metrics preference.
- [x] Session "time on surface" froze at staff handoff — it previously kept counting while the carer
      filled in the observation form (and was saved that way into the record + handover text).
- [x] Roster subtitle no longer shows "Last visit · — ·" for untagged resident-surface sessions;
      saving a new resident clears a stale roster search so they are visible straight away.
- [ ] Profile on a real iPad in **Release** — Debug (`-Onone`) makes the orb noise maths several times slower.
- [ ] **Open:** hidden 1×1 PIN field dropped digits under heavy load in the simulator — spot-check fast
      typing on a real device.

### Done — UX pass + deeper performance (Oct 2026, round 2)

- [x] Wing chips now filter the curated roster (header shows "N residents on {wing}").
- [x] Roster cards trimmed to place · last visit (relative day) · % at ease; search pins the field to the
      top and hides the home summary so results sit under the field.
- [x] Profile: primary "Open resident calm surface" moved under the name; discovery copy shortened.
- [x] Resident surface: staff return is press-and-hold with hint on quick tap (VoiceOver: custom action).
- [x] Group mode plays the listed track; playlist limited to bundled-audio titles.
- [x] Sentiment / group check-in forms top-aligned (buttons no longer slide under the finger between steps);
      insight "Copy …" buttons confirm in their own label.
- [x] Perf (no visual change): orb halo/glow cached sprites, wisps GPU-flattened, empty ripple canvas removed.
      Idle sign-in CPU ~30% → ~21% (iPhone sim, Release); recorded demo smoothness 22 fps → 27–50 fps.
- [x] `DemoAudioLog` (launch arg `-NoteStalgiaDemoAudioLog YES`) logs music/chime/phase events for demo
      soundtrack reconstruction; off by default.
- [ ] **Android TODO:** wing-chip filtering semantics, press-and-hold staff return, group playlist plays
      listed (bundled) tracks, roster card subtitle format.

### Done — Interaction feedback + session summary (Oct 2026, round 3)

- [x] Glowing pulse on every staff button press (keyframe halo + spreading ring, `CalmMotionViews.swift`) and
      a chime on every press; non-button controls (toggles, segmented pickers, steppers, menus, photo pickers)
      chime on change. Reduce Motion skips both.
- [x] Screen-tap glow ripple app-wide (`Core/TouchRipple.swift`, mounted in `AppRootView`). Passive window
      recogniser — verified with touch logging that it neither delays nor duplicates touches.
- [x] Post-session insight page rebuilt as a structured **Session summary** (`CareSessionInsightView`, data from
      `CareSessionInsightSummary` / `handoverSections` in `CareSessionSentiment.swift`). Handover / family /
      care-plan texts are byte-identical to before (handover text is now rendered from the same sections).
- [x] Fixed "conditions.." double full stop in the low-wellbeing next-step suggestion.
- [ ] **Android TODO:** press glow + chime on buttons, screen-tap ripple, and the structured session summary
      layout (at-a-glance tiles, rating bars, responded-to card, single write-up switcher).
- [ ] Simulator demo automation note: the PIN auto-submits on the 6th digit — don't tap Continue afterwards
      (the tap lands on the roster that has already loaded).

### Done — Group activities: intelligent resident selection (Oct 2026)

- [x] From the product specialist's brief: the roster's "Group activities" button now opens a **planner**
      (`Screens/GroupActivityPlannerScreens.swift`, phase `careGroupPlanner`) with suggested activities built around
      shared musical tastes, staff suggestions (nobody overlooked · organise · pairings · better served one-to-one),
      a resident picker sorted by who would benefit most (flags: overdue a visit, due a group, regular, small groups,
      prefers 1-to-1, keep it gentle) and an engagement overview (regulars, needs encouragement, activities that land
      best). All heuristics live in `Core/GroupActivityPlanner.swift`; participants + activity are stored on each
      `GroupSessionRecord`; `CarePatientProfile.groupComfort` is the staff-set comfort flag; demo history seeded.
- [x] Follow-ups done (26 Oct 2026, `Core/GroupActivityFlow.swift`): the resident profile has a "Group activities"
      card with the participation line (`profile.groupActivities`) and the staff-set **In company** picker
      (`profile.groupComfort` → `setResidentGroupComfort`); the home-admin dashboard has a **Group programme** card
      (`admin.groupProgramme`: sessions, reached, engagement, morale, activity that lands best, residents who would
      welcome a group but had none), cached via `CareRosterUIStore.groupProgrammeCache` (home + data revision +
      group-record count). `testGroupPlannerWalkthrough` now covers both cards.
- [x] Fix (26 Oct, found in the UX review): group records were not scoped to the home, so Riverside House's
      "Group programme" card showed Maple Lodge's best activity. `GroupActivityPlanner.build` now keeps only
      records that involved the residents it is given.
- [ ] **Android TODO:** planner screen, heuristics, `groupComfort` (+ the profile picker and participation line),
      participants on group records, roster copy, the admin "Group programme" card.
- [ ] **Open — UX review round 5 (26 Oct 2026):** findings and the suggested order live in
      [`docs/UX_REVIEW_2026-10-26.md`](UX_REVIEW_2026-10-26.md). Headline items: a skipped whole-home session counts as
      a group for every resident; the chosen activity theme does not shape the compiled playlist; Start is buried under
      the resident list; home leads cannot reach the roster/planner; the trend strip clips its third chart on iPad;
      cognitive/accessibility/care needs are not modelled (brief §5). iPad is the primary target for all of these.

### Done — Care at home scenario (Oct 2026)

- [x] **Household accounts** (`Core/HouseholdCareModels.swift`, `Core/HouseholdCareFlow.swift`,
      `Screens/HouseholdScreens.swift`): a family member or private carer creates an account on the sign-in
      screen (any personal email + chosen PIN, stored on the device), registers **one** resident (name, age,
      nationality, optional photo; discovery optional and re-runnable), and lands on a home screen with Open
      calm surface · Insights & trends · Profile & preferences · Listening discovery. Resident surface,
      discovery, observation and session summary are the shared screens; "back" goes to the home screen
      (`staffHubPhase()`). Demo household `claire@example.com` / `123456` → Harold T. with 14 days of history.
- [x] **Per-resident insights** (`CareHomeAnalytics.buildResidentInsights`): trends, KPIs, observation
      averages, responded-to genres, next step, recent sessions — reusing the admin dashboard subviews
      (`DashboardTrendGraphsStrip`, `DashboardKPICardView`, `DashboardRecentSessionRow`, now internal).
- [x] **Tenancy**: `SupervisorRole.household`; each household is a one-wing `CareHome`; `CareAccountDirectory`
      merges mock + household accounts and homes (auth, PIN reset, demo sign-in all go through it).
- [x] **Persistence**: `HouseholdCareStore` writes residents/history (JSON, Codable models) and portraits
      (JPEG) to Application Support, merged into the launch seed. **Landmine:** renaming or removing a field
      on `CarePatientProfile` / `CareSessionRecord` / `CareGenrePlaylistGroup` / `CarePlaylistEntry` breaks
      decoding of stored households — add a version or migration if you change them.
- [x] **Orb frame-rate pass** (`Core/ReferenceOrbNebulaRender.swift` `NebulaDensityPrecompute`, `Core/OrbOverlayTextStyle.swift`
      `flattenedShadows`, `Core/OrbRenderBudget.swift`, `Core/OrbFrameMonitor.swift`, `tools/demo/orbperf.sh`): measured on the
      iPad simulator with a CADisplayLink monitor + `sample` of the app *and* of `backboardd`. Findings: the app's main
      thread was ~76% idle at idle sign-in, yet the display link delivered only ~20 fps; the simulator's render server
      spent 76% of its render thread in `CA::OGL::ShadowNode → blur_surface → MTLSimDriver waitUntilScheduled` — one
      synchronous host-GPU round-trip per `.shadow` per frame (≈13 passes on the sign-in screen: 4 per orb-overlay label,
      button label, card, 3 on the shell). Changes: nebula noise precomputed one frame ahead off-main (same values;
      canvas 1.9 → ~0.9 ms), shell timeline at display rate (120 Hz capable), shadows flattened into textures (pixel
      diff 0 vs Core Animation in a frozen-orb A/B), launch warm-up already moved under the splash. Simulator A/B,
      interleaved, window visible: CA shadows median ~16.5 fps vs flattened 19–30 fps (noisy — the 8 GB machine was
      swapping with <2 GB disk free). The simulator's delivered rate also depends on the Simulator window being visible
      (15–20 fps hidden vs 33–42 visible). **On device the orb should hold 60 / 120 fps; verify on an iPad before judging
      smoothness from the simulator.** Measurement switches (demo-only): `-NoteStalgiaDemoFrameLog`, `-NoteStalgiaDemoFreezeOrb`,
      `-NoteStalgiaPerfCAShadows`, `-NoteStalgiaPerfSyncNebula`, `-NoteStalgiaPerfNoShellShadows`.
- [x] **Smooth opening** (`Flow/FlowRootView.swift` `LaunchWarmUp`, `Core/DiscoveryEtherealTapChime.swift`,
      `Core/AppAudioSession.swift`, `App/Assets.xcassets/LaunchBackground.colorset`): a cold-launch sample showed the
      single `LaunchWarmUp.perform()` call blocking the main thread for ~2 s at t≈0.4 s of the title animation
      (keyboard pre-load with a synchronous pasteboard XPC, plus audio session + `AVAudioEngine` start), i.e. the
      "laggy opening". Now: keyboard + glow sprites before the first frame under a brand-coloured launch screen
      (was white), audio entirely off-main (engine created/started on a background queue; `play()` waits it out),
      remaining warm-ups staged per run-loop turn. **Landmine:** keep `performBeforeFirstFrame()` in `onAppear`
      *before* `launchAnchor = Date()` — anchoring first would start the title mid-animation.
- [x] **Walkthrough v6** (`NoteStalgia-Walkthrough-v6.mp4` + `.srt`, ~16 min — the only demo video kept; v1–v5 were purged on 7 Oct 2026 at the user's request): v5's three care-home
      takes plus a fourth story take `testStoryPartD_Household` (create account → register → session → first
      insights → Claire's household with a fortnight of data) as flow 9 "Care at home"; the panel index now runs
      five rows per column (`build.py` `INDEX_ROW_H`), the intro names both settings, and
      `-NoteStalgiaDemoResetHouseholds YES` lets the sign-up reuse the same email every take.
- [x] **Production plan updated** (`docs/IMPLEMENTATION_PLAN.md`): households are a second tenant kind on the
      same platform (B2C: self-serve verified sign-up, `HouseholdCarer` role, controller-mode consent with carer
      authority attestation, per-resident insights grain, store billing via a new Billing & Entitlements context,
      consumer cells, account-triggered rollout table in §12.3, `consumer_launch` flag). The care-home platform
      does not wait for the consumer rails.
- [ ] **Android TODO:** household account + single-resident registration, per-resident insights screen,
      sign-in copy ("Caring for someone at home? Create an account"), on-device persistence.
- [ ] Open: no email verification or account recovery beyond the demo reset code; one resident per
      account (a second resident needs a second account); the demo household never persists sessions.

### Done — UX review round 4: stable portraits, honest loading, nav safety, copy, a11y, exact-only perf (Oct 2026)

- [x] **Portraits never swap.** Root cause was `AsyncImage` with a stock photo of a *different* person as
      placeholder, rebuilt on every phase change. The 12 Wikimedia photos are now bundled
      (`PortraitWoman01–06`, `PortraitMan01–06`), assigned by `ResidentPortraitCatalog.assetName(displayName:)`
      (same gender + FNV-1a hash → same face each resident had before), pre-decoded off-main at launch.
      `remotePortraitURL` and the `StockPortrait*` assets are gone.
- [x] Welcome screens gate on real readiness (`Core/RosterWarmUp.swift`): roster seeded, portraits decoded,
      presentation cache warm; 2.2 s / 2.8 s minimum, 6 s cap, late hint after 2.6 s.
- [x] Loading fallbacks with timeouts: nature video (8 s / item failure), discovery media (6 s), photo picker
      progress + failure copy with off-main ImageIO decode (`UIImage.decodedThumbnail`).
- [x] Nav safety: discard confirmation on the new-resident form; "Skip" back titles where Back saves; staff-key
      and roster-back VoiceOver labels fixed; pinned section A–Z; admin trend dots keyed to their own day
      (nil days used to misalign dots and labels).
- [x] Copy: Log out · % at ease · Session summary · carer observations · Day programme · "Save observation";
      duplicate "next step" in history removed; launch ellipsis; "Opening calm surface".
- [x] A11y: 44 pt hit areas (top chrome, search clear, pins, Forgot PIN) via `expandedHitArea` with unchanged
      visuals; selected chips / mood orbs announce *Selected*; Dynamic Type on Forgot PIN + sign-in error.
- [x] Perf, pixel-exact only (orb render code untouched): icon orbs 20 fps + pause on keyboard/scroll/background
      (`flowAmbientPaused`); staff immersive holds the full-page cover; resident glyphs / mood orbs built once,
      moved by transforms; discovery orb no longer observes the audio bus; live equalizer redraws on bus
      publish; tap-ripple sprite; loader 60 fps cap; chime engine idle pause (20 s); `DemoAudioLog` autoclosure.
- [x] Verified (iPad Air 11 sim, Debug): welcome gate dwell 2.73–2.76 s (ready well inside the cap); faces identical
      across profile ↔ roster and Cards ↔ Compact on iPhone + iPad; Reduce-Motion A/B screenshots old vs new —
      the orb itself diffs to 0 on sign-in, roster and resident surface (only the per-run sparkle field and the
      glyphs' launch phase differ); glyph zoom-crops identical. `sample` main-thread idle: roster 70% → 70% (the
      nebula noise, deliberately untouched, is the whole cost), resident surface playing 93% → 94% with the
      per-tick `floatingGlyphButton` rebuild gone from the profile.
- [ ] **Skipped on purpose:** nebula noise RNG swap (not bit-identical — user chose exact-only); shell-shadow
      sprite and text-shadow flattening (need A/B); `ScrollContentEdgeFade` mask skip (toggling the mask changes
      view identity and would reset scroll state); dropping the `vitals` forward from `SessionPOCState`
      (`CareSessionPrepView` binds `$state.iot*`; low win, medium risk).
- [ ] **Android TODO:** bundle the same 12 portraits with identical names/order and hash assignment; pinned A–Z;
      copy terms above; discard confirmation; video/discovery timeouts + copy; photo-picker loading/failure state.
- [x] **Identifiers everywhere**: all ~90 interactive controls carry an `accessibilityIdentifier` (table in
      `tools/demo/README.md`); XCUITest walkthroughs never tap by coordinate.
- [x] **Centring**: `HorizontalScrollEdgeFade` centres its row when it fits (wing filter pills were hugging the
      leading edge on iPad); audit of the other screens found cards, titles and buttons already centred.
- [x] **Resident profiles fleshed out** (`Core/ResidentProfileSeeds.swift`): the 28 generated Maple Lodge
      residents and 6 Riverside residents each have their own sensory notes, reminiscence anchors, ages,
      nationalities, favourite + secondary genre, bundled-audio playlists and suggested liked songs (they used
      to recycle Elena / James / Sam's templates). **Android TODO:** mirror the seed table in the Android mock roster.
- [x] **Walkthrough v5 — v4 with a neural voice and subtitles** (`NoteStalgia-Walkthrough-v5.mp4` + `.srt`,
      same cut as v4; file since purged — v6 supersedes it): narration re-rendered with `edge-tts` (`en-GB-RyanNeural`, network; `DEMO_VOICE=Daniel`
      keeps the offline macOS voice), every cue burned in as a subtitle strip under a slightly smaller device
      (`build.py` `subtitle_strip`, compositor overlays with `x`/`y`), and an `.srt` sidecar for players and
      YouTube. This ffmpeg build has no libass/drawtext, hence the compositor route.
- [x] **Walkthrough v4 recorded — narrated, chronological** (`NoteStalgia-Walkthrough-v4.mp4`, ~11¾ min,
      gitignored; file since purged — v6 supersedes it): one afternoon end to end in three continuous story takes
      (`DemoUITests` `testStoryPartA_SignInToSummary` / `PartB_DiscoveryAndGroup` / `PartC_Admin`, Release build,
      iPad Air 11 sim, typed sign-in, no demo jumps, slow on-screen scrolling through every long screen). Each
      scripted step writes a timestamped marker; `tools/demo/pipeline/build_story.py` (was `build_v4.py`) cuts chapter cards where the
      marker's flow changes, shows the caption until the next marker, and queues the spoken line
      (`narration.py`, loudness-normalised, music ducked underneath; v4 used macOS `say` Daniel at 168 wpm). Holds in the
      script are sized to the narration; follow-on lines (`EXTRA`) fill holds longer than ~12 s. **Landmine:** the
      simulator recorder does not keep wall-clock time — it loses 1–2 s under load (app launch, discovery media)
      — so the clock offset is measured at every clean phase change and interpolated between them (close
      phase pairs are skipped because their steps can't be told apart). `walkthrough.sh` now trims by the
      first marker, re-encodes takes to half resolution (a 6-minute take ≈ 300 MB) and deletes the raw file.
      BlackHole capture still records silence while the Mac's output is on the speakers, so the soundtrack is
      rebuilt from the demo log. Re-run: three `walkthrough.sh` calls then `python3 tools/demo/pipeline/build_story.py`.
- [x] **Walkthrough v3 recorded** (`NoteStalgia-Walkthrough-v3.mp4`, 4 min 55 s, gitignored; v1–v3 files since
      purged — v6 supersedes them): four scripted takes (`tools/demo/walkthrough.sh` resident / discovery / group / admin
      at `DEMO_PACE=1.1`, Release build, iPad Air 11 sim) assembled by `tools/demo/pipeline/build_v3.py` — chapter
      cuts and captions come from each take's event log, sync is calibrated from the frames, soundtrack rebuilt from
      the log (BlackHole capture is wired but the Mac's output was on the speakers). Re-run the whole thing with
      `tools/demo/walkthrough.sh <scenario> <take>` ×4 then `python3 tools/demo/pipeline/build_v3.py`.
- [x] **Demo recording toolkit** (`tools/demo/`, `DemoUITests/`, `Core/DemoLaunchOptions.swift`): scripted
      XCUITest walkthroughs (resident session, discovery, group, admin) recorded by `walkthrough.sh`; `record.sh`
      captures simulator video + BlackHole loopback audio with ffmpeg; demo launch arguments and
      accessibilityIdentifiers on the main controls. The v1/v2 compositor pipeline lives in `tools/demo/pipeline/`
      with repo-relative paths (`DEMO_WORKDIR`, default `.demo-work/`, gitignored). Machine: ffmpeg + BlackHole
      installed Oct 2026 (BlackHole needs a reboot before it appears as an audio device).


- [ ] iPad + iPhone: glyph hit targets during equalizer / media expansion  
- [ ] Cloud-skip last track stops audio; sun-like persists preference  
- [ ] Rage-tap bursts must **not** boost genre preference (metrics already distinguish — regression-test)

### P2 — Staff chrome / phone

- [ ] Spot-check all `CenteredScrollScreen` phases after top-inset fix  
- [ ] Admin trend strip + roster wings horizontal fade on small widths  

### P2 — Performance regression pass

- [ ] Scroll roster with sparkles paused (`AmbientInteractionPause`)  
- [ ] Keyboard on sign-in pauses ambient  
- [ ] Scene still crossfade without backdrop remount flicker  

---

## 2. Medium-term POC work

Backend follow-ups (all optional; the POC works without them):

- [ ] One free Cloudflare WAF rate-limit rule on `/v1/auth/*` after the first deploy.
- [ ] Migrate tests to `@cloudflare/vitest-plugin` (the `vitest-pool-workers` package was renamed).
- [ ] Riverside has no supervisor account in the seed; home leads cannot open the group planner (UX review).
- [ ] A staff-facing `/taste` view (the explain reasons already come back with every queue).
- [ ] Run `testGroupPlannerWalkthrough` / `testHouseholdWalkthrough` with
      `TEST_RUNNER_API_BASE_URL=http://localhost:8787` against `wrangler dev` in CI.

- [ ] Richer per-genre playlists (2–3 stems each) once more licensed/AI stems exist — keep
      **primary** stem stable for each glyph.
- [ ] Group session playlist compiler should prefer catalog titles that exist as bundled audio
      (avoid silent fallback to ambient loop).
- [ ] Trim / archive unused Mellority-named assets if any remain (`MellorityLogo.imageset`).
- [ ] Optional: short “How to run in Xcode” one-pager for free sharing (no TestFlight).

---

## 3. Production path (do not start unless asked)

Follow `docs/IMPLEMENTATION_PLAN.md`. Do **not** scaffold AWS/Mongo inside this POC repo without an
explicit request. The Cloudflare Worker is the **POC** backend behind the same v1 contract
(`../NoteStalgia-Backend/contracts/openapi.yaml`); production replaces it, keeping the contract, seed,
model code and tests. When production starts:

1. Extract SPM feature modules from `Core/` / `Screens/`  
2. Replace mock stores with OpenAPI clients from `notestalgia-contracts`  
3. Keep UX decisions in README catalogue unless product revises them via ADR  

---

## 4. Known landmines

| Risk | Detail |
|---|---|
| Double safe-area inset | Root `menuStandard` must stay `0`; chrome uses `safeAreaInset` |
| `String.hashValue` for imagery | Forbidden — use `StableHash` |
| Cross-genre track reuse | Forbidden in audible catalog (was the old bug) |
| XcodeGen wipe | Regenerating overwrites hand `DEVELOPMENT_TEAM` in pbxproj — set locally after generate |
| Android gospel raw | Needs `pine_smoke_drift_1` distinct from `pine_smoke_drift` |
| Audio tap threading | `MusicReactiveTapContext` state belongs to the audio thread — never mutate it from main; the tap owns a +1 on the context |
| Full-page cover pause | Only hold `AmbientInteractionPause.beginFullPageCover` while the covering layer is opaque **and** settled; always release in `onDisappear` |
| Portrait pool order | `ResidentPortraitCatalog` pool order is part of the resident→face contract — reordering either array changes every resident's face. `StableHash` must stay FNV-1a |
| Welcome gate | `RosterWarmUp` awaits `careData.$isSeeded` — set by the offline seed, the cache load or the first pull; anything that skips it makes the welcome dwell the full 6 s cap |
| Backend base URL | `-NoteStalgiaAPIBaseURL` is the only switch. The client appends `/v1`; ATS allows local networking only (`NSAllowsLocalNetworking`), so a deployed URL must be https |
| Sync cursor | Always the server `seq` (SQLite triggers), never `updatedAt`. Pull pages until `hasMore` is false; pushes must stay idempotent upserts |
| Free-tier budget | ≤ 50 statements per invocation, LIKE patterns ≤ 50 bytes, 100k requests/day: keep one `db.batch()` per write route and one signals row per session |
| Apple previews | Demo-only: stream from Apple's CDN, never cache server-side or re-host, keep the Apple Music link in the search sheet |
| Favourite genre | Server-side `chooseFavourite` needs an evidence lead of 0.12 as well as a blended-affinity lead; a stronger nationality prior alone must never flip a staff-set favourite |

---

## 5. Suggested first Claude task (copy-paste)

```text
You are continuing NoteStalgia-iOS. Read README.md, AGENTS.md, and docs/HANDOFF_PLAN.md.

1) git status — if genre icons + track remap are uncommitted, commit them with a clear message
   (only if the user asks to commit; otherwise summarise the dirty tree).
2) Confirm ResidentPlaybackTrackCatalog matches the README track table and Android PlaybackCatalog.
3) Run an iPhone simulator build.
4) Propose the next P0/P1 item from HANDOFF_PLAN and implement only after confirmation.
```

---

## 6. Decision log maintenance

When you change product behaviour:

1. Update the **Catalogue of decisions** table in `README.md`  
2. Add a bullet under the relevant section of this handoff file (done / superseded)  
3. Large production decisions → ADR under `docs/decisions/` (create folder on first ADR)  

Last catalogue refresh: handoff prep (genre artwork + 1:1 track map + staff chrome/fades + metrics).
