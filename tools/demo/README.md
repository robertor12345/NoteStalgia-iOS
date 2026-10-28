# Demo recording toolkit

Everything needed to record the walkthrough videos without hand-driving the simulator. The
intermediates (takes, PNG cards, profiles) go to `.demo-work/` (gitignored); set `DEMO_WORKDIR`
to put them elsewhere.

## One-command walkthroughs

```bash
xcrun simctl boot "iPad Air 11 Demo"          # or any simulator; the first booted one is used
tools/demo/walkthrough.sh list                # scenario names
tools/demo/walkthrough.sh testStoryPartA_SignInToSummary a_story
```

That builds the app (Release) plus `DemoUITests`, starts `record.sh`, runs the one scripted
scenario, stops the recording and leaves `.demo-work/takes/a_story.mp4` (trimmed of the xcodebuild
lead-in and re-encoded at half resolution so a five-minute take is ~250 MB) plus three sidecars:
`.log.jsonl` (the app's phase / music / chime log), `.markers.log` (`epoch|label` for every scripted
step) and `.sync.json` (recording start + trim).

The story is one chronological afternoon in four continuous takes (three in the care home, one at home):

| Scenario | What it shows |
|---|---|
| `testStoryPartA_SignInToSummary` | title → typed sign-in (`max@…`, PIN) → welcome → roster (scroll, wing filter, Cards/Compact) → Irene's profile scrolled card by card → calm surface (play, sun, switch, cloud) → staff hold → observation (tags, ratings, note) → session summary scrolled → copy family update → Done |
| `testStoryPartB_DiscoveryAndGroup` | roster → new-resident discovery (age → seven clips with reactions) → first calm surface → staff hold → name + save → roster → group mode (next, pick a track) → end → check-in → roster |
| `testStoryPartC_Admin` | typed sign-in as `alex@…` → home picker → admin welcome → dashboard (expand a trend, scroll) |
| `testStoryPartD_Household` | Care at home: "Create an account" from sign-in → sign-up (Priya, private carer, PIN) → register Arun S. (no discovery) → household home → calm surface session → observation → summary (Family write-up) → first insights → log out → sign in as `claire@example.com` → Harold's insights scrolled. Launches with `-NoteStalgiaDemoResetHouseholds YES` so the same email works every take |
| `testStoryPartE_LiveBackend` | **v7** · live backend: typed sign-in checked by the server → "Syncing" → synced roster → Irene's profile → Group activities card (In company → Small groups) → Find a song they love ("vera lynn": sleeves, preview, Add) → the chip + real-time re-ranking → calm surface (new Pop glyph, We'll Meet Again with its sleeve, swipe to more Vera Lynn, sun) → staff hold → observation skipped → summary → Done. Every tap is followed by a hold of ≥ 3 s |
| `testStoryPartF_OnlineDiscovery` | **v7** · online discovery for Irene: seven real songs with their sleeves in the orb and the staff caption → faces → playlists on her calm surface → first playlist plays → staff hold → summary |
| `testStoryPartH_GroupSession` | **v7** · Group activities → planner (suggestions from shared tastes, reasons) → tap a suggestion → the residents and their reasoning → Start → a playlist ranked for the whole room by the server (sleeve, who each song is for, why) → next → the full list → End → check-in → roster |
| `testStoryPartG_GroupProgramme` | **v7** · `alex@…` → Maple Lodge → dashboard from synced data → the Group programme card |
| `testGroupPlannerWalkthrough` | Group activities: roster → planner → pick a suggested activity → toggle a resident → start → session (activity line) → end → check-in → roster → Irene K.'s profile (Group activities card: participation line, set "In company" to Small groups) → log out → `alex@` → Maple Lodge dashboard (Group programme card) |
| `testHouseholdWalkthrough` | Care at home: create an account → register a resident (no discovery) → home → empty insights → profile → calm surface session → observation → summary → insights with data → relaunch + sign in (persistence) → demo household `claire@example.com` → Harold's insights |

Every step calls `mark("<label>")`, which appends to `/tmp/notestalgia-demo-markers.log`
(`TEST_RUNNER_DEMO_MARKERS_FILE`); the labels are the keys of `pipeline/narration.py`, which holds
the on-screen caption and the spoken line for each step. Holds are sized so each screen stays up at
least as long as its narration. `DEMO_PACE=1.3 tools/demo/walkthrough.sh …` stretches every pause by
1.3×. `DEMO_CONFIG=Debug` builds faster when you only want to check the script. xcodebuild usually
shuts the simulator down afterwards — `walkthrough.sh` boots it again before the next scenario.

## Full walkthrough video (narrated + subtitled)

```bash
for s in testStoryPartA_SignInToSummary:a_story testStoryPartB_DiscoveryAndGroup:b_story \
         testStoryPartC_Admin:c_story testStoryPartD_Household:d_story; do
  tools/demo/walkthrough.sh "${s%%:*}" "${s##*:}"
done
python3 tools/demo/pipeline/build_story.py         # → NoteStalgia-Walkthrough-v6.mp4 + .srt (~16 min, nine flows)
```

### v7 — what's new since v6 (live backend)

```bash
tools/demo/reset-backend.sh                   # model + ad-hoc songs cleared, demo organisation removed, demo residents re-seeded
for s in testStoryPartE_LiveBackend:e_live testStoryPartF_OnlineDiscovery:f_discovery testStoryPartH_GroupSession:h_group testStoryPartG_GroupProgramme:g_admin testStoryPartI_Onboarding:i_onboarding; do
  DEMO_AUDIO_DEVICE="" TEST_RUNNER_API_BASE_URL=https://notestalgia-api.fitraclesub.workers.dev \
    tools/demo/walkthrough.sh "${s%%:*}" "${s##*:}"
done
python3 tools/demo/pipeline/build_v7.py       # → NoteStalgia-Walkthrough-v7.mp4 + .srt (ten flows)
```

`-NoteStalgiaDemoSignInPIN 135790` pairs with `-NoteStalgiaDemoSignIn` for an account that is not a seeded demo one
(an organisation created through onboarding). `testOnboardingJoinSmoke` is a one-minute check of Part I's tail
(sign in as the org admin → roster → log out → "I have an invite or activation code") for when the long take is
not needed.

Part I (`i_onboarding`, flow 10 "A new organisation") walks the organisation onboarding end to end: request a
workspace → verification code → activation → the paged set-up (organisation: details, address with its
required-field message, domains, defaults; a home over three pages; an invite over two with its INV- code; the
sample residents import; this iPad with its required label; the checklist and audit trail) → the new home's
dashboard and roster → the invited
supervisor joins with the code. It needs a Worker that exposes codes and approves at once (`EXPOSE_CODES=1`,
`AUTO_APPROVE=1` on the demo deployment) and `reset-backend.sh` before every take: the reset removes every
organisation created through self-service onboarding, so "Willowbank Care" / `dana@willowbank-care.co.uk` can be
used again. Narration keys `v7_onb_*`.

`build_v7.py` is `build_story.py` with its own flow list, cards and take names (narration keys `v7_*`,
`intro7`, `outro7`). The takes are recorded **video-only** (`DEMO_AUDIO_DEVICE=""`): the app logs `title` +
`url` with every `music.start`, so streamed Apple previews are fetched once into the wav cache and cut in
exactly where they played, alongside the bundled stems and synthesised chimes — no BlackHole routing and no
stray system sounds. Run `reset-backend.sh` before every take of Part E so Irene has no pick and no taste yet;
Parts F and G can follow E without a reset.

`build_story.py` reads each take's markers: a chapter card is cut in where a marker's flow changes, the
caption runs from one marker to the next, and the narration line is queued so lines never overlap, with
the music ducked underneath. The voice is a Microsoft neural voice through `edge-tts` (`pip3 install --user
edge-tts`; needs network; `DEMO_VOICE`, default `en-GB-RyanNeural` — `en-GB-SoniaNeural` is the female
alternative; `DEMO_EDGE_RATE`, default `-3%`). Any plain macOS voice name (`DEMO_VOICE=Daniel`) falls back to
the offline `say` synthesiser. Lines are cached in `.demo-work/voice/`. Every narration cue is also burned
in as a subtitle strip under the device (sentence timings from the voice engine, long sentences split at
~84 characters) and written to a sidecar `.srt` next to the video. Sync is calibrated from the frames at
every clean phase change and interpolated between them — the simulator recorder loses a second or two
whenever the app is under load, so one offset per take is not enough. The soundtrack is the take's audio
when BlackHole captured it, otherwise rebuilt from the log.
Edit a line in `narration.py` and re-run `build_story.py` (`--reuse-video` re-mixes onto the already rendered
picture in about a minute, but only while captions, cuts and subtitles are unchanged — a changed line changes
its subtitles, so a full render is the norm) — no re-recording needed unless the
hold is now too short. Keep ≥3 GB free: a raw take is 0.5–1.5 GB until `walkthrough.sh` compacts it. Kill stray
`simctl io … recordVideo` processes if a run is interrupted — they keep deleted takes alive on disk.

The v3 scenarios (`build_v3.py`: four short takes, captions from phase events, no voice) are superseded
but the script still runs if the old take names are recorded.

## Audio

`xcrun simctl recordVideo` has no sound. `record.sh` also captures the Mac's **BlackHole 2ch**
loopback device with ffmpeg when it exists and muxes it in on `stop`. Setup once:

1. `brew install ffmpeg && brew install --cask blackhole-2ch`, then reboot.
2. Audio MIDI Setup → `+` → *Create Multi-Output Device* with **BlackHole 2ch** and your speakers;
   select it as the system output while recording. You still hear the take.
3. If chimes land early/late, set `DEMO_AUDIO_OFFSET=0.3` (seconds) when calling `record.sh stop`.

Fallback without BlackHole: launch with `-NoteStalgiaDemoAudioLog YES` (the walkthroughs do) and
rebuild the soundtrack from `Documents/demo-audio-log.jsonl` with `pipeline/mix_v2.py` — it
re-synthesises the chimes and re-cuts the bundled MP3s at the logged times.

## Launch arguments (`Core/DemoLaunchOptions.swift`)

| Argument | Effect |
|---|---|
| `-NoteStalgiaDemoSignIn max@sunrise-care.co.uk` | signs in as that mock account as the title fades (`alex@…` → home picker / admin) |
| `-NoteStalgiaDemoSkipLaunch YES` | title screen lasts only as long as warm-up (~1 s) |
| `-NoteStalgiaDemoJump roster\|profile:<name>\|surface:<name>\|discovery\|group` | after the welcome gate, jump straight to that scene |
| `-NoteStalgiaDemoFreezeGlyphDrift YES` | resident glyphs hold still so taps land |
| `-NoteStalgiaDemoAudioLog YES` | log music / chime / phase events to `Documents/demo-audio-log.jsonl` |
| `-NoteStalgiaDemoResetHouseholds YES` | forget Care at home accounts created on this device (the demo household stays) |
| `-NoteStalgiaDemoFrameLog YES` | log `orb.frames` (display-link fps, hitches, shell draws, nebula canvas ms) every 2 s to the demo log |
| `-NoteStalgiaDemoFreezeOrb YES` | orb and sparkles hold one frame — for pixel comparisons between builds |
| `-NoteStalgiaAPIBaseURL http://localhost:8787` | use the POC backend (`../NoteStalgia-Backend`, `npm run dev` + `npm run seed:local`) instead of the in-memory seed: real sign-in, synced homes, Apple-preview catalogue, online discovery. The client appends `/v1`. Omit it for the recorded demo |
| `-NoteStalgiaExportSeed YES` | one-off: write the deterministic mock roster, history, group history and demo household to `Documents/seed.json` (copied to `../NoteStalgia-Backend/seed/demo.json`) |

XCUITests pick the backend up from the environment: `TEST_RUNNER_API_BASE_URL=http://localhost:8787 xcodebuild test …`
passes `-NoteStalgiaAPIBaseURL` to the app (the household walkthrough then registers a unique email per run).

Example — straight to Irene's calm surface with the real title screen:

```bash
xcrun simctl launch --terminate-running-process booted com.notestalgia.ios \
  -NoteStalgiaDemoSignIn max@sunrise-care.co.uk -NoteStalgiaDemoJump surface:Irene
```

## Accessibility identifiers (for XCUITest or manual `simctl`-free driving)

Every interactive control carries one. `<…>` parts are the on-screen text (e.g. `roster.resident.Irene K.`).

| Screen | Identifiers |
|---|---|
| Sign-in | `signin.email`, `signin.pin`, `signin.continue`, `signin.forgotPin`; reset flow `pinReset.email`, `pinReset.code`, `pinReset.primary`, `pinReset.backToSignIn` |
| Signed-in start | `home.oneToOne`, `home.logout`; home picker `homePicker.<Home name>` |
| Chrome | `chrome.back` (also "Skip" / "Discard" variants), `chrome.logout` |
| Roster | `roster.search`, `roster.wing.<Wing>` / `roster.wing.All wings`, `roster.displayMode`, `roster.startDiscovery`, `roster.groupMode`, `roster.browseAll`, `roster.backToToday`, `roster.switchHome`, `roster.resident.<Display Name>`, `roster.pin.<Display Name>` |
| Profile | `profile.openSurface`, `profile.age` (stepper), `nationality.menu`, `profile.groupActivities` (participation line), `profile.groupComfort` (In company segmented: Not set / Enjoys groups / Small groups / One-to-one), `profile.addSong`, `profile.song.remove.<Title>`, `profile.startDiscovery`, `profile.prepSession` |
| Session prep | `prep.toggle.<Title>`, `prep.brightness`, `prep.minutes`, `prep.continue` |
| Entry / capture / mood | `entry.<Tile title>`, `capture.chooseLibrary`, `capture.takePicture`, `capture.startSession`, `capture.chooseAnother`, `capture.takeAgain`, `mood.<Mood>`, `mood.begin` |
| Staff immersive | `immersive.mute`, `immersive.settings`, `immersive.lights`, `immersive.share`, `immersive.end`, `immersive.returnToPlaylists`; "How that felt": `insight.note`, `insight.skip`, `insight.returnToPlaylists`; feedback: `feedback.outcome.<Title>`, `feedback.tuning.<Title>`, `feedback.note`, `feedback.save`, `feedback.skip` |
| Calm surface | `surface.glyph.<genre>` (jazz, classical, pop, rock, gospel, country, soul), `surface.like`, `surface.skip`, `surface.staffKey` (press-and-hold) |
| Observation | `observation.chip.<Label>`, `observation.residentLed`, `observation.distress`, `rating.1 … rating.10`, `observation.note`, `observation.save`, `observation.skip` |
| Session summary | `summary.shareKind` (Handover / Family / Care plan), `summary.copy`, `summary.done`, `summary.back` |
| Discovery | `discovery.age`, `nationality.menu`, `discovery.begin`, `discovery.face.pleasant` / `.neutral` / `.unpleasant` |
| New resident | `newResident.choosePhoto`, `newResident.takePhoto`, `newResident.name`, `newResident.age`, `nationality.menu`, `newResident.save`; Back is "Discard" → confirmation dialog |
| Group | planner `planner.activity.<id>` (e.g. `genre.classical`, `mixed`), `planner.suggestion.<id>` (Add), `planner.resident.<Display Name>`, `planner.clear`, `planner.start`, `planner.startAll`; session `group.activityLine`, `group.previous`, `group.playPause`, `group.next`, `group.track.<Title>`, `group.end`; check-in `rating.<n>`, `group.note`, `group.save`, `group.skip` |
| Admin | `admin.trend.<series id>` (sessions / calm / wellbeing), `admin.groupProgramme` (Group programme card title), `admin.switchHome`, `admin.open` |
| Organisation onboarding (backend only) | sign-in links `signin.requestWorkspace`, `signin.haveCode`; request `onboarding.request.org` / `.name` / `.email` / `.phone` / `.role` / `.homes` (segmented) / `.cqc` / `.notes` / `.consent` / `.submit`, verification `onboarding.code` (hint reads "Demo code: …" on the demo Worker), `onboarding.verify`, `onboarding.activationCode`, `onboarding.activate`; code screen `onboarding.codeEmail`, `onboarding.codeField`, `onboarding.codeName`, `onboarding.codePin`, `onboarding.codeConfirmPin`, `onboarding.terms`, `onboarding.redeem`; set-up `onboarding.section.1 … 6` (stepper circles), `onboarding.back` (previous page, a text button), `onboarding.next` ("Next: <page>"), `onboarding.addHome.start` / `onboarding.addHome` (open / commit the add-a-home journey), `onboarding.homes.skip`, `onboarding.invite.start` / `.startMany` (open the invite journeys), `onboarding.import.discard`, and `<field id>.error` (the message under a field that failed validation, e.g. `onboarding.org.address.error`), `onboarding.done` ("Finish set-up"), `onboarding.error` / `onboarding.notice` (the banner above the bar), `onboarding.keyboardDone`; leaving a step with unsent work raises an alert (Save and continue / Discard / Keep editing); organisation `onboarding.org.*`, `onboarding.domain.*` (`.method` segmented Email code / DNS record, `.new`, `.send`, `.code`, `.verify`, `.checkDns`); homes `onboarding.home.name` / `.cqc` / `.capacity` / `.newWing` / `.addWing` / `.lead` / `.leadEmail` / `.leadName`, `onboarding.addHome`, exports `onboarding.export.residents.<Home>` / `onboarding.export.json.<Home>` / `onboarding.export.share`; team `onboarding.invite.email` / `.name` / `.role` / `.home.<Home>` / `.temporary` / `.send` / `.bulk` / `.sendAll` / `.code` (the INV- tile) / `.resend.<email>` / `.revoke.<email>`, `onboarding.staff.toggle`; residents `onboarding.import.home.<Home>`, `onboarding.import.template`, `onboarding.import.sample`, `onboarding.import.pick`, `onboarding.import.apply`, `onboarding.import.roster`; iPads `onboarding.device.label`, `onboarding.device.register`; ready `onboarding.ready.roster`; admin dashboard / home picker `admin.orgSetup`, `homePicker.orgSetup` |
| Care at home | sign-in link `signin.createHousehold`; sign-up `household.name`, `household.email`, `household.relationship` (Family member / Private carer), `household.pin`, `household.confirmPin`, `household.create`; resident setup `household.residentName`, `household.residentAge`, `nationality.menu`, `household.choosePhoto`, `household.takePhoto`, `household.startDiscovery`, `household.skipDiscovery`; home `household.openSurface`, `household.insights`, `household.profile`, `household.discovery`, `household.register`; insights empty state `household.insightsBack` |

## Other helpers

- `shot.sh <name>` — screenshot (+1000px preview) into `.demo-work/shots/`.
- `profile.sh <label> [seconds]` — `sample` the running app and summarise main-thread hot spots (`anal.py`).
- `mark.sh "<label>"` — timestamped marker for hand-driven takes (same `epoch|label` format as the scripted markers).
- `orbperf.sh <label> [launch args…]` — orb performance probe: launches to sign-in with the frame monitor on and reports host
  CPU (app + `backboardd`), screen-recorder fps, main-thread busy %, and the in-app `orb.frames` log (display-link fps,
  hitches, shell draws/s, nebula canvas ms). Keep the Simulator window visible while measuring — hidden, the
  simulator throttles frame delivery to ~15–20 fps. A/B switches: `-NoteStalgiaPerfCAShadows YES` (Core Animation
  shadows instead of flattened textures), `-NoteStalgiaPerfSyncNebula YES` (noise on the main thread),
  `-NoteStalgiaPerfNoShellShadows YES` (drop the shell's three shadows — measurement only), `-NoteStalgiaDemoFreezeOrb YES`
  (orb + sparkles hold one frame for pixel diffs).

## Legacy compositor pipeline (`pipeline/`)

The v1/v2 walkthroughs were assembled without ffmpeg: `build.py` / `build_v2.py` turn a shot list
into a plan JSON plus PNG caption/chapter cards (Pillow), `render.swift` composites the plan,
`mix_v2.py` rebuilds audio from the demo log. Kept for reference and for the audio-log fallback;
with ffmpeg available, trimming/concatenating/overlaying is a one-liner each:

```bash
ffmpeg -i take.mp4 -ss 12 -to 31 -c copy clip.mp4                              # trim
ffmpeg -i clip.mp4 -i caption.png -filter_complex overlay=0:H-h-80 out.mp4       # caption card
printf "file 'a.mp4'\nfile 'b.mp4'\n" > list.txt && ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4
```

`build_tools.sh` compiles `render.swift` and `fps.swift` (recorded-smoothness meter) into `.demo-work/bin/`.

## Machine notes

8 GB RAM: one simulator at a time; the **iPad Air 11 Demo** device is the smooth one (the iPad Pro 13″
was too slow). Recording works headless (`simctl boot`, no Simulator.app window). Three things about
`simctl io recordVideo` learnt the hard way: it writes its file only when it stops (a take is 0 bytes until
`record.sh stop`, so never judge it by size mid-take); the output path must be **absolute** (the render server
opens the file itself — a relative path fails at once with "SimRenderServer.SimulatorError Code=2"); and when the
disk fills during a take the final write fails and the take comes back as a 0-byte file with "moov atom not
found" — typed takes are the risk, because the keyboard makes the simulator download 1–3 GB of speech assets
(see above). `record.sh` waits for a screenshot to succeed and checks the recorder is still alive a few seconds in. Keep ≥3 GB disk free — a raw take is 0.5–1.5 GB until `walkthrough.sh` compacts it. Record from a Release build.
The simulator's own data folder grows by gigabytes: once the keyboard has been used it downloads Siri / dictation
speech assets (`data/private/var/MobileAsset/…Siri_Understanding`, ≈1–3 GB). `walkthrough.sh` deletes that cache
after every take; if a take still comes back as a 0-byte `raw.mp4` with "moov atom not found", the disk filled —
`xcrun simctl erase <udid>` the device and re-run.
