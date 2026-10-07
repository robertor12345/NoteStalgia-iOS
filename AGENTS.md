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
- **Top staff chrome:** never re-introduce root `safeTop + 8` padding for screens that use `CenteredScrollScreen` / `safeAreaInset` nav.
- **Face ID / IoT:** do not expand; production plan drops them for v1.
- **Do not commit secrets** (`.env`, keystores, App Store Connect API keys).

## Hard rules (engineering)

- Project is **XcodeGen**: edit `project.yml`, then `xcodegen generate`. Do not hand-edit `.pbxproj` unless unavoidable.
- Deployment target **iOS 17**. Prefer APIs available on 17; gate iOS 18+ extras (`onScrollGeometryChange`, etc.).
- Keep `SessionPOCState` as a thin coordinator — put new domain state in the appropriate `*Store`.
- Avoid per-frame `@State` updates on scroll/audio paths; follow `AmbientInteractionPause` / `OrbRenderBudget` patterns.
- Match existing visual language (`BrandTheme`, `BrandLayout`, `CalmMotion`) — no generic purple/Inter redesigns.
- After substantive Swift changes:  
  `xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Only `git commit` / `git push` when the user asks.

## Where things live

| Concern | Primary files |
|---|---|
| Flow / phases | `Flow/FlowRootView.swift`, `SessionPOCState` |
| Resident glyphs + play | `Screens/ResidentExperienceScreens.swift`, `ResidentPlaylistVisuals.swift`, `ResidentMusicModel.swift` |
| Track catalog | `ResidentPlaylistVisuals.swift` (`ResidentPlaybackTrackCatalog`) |
| Discovery audio order | `DiscoveryModels.swift`, `DiscoveryEraMedia.swift` |
| Mood / scene visuals | `MusicVisualMood.swift`, `SceneImageCache.swift` |
| Staff roster / chrome | `Screens/CareStaffScreens.swift`, `CenteredScrollScreen.swift`, `ScrollContentEdgeFade.swift` |
| Metrics → prefs | `ResidentSurfaceSessionMetrics.swift`, `SessionPOCState.residentPlaylistTitles` |
| Bundled MP3s | `App/Resources/Music/` |
| Genre icons | `App/Assets.xcassets/Genre*.imageset/` |
| Resident portraits | `App/Assets.xcassets/Portrait{Woman,Man}01–06.imageset/`, `Core/ResidentPortraitCatalog.swift` |
| Demo recording | `tools/demo/` (scripts + README), `DemoUITests/` (scripted walkthroughs), `Core/DemoLaunchOptions.swift` |

## Android parity checklist

When you change any of the following on iOS, update Android in the same effort (or leave a clear TODO in the PR/handoff):

- Track titles / genre mapping  
- Genre artwork  
- Discovery snippet mood order  
- Demo credentials / mock roster semantics  
- Sun/cloud comfort semantics  

Android root: `../NoteStalgia-Android`.

## Done means

- Builds clean on simulator for the change you made  
- Decisions that affect product behaviour are reflected in `README.md` (catalogue table) and/or `docs/HANDOFF_PLAN.md`  
- No drive-by refactors outside the requested scope  
