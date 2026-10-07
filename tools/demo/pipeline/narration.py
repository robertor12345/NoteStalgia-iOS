"""Narration + captions for the story walkthrough, keyed by the markers the UI tests write.

`speak(key)` renders a line into a 44.1 kHz stereo WAV under .demo-work/voice/ (cached by voice + text
hash) with a Microsoft neural voice through `edge-tts` (DEMO_VOICE=en-GB-RyanNeural by default; needs
network — pip3 install --user edge-tts) or, for any `say` voice name such as DEMO_VOICE=Daniel, with the
offline macOS synthesiser. `line_cues(key)` gives the subtitle cues for that line (sentence timings from
edge-tts, long sentences split to ≤ SUB_MAX_CHARS). `caption` is the on-screen text (shorter than the
spoken line). `chapter` maps a marker to the walkthrough flow index.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORK = os.environ.get("DEMO_WORKDIR", os.path.join(REPO, ".demo-work"))
VOICE_DIR = os.path.join(WORK, "voice")
VOICE = os.environ.get("DEMO_VOICE", "en-GB-RyanNeural")   # "…Neural" → edge-tts, anything else → `say`
EDGE = "Neural" in VOICE
RATE = int(os.environ.get("DEMO_VOICE_RATE", "168"))        # `say` words per minute (Daniel's default ~180)
EDGE_RATE = os.environ.get("DEMO_EDGE_RATE", "-3%")          # edge-tts rate offset
SUB_MAX_CHARS = 84                                            # longest subtitle cue (wraps to two lines)
SR = 44100

# marker → (flow index 0–7, caption, spoken line)
SCRIPT = {
    "open": (0,
        "NoteStalgia opens on its signature orb — breathing slowly, three seconds in, three seconds out.",
        "This is NoteStalgia. It opens on its signature orb, breathing slowly: three seconds in, three seconds out."),
    "signin": (0,
        "Care staff sign in with their work email and a six-digit PIN — quick on a busy floor, nothing long to remember.",
        "Care staff sign in with their work email and a six digit PIN. Quick on a busy floor, and nothing long to remember."),
    "welcome": (0,
        "A calm welcome while the roster, resident portraits and the day's data are made ready.",
        "A calm welcome while the roster and portraits are made ready."),
    "roster": (1,
        "Today's roster: pinned, recently seen and 'due a visit' residents first, under a home-wide wellbeing summary. Every tap glows and chimes softly.",
        "This is today's roster for Maple Lodge. Residents who are pinned, recently seen, or due a visit come first, "
        "under a summary of carer observations across the home. Every tap glows and chimes softly, so staff know a touch has landed."),
    "roster_scroll": (1,
        "Each card shows the room, the wing, when the resident was last visited and how settled they were.",
        "Scrolling down, each card shows where the resident is, when they were last visited, and how at ease they were. "
        "Their portrait is right there, so a new member of staff can recognise them."),
    "wing": (1,
        "Tap a wing and the whole roster focuses on it — the count updates and every section filters to that wing.",
        "Tap a wing, and the whole roster focuses on it. The count updates and every section filters to just that wing. "
        "Tap All wings to see everyone."),
    "compact": (1,
        "Cards or a compact list — the same roster, denser when a carer knows the names.",
        "Carers can switch between cards and a compact list. It's the same roster, just denser for staff who already know the names."),
    "profile": (2,
        "A resident's profile opens with the one thing a carer needs most — the button that starts their calm session — then their recent carer observations.",
        "Opening Irene's profile. The first thing on screen is the one thing a carer needs most: the button that starts "
        "her calm session. Below it, the rolling carer observations from her recent sessions."),
    "profile_scroll1": (2,
        "Her playlists by genre — these become the floating artwork on her calm surface — and songs family or staff know she loves.",
        "Further down are her playlists, grouped by genre. These become the floating artwork on her calm surface. "
        "Below them, the songs that family or staff know she loves."),
    "profile_scroll2": (2,
        "Age and nationality shape the listening discovery; a discovery pass can be re-run at any time.",
        "Her listening profile: approximate age and nationality, which shape the order of the listening discovery. "
        "And a discovery pass can be run again at any time, if her tastes seem to be changing."),
    "profile_scroll3": (2,
        "Comfort notes — light, scent, touch — and every previous session, so any carer can pick up where the last one left off.",
        "Then her comfort notes: how she likes the light, which scents are familiar, and how she feels about touch. "
        "And every previous session, with its outcome, so any carer can pick up exactly where the last one left off."),
    "profile_top": (2,
        "Back to the top — time to hand the iPad to Irene.",
        "Back to the top. It's time to hand the iPad to Irene."),
    "handoff": (2,
        "The carer opens the calm surface and hands over the iPad.",
        "The carer opens the calm surface and hands over the iPad."),
    "surface": (3,
        "The resident's own view: no words — just their music as floating artwork around the orb. A glowing ripple answers every touch.",
        "This is Irene's own view. There are no words to read — just her music, as floating artwork drifting around the orb. "
        "A glowing ripple answers every touch, wherever it lands, so nothing she does feels ignored."),
    "play": (3,
        "One tap plays that genre. The orb blooms into full-screen, mood-matched imagery and the ring pulses with the live music.",
        "One tap on a glyph plays that genre. The orb blooms into full screen imagery matched to the mood of the music, "
        "and the ring around the artwork pulses with the live sound."),
    "sun": (3,
        "Sun means “I like this”. It's remembered, so the song comes round sooner next time.",
        "The sun means: I like this. It's remembered, so this song comes round sooner next time — and it shows up in the carer's notes."),
    "switch": (3,
        "Tapping another genre folds the imagery back into the orb and re-blooms with the new music.",
        "Tapping another genre gently folds the imagery back into the orb, and it blooms again with the new music."),
    "cloud": (3,
        "Cloud means “not for me”. The song is skipped and taken out of today's session — there are no wrong answers.",
        "The cloud means: not for me. The song is skipped and taken out of today's session. There are no wrong answers here."),
    "staffkey": (4,
        "To take the iPad back, staff press and hold the corner key. A resident's stray tap only shows a gentle hint.",
        "When it's time, staff press and hold the corner key to take the iPad back. A resident's accidental tap only shows a gentle hint."),
    "captured": (4,
        "Everything the resident did is already captured: time with music, genres explored, likes, skips and listening time.",
        "Everything Irene did is already captured: her time with the music, the genres she explored, what she liked, what she skipped, "
        "and how long she listened to each song. The carer doesn't have to remember any of it."),
    "tags": (4,
        "One-tap context tags for the nursing handover — time of day, how they were beforehand, the environment.",
        "One-tap context tags for the nursing handover: the time of day, how she was beforehand, and the environment in the room."),
    "ratings": (4,
        "Four quick 1–10 carer observations: mood, alertness, emotional presentation and orientation.",
        "Then four quick observations on a one to ten scale: mood, alertness, emotional presentation and orientation. "
        "Each answer moves straight on to the next."),
    "note": (4,
        "An optional note in the carer's own words.",
        "And an optional note, in the carer's own words."),
    "save": (4,
        "Saving the observation.",
        "Saving the observation."),
    "insight": (4,
        "The session summary — at a glance: trend against their usual, time with music, what they responded to.",
        "NoteStalgia drafts the session summary. At a glance: how Irene's wellbeing compares with her usual, how long she "
        "spent with the music, which genres she played, and what she liked or moved on from."),
    "insight_scroll1": (4,
        "Carer ratings as simple bars, the note, and what she responded to — with the genre artwork.",
        "Scrolling down: the carer's ratings as simple bars. The note. "
        "And what she responded to, shown with the same genre artwork she saw."),
    "insight_scroll2": (4,
        "One suggested next step for the care plan, then the write-ups: handover, family update or care plan entry — one at a time.",
        "Then one suggested next step for the care plan. And the write-ups: a nursing handover, a family update, or a care plan entry — "
        "shown one at a time so the screen never overwhelms."),
    "copy": (4,
        "Each write-up is one tap to copy into the home's own systems.",
        "Each write-up is one tap to copy into the home's own care system or a message to family."),
    "done": (4,
        "Done. The session is in Irene's history and the carer is back on the roster.",
        "Done. The session is saved to Irene's history, and the carer is back on the roster."),
    "newres": (5,
        "Someone new has arrived and nobody knows their music yet — the carer starts a listening discovery.",
        "Now someone new has arrived at the home, and nobody knows her music yet. From the roster, the carer starts a listening discovery."),
    "agenat": (5,
        "Age and nationality set the running order: music from their teens and twenties first, with a gentle cultural bias.",
        "Age and nationality set the running order. Music from her teens and twenties plays first, with a gentle bias towards "
        "the sounds of where she grew up."),
    "clips": (5,
        "Seven short clips, one per genre, each with imagery from its era. The resident taps a face — green, amber or red.",
        "Seven short clips follow, one for each genre, each with imagery from its era. The resident simply taps a face: "
        "green for comforting, amber for unsure, red for uncomfortable."),
    "clipstap": (5,
        "Each tap moves straight on. No reading, no wrong answers; left alone, a clip plays for thirty seconds.",
        "Each tap moves straight on to the next clip. No reading, no wrong answers. Left alone, a clip simply plays for thirty seconds."),
    "clipsall": (5,
        "Every genre gets a fair hearing, in an order tuned to the resident.",
        "Rock, country, classical, gospel — every genre gets a fair hearing, in an order tuned to her."),
    "result": (5,
        "Her reactions build a first set of playlists, and the calm surface opens with them.",
        "Her reactions build a first set of playlists, and her calm surface opens with them straight away. She can start listening before she even has a name on the roster."),
    "staffkey2": (5,
        "Staff take the iPad back with the same press-and-hold.",
        "Staff take the iPad back with the same press and hold."),
    "saveres": (5,
        "Back with the carer: a name and photo so the next person on shift recognises her. Leaving without saving asks first.",
        "Back with the carer: a name and a photo, so the next person on shift recognises her. If a carer tries to leave without saving, "
        "the app asks first — nothing is thrown away by accident."),
    "saved": (5,
        "Saved. Edith is on the roster with her first session and starter playlists already logged.",
        "Saved. Edith is on the roster, with her first session and her starter playlists already logged."),
    "group": (6,
        "Group mode builds one shared-room playlist from the listening data of everyone on this home's roster — and plays exactly the track it shows.",
        "Group mode is for a lounge or a day room. It builds one shared playlist from the listening data of everyone on the roster, "
        "and plays exactly the track it shows."),
    "groupctl": (6,
        "Familiar controls for the carer leading the room — skip, or tap any song in the list.",
        "Familiar controls for the carer leading the room: pause, skip, or tap any song in the list to play it."),
    "groupend": (6,
        "Ending the group session.",
        "Ending the group session."),
    "groupfb": (6,
        "Four quick ratings — morale, alertness, orientation and engagement — log the session for the whole group.",
        "Four quick ratings — morale, alertness, orientation and engagement — log the session for the whole group."),
    "groupsaved": (6,
        "Saved — the latest group check-in is summarised right on the roster.",
        "Saved. The latest group check-in is summarised right on the roster."),
    "adminsign": (7,
        "Home leads and managers sign in with the same email and PIN.",
        "Finally, the view for home leads and managers. They sign in with the same email and PIN."),
    "picker": (7,
        "Anyone who looks after more than one home chooses which one to review.",
        "Anyone who looks after more than one home chooses which one to review."),
    "adminwelcome": (7,
        "A brief welcome while the home's insights are prepared.",
        "A brief welcome while the home's insights are prepared."),
    "dash": (7,
        "The home dashboard: sessions, residents reached, average at-ease and carer-observed wellbeing over the last fourteen days.",
        "The home dashboard: sessions, residents reached, average at ease, and carer observed wellbeing across the last fourteen days."),
    "expand": (7,
        "Tap any trend to expand it for a closer look.",
        "Tap any trend to expand it for a closer look."),
    "impact": (7,
        "Below: impact by wing, residents who are improving or need attention, and every recent session — evidence for the whole home.",
        "Below that: impact by wing, the residents who are improving or need attention, and every recent session. "
        "Evidence of impact for the whole home, from the same taps carers make every day."),
    "end": (None, "", ""),
    # Follow-on lines inside a long hold (see EXTRA: marker → [(seconds after the marker, key)]).
    "roster_scroll2": (1,
        "The star pins a resident to the top of the roster — handy for the regulars on a carer's round.",
        "The star pins a resident to the top of the roster — handy for the regulars on a carer's round."),
    "compact2": (1,
        "Search finds a resident by name, room or wing.",
        "And search finds a resident by name, room or wing."),
    "note2": (4,
        "The note appears in the summary and in the handover write-up.",
        "The note appears in the summary and in the handover write-up."),
    "copy2": (4,
        "Each version is written for its reader — clinical for the handover, warm and plain for the family.",
        "Each version is written for its reader: clinical for the handover, warm and plain for the family."),
    "clipsall2": (5,
        "Imagery from each song's era inside the orb, and a ring that moves with the music, give the resident something to watch while a clip plays.",
        "Imagery from each song's era sits inside the orb, and the ring moves with the music, so the resident has something to watch while a clip plays."),
    "groupctl2": (6,
        "The list shows what's coming next, so staff can see the whole set at a glance.",
        "The list shows what's coming next, so staff can see the whole set at a glance."),
    "impact2": (7,
        "Recent sessions list each resident, wing and outcome, so a manager can follow up on any one of them.",
        "Recent sessions list each resident, their wing and the outcome, so a manager can follow up on any one of them."),
    "groupfb2": (6,
        "Same one-to-ten scale as the one-to-one observations — carers never learn a second system.",
        "It's the same one to ten scale as the one-to-one observations, so carers never have to learn a second system."),
    # Spoken over the title and closing cards (no caption).
    "intro": (None, "",
        "NoteStalgia. Sound that takes you back. This walkthrough follows one afternoon in a care home, from a carer "
        "signing in to the home manager's dashboard — eight flows, end to end, exactly as they happen on the iPad."),
    "outro": (None, "",
        "Thanks for watching. We'd love your feedback on these four questions. Everything you've seen runs on the iPad, "
        "with demo residents and demo data."),
}


# marker → [(seconds after the marker, follow-on key)] for holds much longer than their line.
EXTRA = {
    "roster_scroll": [(12.0, "roster_scroll2")],
    "compact": [(9.0, "compact2")],
    "note": [(3.5, "note2")],
    "copy": [(6.0, "copy2")],
    "clipsall": [(14.0, "clipsall2")],
    "groupctl": [(8.0, "groupctl2")],
    "groupfb": [(10.0, "groupfb2")],
    "impact": [(13.0, "impact2")],
}


def chapter(key):
    return SCRIPT.get(key, (None, "", ""))[0]


def caption(key):
    return SCRIPT.get(key, (None, "", ""))[1]


def _parse_cue_file(path):
    """[(start, end, text)] from edge-tts's subtitle file (SRT-style blocks)."""
    pat = re.compile(r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)")
    cues, cur, lines = [], None, []
    def flush():
        if cur and lines:
            cues.append((cur[0], cur[1], " ".join(lines).strip()))
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        m = pat.search(line)
        if m:
            flush(); lines = []
            g = [int(x) for x in m.groups()]
            cur = (g[0] * 3600 + g[1] * 60 + g[2] + g[3] / 1000.0, g[4] * 3600 + g[5] * 60 + g[6] + g[7] / 1000.0)
        elif line and not line.isdigit() and line != "WEBVTT":
            lines.append(line)
    flush()
    out, last_end = [], 0.0
    for a, b, text in cues:                      # edge-tts cues overlap by a few ms; keep them sequential
        a = max(a, last_end)
        b = max(b, a + 0.3)
        out.append((a, b, text)); last_end = b
    return out


def _split_text(text, limit):
    """Split a sentence at the separator nearest its middle until every piece fits the limit."""
    if len(text) <= limit:
        return [text]
    best, best_d = None, None
    for m in re.finditer(r"(, | — |; | – |: )", text):
        cut = m.end()
        d = abs(cut - len(text) / 2)
        if best is None or d < best_d:
            best, best_d = cut, d
    if best is None or best < 12 or len(text) - best < 12:
        words = text.split(" "); mid = len(words) // 2
        best = len(" ".join(words[:mid])) + 1
    left, right = text[:best].rstrip(), text[best:].lstrip()
    return _split_text(left, limit) + _split_text(right, limit)


def _split_cues(cues, limit=SUB_MAX_CHARS):
    out = []
    for a, b, text in cues:
        parts = _split_text(text, limit)
        total = sum(len(p) for p in parts) or 1
        t = a
        for p in parts:
            d = (b - a) * len(p) / total
            out.append((round(t, 3), round(t + d, 3), p)); t += d
    return out


def _render(key):
    """Synthesises the line once; returns (wav_path, cues_path) or None when the key has no line."""
    text = SCRIPT.get(key, (None, "", ""))[2]
    if not text:
        return None
    os.makedirs(VOICE_DIR, exist_ok=True)
    digest = hashlib.sha1(f"{VOICE}|{EDGE_RATE if EDGE else RATE}|{text}".encode()).hexdigest()[:12]
    wav_path = os.path.join(VOICE_DIR, f"{key}_{digest}.wav")
    cues_path = wav_path[:-4] + ".cues.json"
    if not (os.path.exists(wav_path) and os.path.exists(cues_path)):
        raw_cues = None
        if EDGE:
            src = wav_path[:-4] + ".mp3"; sub = wav_path[:-4] + ".srt"
            r = subprocess.run([sys.executable, "-m", "edge_tts", "--voice", VOICE, f"--rate={EDGE_RATE}",
                                "--text", text, "--write-media", src, "--write-subtitles", sub],
                               capture_output=True, text=True)
            if r.returncode != 0 or not os.path.exists(src) or os.path.getsize(src) < 1000:
                raise SystemExit(f"edge-tts failed for '{key}': {r.stderr.strip()[-400:]}\n"
                                 "(needs network; set DEMO_VOICE=Daniel for the offline macOS voice)")
            raw_cues = _parse_cue_file(sub); os.remove(sub)
        else:
            src = wav_path[:-4] + ".aiff"
            subprocess.run(["say", "-v", VOICE, "-r", str(RATE), "-o", src, text], check=True)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src,
                        "-ac", "2", "-ar", str(SR), "-af", "loudnorm=I=-19:TP=-2:LRA=9", "-f", "wav", wav_path], check=True)
        os.remove(src)
        with wave.open(wav_path) as w:
            secs = w.getnframes() / SR
        if not raw_cues:
            # `say` gives no timings: one cue per sentence, timed by length.
            sentences = [t for t in re.split(r"(?<=[.!?])\s+", text) if t]
            total = sum(len(t) for t in sentences); t0 = 0.05; raw_cues = []
            for sent in sentences:
                d = (secs - 0.1) * len(sent) / total
                raw_cues.append((t0, t0 + d, sent)); t0 += d
        json.dump(_split_cues(raw_cues), open(cues_path, "w"))
    return wav_path, cues_path


def speak(key):
    """Returns (stereo float32 array at SR, seconds) for the marker's spoken line, or None."""
    r = _render(key)
    if r is None:
        return None
    with wave.open(r[0]) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    data = data.reshape(-1, 2)
    return data, len(data) / SR


def line_cues(key):
    """[(start, end, text)] relative to the line's start, for subtitles."""
    r = _render(key)
    return [tuple(c) for c in json.load(open(r[1]))] if r else []


if __name__ == "__main__":
    total = 0
    for key in SCRIPT:
        r = speak(key)
        if r:
            total += r[1]
            print(f"{key:18s} {r[1]:5.1f}s")
    print(f"total narration {total:.0f}s")
