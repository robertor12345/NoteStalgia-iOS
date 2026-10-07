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
| Visual identity | Cosmic / nebula orb, dark-card + gold staff chrome, pastel accents (not traffic-light primaries on resident music surface) |
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
| Comfort dock | Always-on **sun (like)** / **cloud (skip + remove from session queue)** while playing |
| Staff return | Corner button is **press-and-hold (0.8 s)** with a filling ring; a quick tap only shows "Staff: press and hold" so residents can't end their own session |
| Media | Mood-matched stills (`MusicVisualMood` + Wikimedia scene URLs); orb morphs circle → full-page on play — full-page covers the **whole screen** incl. status bar (sized from `flowSafeAreaInsets`) |
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
Discovery auditions **all 7 stems** (one snippet per genre: Pop, Rock, Classical, Jazz, Gospel,
Soul, Country) before age/nationality reordering. *Android `calibrationMoods` not yet aligned.*

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
| Screen-tap ripple | A short tap anywhere (staff **and** resident surface) blooms a cyan/pink glow ring at the finger (`TouchRipple.swift`). Observed by a window-level recogniser that never claims, cancels or delays touches; drags/scrolls and long presses don't ripple; off under Reduce Motion |
| Post-session summary | Supervisor sees **Session summary**: at-a-glance (trend vs usual, time with music, genres, liked · skipped, context chips) → carer ratings as 10-segment bars (≤4 in soft salmon) + note → what they responded to (genre artwork chips, sun / cloud / longest listening) → one highlighted next step → **one** write-up at a time (Handover · Family · Care plan) with a single Copy button. Copied texts are unchanged; handover shows as labelled sections with the narrative collapsed |

### Performance

| Decision | Choice |
|---|---|
| Ambient sparkles | ~450 particles; cull off-screen; tiered glow; pause on scroll / keyboard / reduce-motion |
| Orb / glyphs | Budgeted FPS (`OrbRenderBudget`); pause expensive loops while scrolling |
| Scene stills | `SceneImageCache` (memory + disk) + prefetch |
| Scroll pause | Refcounted `AmbientInteractionPause` |
| Orb glow sprites | Outer halo + inner glow are scale-invariant blurred gradients → rendered once (`OrbGlowSprites`) and drawn as images; exterior wisps flattened with `drawingGroup`; empty ripple-ring Canvas removed. Pixel diff vs live: max 8/255 |
| Full-page cover pause | While resident playlist media is fully expanded **and** decoded, sparkles + orb shell pause (`AmbientInteractionPause.beginFullPageCover`) — invisible behind the media; resumes as it collapses. Orb visuals themselves are never simplified for performance. The staff immersive screen (opaque video / poster / fallback) holds the same cover |
| Icon orbs | Self-driven small orbs (roster cards, mood orbs, picker labels, nav buttons; < 96 pt) run at **20 fps** (`OrbRenderBudget.iconFramesPerSecond`; sub-pixel drift) and **freeze** while the keyboard is up, a staff list scrolls or the app is backgrounded (`flowAmbientPaused` environment) |
| Motion as transforms | Resident glyph buttons (`ResidentGlyphButton`, `Equatable`) and mood orbs are built once; per-tick drift is applied as position/rotation/scale/offset transforms in the original order. Discovery orb no longer re-renders at audio-bus rate |
| Equalizer redraws | Live-only radial bars redraw when `MusicReactiveBus` publishes (≤48/s playing, 0 idle) rather than 60×/s; bar trig precomputed |
| Cheap effects | Tap ripple pre-rendered as a sprite (scale/opacity only); `CalmCircularLoader` capped at 60 fps with rotation-invariant shadows; chime engine pauses after 20 s idle; `DemoAudioLog` builds nothing when disabled |

### Distribution / sharing

| Decision | Choice |
|---|---|
| Free share | GitHub clone + Xcode Simulator, or screen recording |
| Demo recording | `tools/demo/walkthrough.sh <scenario>` records a scripted walkthrough (`DemoUITests`) on the booted simulator with real audio via ffmpeg + BlackHole; demo-only launch arguments (`DemoLaunchOptions`: auto sign-in, skip title, jump to scene, freeze glyph drift) and `accessibilityIdentifier`s on the main controls make it deterministic. The narrated walkthrough (v4) is three chronological story takes whose scripted steps write timestamped markers; `pipeline/build_story.py` turns the markers into chapter cuts, captions, a neural voice-over (`pipeline/narration.py`, edge-tts with a macOS `say` fallback) and burned-in subtitles plus an `.srt` sidecar. See `tools/demo/README.md` |
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
