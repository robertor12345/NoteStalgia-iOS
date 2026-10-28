# AGENTS.md — NoteStalgia iOS

Instructions for Claude Code (loaded via `CLAUDE.md`) and any other coding agent working in this repository.

## Before you change code

1. Read [`README.md`](README.md) — especially **Catalogue of decisions** and the **track → genre → icon** table.
2. Read [`docs/HANDOFF_PLAN.md`](docs/HANDOFF_PLAN.md) — current priorities and open risks.
3. For production/cloud work, read [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md); do **not** invent competing architecture.
4. Prefer extending existing stores/screens over new parallel systems.

## Hard rules (product)

- **Name:** NoteStalgia (not Mellority).
- **Staff auth:** email + 6-digit PIN only in shipped POC UX.
- **Genre glyphs:** use `Genre*` asset catalog images via `ResidentMusicGenre.artworkAssetName` — do not revert resident surface to SF Symbols.
- **Audible playlist catalog:** only change track↔genre mapping in `ResidentPlaybackTrackCatalog` **and** mirror Android `PlaybackCatalog.kt` + discovery moods in the same change.
- **Gospel stem:** `Pine Smoke Drift (1)` is an **interim** stand-in; prefer replacing with a real gospel track over reshuffling other genres.
- **Top staff chrome:** never re-introduce root `safeTop + 8` padding for screens that use `CenteredScrollScreen` / `safeAreaInset` nav. Back is top-left, **Log out is top-right** (`FlowTopStaffNavBar`); any screen with its own bar keeps that order.
- **Data points and handover notes:** build them from `Core/BrandDataDisplay.swift` (`BrandSectionHeader`, `BrandStatTile`, `BrandRatingRow`, `BrandStatusChip`, `BrandInsetTile`, `BrandQuoteBlock`, `BrandSegmentedChoice`) and the `BrandTheme` data tokens — no ad-hoc tiles, tracks or colour-only status. Section titles are headers, meters read their value, status is icon + word.
- **Platform priority:** the resident and staff-session experience is **iPad-first** (check it on the iPad simulator first). **Admin, set-up and data-dashboard pages are phone-first**: design and verify them at phone width, then make sure they open up properly on the iPad. On any screen: one primary action per screen, no two controls with the same label, equal margins on all sides of a card's content, dividers between rows only, and nothing hidden behind a pinned bar or the keyboard (scroll each page to its end and open the keyboard on its last field).
- **Form input:** every text field in a form goes through `OnboardingField` (inline message, length cap, optional `InputFilter`) and its form's problem builder in `Core/Onboarding/OnboardingValidation.swift`, which uses `Core/Onboarding/InputRules.swift`. Rules are mirrored by `../NoteStalgia-Backend/worker/src/lib/validate.ts`: change both, and both test files, in one effort. Required fields are enforced on the page they live on and named in the message; characters that can never be right are filtered as typed, everything else is checked with a message — never silently dropped.
- **Face ID / IoT:** do not expand; production plan drops them for v1.
- **Do not commit secrets** (`.env`, keystores, App Store Connect API keys, Cloudflare `.dev.vars`).
- **Backend is optional:** everything must keep working with no `-NoteStalgiaAPIBaseURL` (in-memory seed, bundled stems, on-device heuristics). Online paths degrade to that behaviour on any failure.
- **Onboarding codes:** verification / activation / invite codes come back in API responses only when the Worker exposes them (`ENV != prod`, or `EXPOSE_CODES=1` on the demo deployment); never add another code to a response path, and never log one. Staff join only through invites (`INV-`), organisations only through an approved request (`ORG-`); household sign-up stays the one open door.
- **Sync contract:** cursors are the server `seq`, pushes are idempotent upserts, entity JSON is the client's Codable shape — change `contracts/openapi.yaml` in `../NoteStalgia-Backend` in the same effort as any wire change (`WireSchema.version`).

## Hard rules (engineering)

- Project is **XcodeGen**: edit `project.yml`, then `xcodegen generate`. Do not hand-edit `.pbxproj` unless unavoidable.
- Deployment target **iOS 17**. Prefer APIs available on 17; gate iOS 18+ extras (`onScrollGeometryChange`, etc.).
- Keep `SessionPOCState` as a thin coordinator — put new domain state in the appropriate `*Store`.
- Avoid per-frame `@State` updates on scroll/audio paths; follow `AmbientInteractionPause` / `OrbRenderBudget` patterns.
- Match existing visual language (`BrandTheme`, `BrandLayout`, `CalmMotion`) — no generic purple/Inter redesigns.
- After substantive Swift changes:  
  `xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Only `git commit` / `git push` when the user asks. No `Co-Authored-By` or other AI attribution trailers in commit messages or PR descriptions.

## Where things live

| Concern | Primary files |
|---|---|
| Flow / phases | `Flow/FlowRootView.swift`, `SessionPOCState` |
| Resident glyphs + play | `Screens/ResidentExperienceScreens.swift`, `ResidentPlaylistVisuals.swift`, `ResidentMusicModel.swift` |
| Track catalog | `ResidentPlaylistVisuals.swift` (`ResidentPlaybackTrackCatalog`) |
| Discovery audio order | `DiscoveryModels.swift`, `DiscoveryEraMedia.swift` |
| Mood / scene visuals | `MusicVisualMood.swift`, `SceneImageCache.swift` |
| Staff roster / chrome | `Screens/CareStaffScreens.swift`, `CenteredScrollScreen.swift`, `ScrollContentEdgeFade.swift`, `OrbNavControls.swift` (`FlowTopStaffNavBar`: Back left, Log out right) |
| Data display (tiles, meters, chips, handover notes) | `Core/BrandDataDisplay.swift`, `BrandTheme` data tokens; used by the session summary, profile history, dashboards, planner, Care at home insights. Review log `docs/UX_REVIEW_2026-10-28.md` |
| Group activities (planner + recommendations) | `Core/GroupActivityPlanner.swift` (heuristics, demo history, `betterServedOneToOne`), `Screens/GroupActivityPlannerScreens.swift` (three resident sections, pinned Start), `GroupSessionStore` (selection/plan), `SessionPOCState` group functions, `Core/GroupActivityFlow.swift` (profile participation line + comfort setter, admin "Group programme" card data), `Core/GroupSessionModels.swift` (`GroupSessionRecord.participantNotes` — "Who stood out?" at the check-in) |
| Care at home (household accounts) | `Core/HouseholdCareModels.swift` (accounts, store, directory, demo), `Core/HouseholdCareFlow.swift` (coordinator extension), `Screens/HouseholdScreens.swift`, `CareHomeAnalytics.buildResidentInsights` |
| Metrics → prefs | `ResidentSurfaceSessionMetrics.swift`, `SessionPOCState.residentPlaylistTitles` |
| Bundled MP3s | `App/Resources/Music/` |
| Genre icons | `App/Assets.xcassets/Genre*.imageset/` |
| Resident portraits | `App/Assets.xcassets/Portrait{Woman,Man}01–06.imageset/`, `Core/ResidentPortraitCatalog.swift` |
| Demo recording | `tools/demo/` (scripts + README), `DemoUITests/` (scripted walkthroughs), `Core/DemoLaunchOptions.swift` |
| API client + auth | `Core/API/APIConfig.swift` (`-NoteStalgiaAPIBaseURL`), `APIClient.swift`, `AuthSession.swift` (+ `PrincipalCache`, Keychain), `AuthFlow.swift`, `Principal.swift`, `Models+Wire.swift` |
| Organisation onboarding (request → verify → activate → set-up; invites; CSV import) | `Core/Onboarding/` (`OnboardingStore`, `OnboardingFlow`, `OnboardingClient`, `OnboardingModels`, `ResidentCSVImport`), `Screens/OnboardingScreens.swift`, phases `.orgRequest` / `.orgCode` / `.orgSetup`; Worker `routes/onboarding.ts` + `routes/org.ts`, `migrations/0004_onboarding.sql`, `scripts/org-requests.ts`; plan `docs/ONBOARDING_PLAN.md` |
| Sync (offline-first) | `Core/Sync/SyncEngine.swift` (observers, outbox, pull/push, portraits, signals), `LocalCache.swift`, `SyncPage.swift`; readiness `CareDataStore.isSeeded` |
| Catalogue, search, discovery online | `Core/API/TrackRef.swift` (`ResidentTrackRef`, wire DTOs), `MusicCatalogClient.swift` (+ `ITunesDirectSearch.swift`, the device-side fallback when Apple blocks the Worker), `RecommendationStore.swift` (per-genre queues on disk), `DiscoveryFlow.swift` (glyph queues, plan / results / signals), `Screens/SongSearchSheet.swift`, `Core/TrackArtworkView.swift` (Apple cover art thumbnails; the orb / backdrop take the sleeve through `DiscoveryEraListeningOrb.planSnippet` and `ResidentPlaylistBackdropView.artworkURL`) |
| Backend (sibling repo) | `../NoteStalgia-Backend/worker/src/{routes,auth,catalogue,model}` (`model/similarity.ts` = songs like the ones they love; `model/group.ts` + `routes/group.ts` = a playlist ranked for a whole room; `routes/music.ts` `artists/expand`), `migrations/`, `seed/`, `contracts/openapi.yaml`, `scripts/deploy.sh` |

## Android parity checklist

When you change any of the following on iOS, update Android in the same effort (or leave a clear TODO in the PR/handoff):

- Track titles / genre mapping  
- Genre artwork  
- Discovery snippet mood order  
- Demo credentials / mock roster semantics  
- Sun/cloud comfort semantics  
- Household (Care at home) account rules, registration fields and the per-resident insights layout  
- Group activity planner heuristics (need score, activity matching, staff suggestions) and the group-comfort flag  
- Input rules (`InputRules.swift` / `validate.ts`: names, addresses, postcodes, phones, emails, beds, CQC ids, required fields) for any form Android gains  
- API client, sync protocol, `ResidentTrackRef` / preview playback, song search, online discovery (Android has none of these yet — see `docs/HANDOFF_PLAN.md`)  

Android root: `../NoteStalgia-Android`.

## Done means

- Builds clean on simulator for the change you made  
- Decisions that affect product behaviour are reflected in `README.md` (catalogue table) and/or `docs/HANDOFF_PLAN.md`  
- No drive-by refactors outside the requested scope  
