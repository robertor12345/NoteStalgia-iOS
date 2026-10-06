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

Signing: Automatic. Local Xcode may set `DEVELOPMENT_TEAM` (e.g. `23CGZDXP4Q`); `project.yml` leaves it blank for regenerating machines.

---

## Product flow (POC)

```
Launch / splash
  → Supervisor email + 6-digit PIN
  → (multi-home) home picker
  → Welcome
  → Curated roster (pin / recent / due / wing / search / browse-all)
       ├─ Resident detail → session prep → resident calm surface → post-session sentiment → insight
       ├─ Discovery (new resident) → age + nationality → traffic-light clips → profile → calm surface
       ├─ Group mode → compiled playlist → group feedback
       └─ (home admin) Insights dashboard
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
AGENTS.md      Conventions for coding agents (Claude / Cursor)
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
| Visual identity | Cosmic / nebula orb, cream + gold staff chrome, pastel accents (not traffic-light primaries on resident music surface) |
| Primary device | **iPad**; iPhone supported with `BrandLayout` compact scaling |
| Auth UX | Work email + **6-digit PIN** (not Face ID for staff in this build) |

### Care / tenancy model

| Decision | Choice |
|---|---|
| Hierarchy | Organisation → Care home (+ wings) → Supervisor accounts |
| Roles | `supervisor` / `homeLead` / `orgAdmin` (`isHomeAdmin` gates dashboard) |
| Roster | Curated: pinned, recent, due, wing filter, search, browse-all (`CareRosterEngine`) |
| Nationality | Soft bias only — discovery order + genre candidates (`ResidentNationalityMusicBias`); **not** hard filtering |
| Face ID linking | Present in code; **drop for v1 production** |
| IoT / Hue / HomeKit | Stubbed; **out of scope for v1** |

### Resident calm surface

| Decision | Choice |
|---|---|
| Genre UI | Floating **designer circular artwork** glyphs (not SF Symbols) — assets `GenreJazz` … `GenreSoul` |
| Comfort dock | Always-on **sun (like)** / **cloud (skip + remove from session queue)** while playing |
| Media | Mood-matched stills (`MusicVisualMood` + Wikimedia scene URLs); orb morphs circle → full-page on play |
| Audio | Bundled MP3s in `App/Resources/Music` via `BundledAudio` / `ResidentPlaybackTrackCatalog` |
| Telemetry | Likes, skips, rage bursts, dwell → `ResidentSurfaceSessionMetrics` → session record + preference boosts |
| Equalizer | Live PCM reactive bars around hero glyph (`MusicReactiveAnalyzer`) |

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

### Staff UI (iPhone + iPad)

| Decision | Choice |
|---|---|
| Top chrome | Back + Log out flush under status bar via `safeAreaInset` — **do not** double-apply `safeTop` in `OrbNavigationStyle` |
| Scroll dissolve | Vertical edge fade on staff scroll screens; **horizontal** fade on wing chips + admin trend strip |
| Suggested liked songs | Supervisor-seeded titles boost playlist scoring (+ dwell / likes) |

### Performance

| Decision | Choice |
|---|---|
| Ambient sparkles | ~450 particles; cull off-screen; tiered glow; pause on scroll / keyboard / reduce-motion |
| Orb / glyphs | Budgeted FPS (`OrbRenderBudget`); pause expensive loops while scrolling |
| Scene stills | `SceneImageCache` (memory + disk) + prefetch |
| Scroll pause | Refcounted `AmbientInteractionPause` |

### Distribution / sharing

| Decision | Choice |
|---|---|
| Free share | GitHub clone + Xcode Simulator, or screen recording |
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

---

## Related repos

- **iOS (this):** feature-complete care path POC  
- **Android:** `../NoteStalgia-Android` — core-path parity; group sessions deferred; keep catalogs in sync when changing tracks/genres/icons  
