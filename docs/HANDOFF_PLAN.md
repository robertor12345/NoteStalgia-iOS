# Handoff plan — Claude / next agent pickup

**Status:** iOS care-path POC is feature-rich and runnable. Uncommitted local work (as of handoff)
includes designer genre icons + 1:1 track↔genre remapping — **commit that before starting new
features** if still dirty.

**Sibling:** `../NoteStalgia-Android` — keep catalogs in sync.

---

## 0. First 15 minutes (setup)

```bash
cd NoteStalgia-iOS
git status
xcodegen generate
xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
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
      same cut as v4): narration re-rendered with `edge-tts` (`en-GB-RyanNeural`, network; `DEMO_VOICE=Daniel`
      keeps the offline macOS voice), every cue burned in as a subtitle strip under a slightly smaller device
      (`build.py` `subtitle_strip`, compositor overlays with `x`/`y`), and an `.srt` sidecar for players and
      YouTube. This ffmpeg build has no libass/drawtext, hence the compositor route.
- [x] **Walkthrough v4 recorded — narrated, chronological** (`NoteStalgia-Walkthrough-v4.mp4`, ~11¾ min,
      gitignored; keep v1–v3 too): one afternoon end to end in three continuous story takes
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
- [x] **Walkthrough v3 recorded** (`NoteStalgia-Walkthrough-v3.mp4`, 4 min 55 s, gitignored like v1/v2 — do not
      delete the earlier two): four scripted takes (`tools/demo/walkthrough.sh` resident / discovery / group / admin
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

## 2. Medium-term POC work (still no backend)

- [ ] Richer per-genre playlists (2–3 stems each) once more licensed/AI stems exist — keep
      **primary** stem stable for each glyph.
- [ ] Group session playlist compiler should prefer catalog titles that exist as bundled audio
      (avoid silent fallback to ambient loop).
- [ ] Trim / archive unused Mellority-named assets if any remain (`MellorityLogo.imageset`).
- [ ] Optional: short “How to run in Xcode” one-pager for free sharing (no TestFlight).

---

## 3. Production path (do not start unless asked)

Follow `docs/IMPLEMENTATION_PLAN.md`. Do **not** scaffold AWS/Mongo inside this POC repo without an
explicit request. When production starts:

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
| Welcome gate | `RosterWarmUp` awaits `careData.$carePatients` — anything that stops `seedCareDataOffMain` publishing on the main actor makes the welcome dwell the full 6 s cap |

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
