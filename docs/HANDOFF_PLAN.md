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

- [ ] Audit `DiscoveryFlowPOC.snippetAudioStreamURLs` vs `snippetMoods` vs
      `ResidentPlaybackTrackCatalog` — one table, three consumers, zero drift.
- [ ] Staff “suggested liked songs” menus should only offer `allUniqueTitles` from the catalog
      (already filtered in places — verify after remap).

### P1 — Resident surface QA

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
