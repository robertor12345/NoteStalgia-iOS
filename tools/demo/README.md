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

The story is one chronological afternoon in three continuous takes:

| Scenario | What it shows |
|---|---|
| `testStoryPartA_SignInToSummary` | title → typed sign-in (`max@…`, PIN) → welcome → roster (scroll, wing filter, Cards/Compact) → Irene's profile scrolled card by card → calm surface (play, sun, switch, cloud) → staff hold → observation (tags, ratings, note) → session summary scrolled → copy family update → Done |
| `testStoryPartB_DiscoveryAndGroup` | roster → new-resident discovery (age → seven clips with reactions) → first calm surface → staff hold → name + save → roster → group mode (next, pick a track) → end → check-in → roster |
| `testStoryPartC_Admin` | typed sign-in as `alex@…` → home picker → admin welcome → dashboard (expand a trend, scroll) |

Every step calls `mark("<label>")`, which appends to `/tmp/notestalgia-demo-markers.log`
(`TEST_RUNNER_DEMO_MARKERS_FILE`); the labels are the keys of `pipeline/narration.py`, which holds
the on-screen caption and the spoken line for each step. Holds are sized so each screen stays up at
least as long as its narration. `DEMO_PACE=1.3 tools/demo/walkthrough.sh …` stretches every pause by
1.3×. `DEMO_CONFIG=Debug` builds faster when you only want to check the script. xcodebuild usually
shuts the simulator down afterwards — `walkthrough.sh` boots it again before the next scenario.

## Full walkthrough video (narrated + subtitled)

```bash
for s in testStoryPartA_SignInToSummary:a_story testStoryPartB_DiscoveryAndGroup:b_story testStoryPartC_Admin:c_story; do
  tools/demo/walkthrough.sh "${s%%:*}" "${s##*:}"
done
python3 tools/demo/pipeline/build_story.py         # → NoteStalgia-Walkthrough-v5.mp4 + .srt (~11¾ min)
```

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
| Profile | `profile.openSurface`, `profile.age` (stepper), `nationality.menu`, `profile.addSong`, `profile.song.remove.<Title>`, `profile.startDiscovery`, `profile.prepSession` |
| Session prep | `prep.toggle.<Title>`, `prep.brightness`, `prep.minutes`, `prep.continue` |
| Entry / capture / mood | `entry.<Tile title>`, `capture.chooseLibrary`, `capture.takePicture`, `capture.startSession`, `capture.chooseAnother`, `capture.takeAgain`, `mood.<Mood>`, `mood.begin` |
| Staff immersive | `immersive.mute`, `immersive.settings`, `immersive.lights`, `immersive.share`, `immersive.end`, `immersive.returnToPlaylists`; "How that felt": `insight.note`, `insight.skip`, `insight.returnToPlaylists`; feedback: `feedback.outcome.<Title>`, `feedback.tuning.<Title>`, `feedback.note`, `feedback.save`, `feedback.skip` |
| Calm surface | `surface.glyph.<genre>` (jazz, classical, pop, rock, gospel, country, soul), `surface.like`, `surface.skip`, `surface.staffKey` (press-and-hold) |
| Observation | `observation.chip.<Label>`, `observation.residentLed`, `observation.distress`, `rating.1 … rating.10`, `observation.note`, `observation.save`, `observation.skip` |
| Session summary | `summary.shareKind` (Handover / Family / Care plan), `summary.copy`, `summary.done`, `summary.back` |
| Discovery | `discovery.age`, `nationality.menu`, `discovery.begin`, `discovery.face.pleasant` / `.neutral` / `.unpleasant` |
| New resident | `newResident.choosePhoto`, `newResident.takePhoto`, `newResident.name`, `newResident.age`, `nationality.menu`, `newResident.save`; Back is "Discard" → confirmation dialog |
| Group | `group.previous`, `group.playPause`, `group.next`, `group.track.<Title>`, `group.end`; check-in `rating.<n>`, `group.note`, `group.save`, `group.skip` |
| Admin | `admin.trend.<series id>` (sessions / calm / wellbeing), `admin.switchHome`, `admin.open` |

## Other helpers

- `shot.sh <name>` — screenshot (+1000px preview) into `.demo-work/shots/`.
- `profile.sh <label> [seconds]` — `sample` the running app and summarise main-thread hot spots (`anal.py`).
- `mark.sh "<label>"` — timestamped marker for hand-driven takes (same `epoch|label` format as the scripted markers).

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
was too slow). Keep ≥3 GB disk free — a raw take is 0.5–1.5 GB until `walkthrough.sh` compacts it. Record from a Release build.
