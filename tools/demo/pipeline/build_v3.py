"""Assemble the v3 walkthrough from scripted takes.

    python3 tools/demo/pipeline/build_v3.py [out.mp4]

Inputs (made by tools/demo/walkthrough.sh): .demo-work/takes/<take>.mp4 + .log.jsonl + .sync.json for
    s1_resident · s2_discovery · s3_group · s4_admin

What it does
  1. Maps each take's app event log onto its video clock (video_t = (t - start) - trim + calib). `calib`
     is measured from the frames: the first phase change is a big luminance step (orb-only welcome ↔
     dark cards), so we find where that step actually happens in the picture.
  2. Cuts chapters at phase changes, writes captions per phase (and per music event on the calm surface),
     renders the cards/chrome/captions with build.py and composites everything with render.swift.
  3. Audio: the take's own track when the recording had one (BlackHole), otherwise the app's sounds are
     rebuilt from the log (bundled MP3s + synthesised chimes, mix_v2.py). Soft bed under intro/outro.
"""
import json
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build as B  # noqa: E402
import mix_v2 as M  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORK = os.environ.get("DEMO_WORKDIR", os.path.join(REPO, ".demo-work"))
TAKES = os.path.join(WORK, "takes")
PNG = os.path.join(WORK, "png_v3")
B.PNG = PNG
RENDER = os.path.join(WORK, "bin", "render")

GENRE = {
    "Velvet Afterhours": "Jazz", "Velvet Cadenza": "Classical", "Echoes of Yesterday": "Pop",
    "Velvet Highway": "Rock", "Pine Smoke Drift": "Country", "Pine Smoke Drift (1)": "Gospel",
    "Drift Between Rooms": "Soul",
}

CAPTIONS = dict(B.CAPTIONS)
CAPTIONS.update({
    "open": "NoteStalgia opens on its signature orb — breathing slowly, three seconds in, three seconds out.",
    "welcome": "A calm welcome while the roster, portraits and the day's data are made ready — then straight in.",
    "roster": "Today's roster: pinned, recently seen and 'due a visit' residents first, under a home-wide wellbeing summary. Every tap glows and chimes softly.",
    "profile": "A resident's profile: carer-observed trends, their genre playlists, songs family know they love — and their comfort notes on light, scent and touch.",
    "handoff": "The carer opens the calm surface and hands over the iPad.",
    "surface": "The resident's own view: no words — their music as floating artwork around the orb. A glowing ripple answers every touch.",
    "play": "One tap plays that genre. The orb blooms into full-screen, mood-matched imagery and the ring pulses with the live music.",
    "sun": "Sun = “I like this”. It's remembered, so the song comes round sooner next time.",
    "switch": "Tapping another genre folds the imagery back into the orb and re-blooms with the new music.",
    "cloud": "Cloud = “not for me”. The song is skipped and taken out of today's session — there are no wrong answers.",
    "captured": "Staff press and hold the corner key to take the iPad back. Everything the resident did is already captured: time with music, genres, likes, skips.",
    "ratings": "Four quick 1–10 carer observations — mood, alertness, emotional presentation, orientation — plus optional context tags and a note.",
    "insight": "The session summary: at a glance — trend against their usual, time with music, what they responded to — then carer ratings and one suggested next step.",
    "copy": "Handover, family update and care-plan entry — one readable write-up at a time, one tap to copy into the home's own systems.",
    "done": "Done. The session is in the resident's history and the carer is back on the roster.",
    "newres": "Someone new has arrived and nobody knows their music yet — the carer starts a listening discovery.",
    "agenat": "Age and nationality set the running order: music from their teens and twenties first, with a gentle cultural bias.",
    "clips": "Seven short clips, one per genre, each with imagery from its era. The resident taps a face — green, amber or red.",
    "clipstap": "Each tap moves straight on. No reading, no wrong answers; left alone, a clip plays for 30 seconds.",
    "clipsall": "Every genre gets a fair hearing, in an order tuned to the resident.",
    "result": "Their reactions build a first set of playlists, and the calm surface opens with them.",
    "saveres": "Back with the carer: a name and photo, so the next person on shift recognises them. Leaving without saving asks first.",
    "saved": "Saved. Edith is on the roster with her first session and starter playlists already logged.",
    "group": "Group mode builds one shared-room playlist from the listening data of everyone on this home's roster — and plays exactly the track it shows.",
    "groupctl": "Familiar controls for the carer leading the room — pause, skip, or tap any song in the list.",
    "groupfb": "When the group finishes, four quick ratings — morale, alertness, orientation and engagement — log the session.",
    "groupsaved": "Saved — the latest group check-in is summarised right on the roster.",
    "picker": "Home leads who look after more than one home choose which one to review.",
    "adminwelcome": "A brief welcome while the home's insights are prepared.",
    "dash": "The home dashboard: sessions, residents reached, average at-ease and carer-observed wellbeing over the last 14 days.",
    "impact": "Below: impact by wing, residents who are improving or need attention, and every recent session — evidence for the whole home.",
})

# Each take: chapter for each phase, caption rules, and the cut window around its phases.
TAKE_PLAN = {
    "s1_resident": {
        "lead_in": 2.2, "tail": 3.0,
        "chapters": {"supervisorWelcome": 0, "carePatientList": 1, "carePatientDetail": 2, "residentProfile": 3,
                     "careSessionSentimentFeedback": 4, "careSessionInsight": 4},
        "last_phase_chapter": 4,   # the final carePatientList belongs to "After the session"
    },
    "s2_discovery": {
        "lead_in": 0.4, "tail": 4.5, "skip_until": "careDiscoveryAgeInput",
        "chapters": {"careDiscoveryAgeInput": 5, "careDiscoveryCalibration": 5, "residentProfile": 5,
                     "careNewResidentProfile": 5, "carePatientList": 5},
    },
    "s3_group": {
        "lead_in": 0.4, "tail": 2.5, "skip_until": "careGroupSession",
        "chapters": {"careGroupSession": 6, "careGroupSessionFeedback": 6, "carePatientList": 6},
    },
    "s4_admin": {
        "lead_in": 0.4, "tail": 13.0, "skip_until": "careHomePicker",
        "chapters": {"careHomePicker": 7, "careHomeAdminWelcome": 7, "careHomeAdminDashboard": 7},
    },
}


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def duration(path):
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).stdout
    return float(out.strip())


def has_audio(path):
    """True when the take carries a usable audio track — present *and* not silence (a BlackHole
    capture with the Mac's output still on the speakers records a perfectly flat line)."""
    out = run(["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream=index", "-of", "csv=p=0", path]).stdout
    if not out.strip():
        return False
    probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
                           capture_output=True, text=True)
    for line in probe.stderr.splitlines():
        if "mean_volume" in line:
            try:
                mean_db = float(line.split("mean_volume:")[1].split("dB")[0])
            except ValueError:
                return False
            usable = mean_db > -60
            if not usable:
                print(f"  {os.path.basename(path)}: audio track is silent ({mean_db:.0f} dB) — rebuilding from the log")
            return usable
    return False


class Take:
    def __init__(self, name):
        self.name = name
        self.video = os.path.join(TAKES, f"{name}.mp4")
        self.sync = json.load(open(os.path.join(TAKES, f"{name}.sync.json")))
        self.events = sorted(
            (json.loads(l) for l in open(os.path.join(TAKES, f"{name}.log.jsonl")) if l.strip()),
            key=lambda e: e["t"],
        )
        self.duration = duration(self.video)
        self.audio = has_audio(self.video)
        self.calib = 0.0
        self.phases = [e for e in self.events if e["event"] == "phase"]

    def vt(self, t):
        return (t - self.sync["start"]) - self.sync["trim"] + self.calib

    def calibrate(self):
        """Measure where the first phase change lands in the picture and correct the clock."""
        if len(self.phases) < 2:
            return
        # The first phase is set as the title fades (sign-in), so use the second phase change.
        target = self.phases[1]["t"]
        expected = self.vt(target)
        lo = max(0.0, expected - 4.0)
        tmp = tempfile.mkdtemp(prefix="calib_")
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{lo:.3f}", "-t", "8", "-i", self.video,
             "-vf", "fps=10,scale=164:-1", os.path.join(tmp, "%03d.png")])
        frames = sorted(f for f in os.listdir(tmp) if f.endswith(".png"))
        if len(frames) < 20:
            return
        lum = []
        for f in frames:
            im = np.asarray(Image.open(os.path.join(tmp, f)).convert("L"), dtype=float)
            h, w = im.shape
            lum.append(im[int(h * 0.30):int(h * 0.60), int(w * 0.20):int(w * 0.80)].mean())
        lum = np.array(lum)
        before, after = np.median(lum[:10]), np.median(lum[-10:])
        if abs(before - after) < 12:
            print(f"  {self.name}: no clear step for calibration (Δlum {abs(before - after):.1f}); keeping 0")
            return
        thr = (before + after) / 2
        crossing = next((i for i in range(1, len(lum)) if (lum[i] - thr) * (before - thr) < 0), None)
        if crossing is None:
            return
        t_star = lo + crossing / 10.0
        # `transitionToPhase` fades the old screen out (0.38 s), stamps the phase, then fades the new
        # one in (~0.45 s). A bright→dark step (dark cards fading in) crosses mid-way ≈0.28 s after
        # the stamp; a dark→bright step (dark screen fading out) crosses ≈0.21 s before it.
        stamp = t_star - 0.28 if before > after else t_star + 0.21
        self.calib = stamp - expected
        print(f"  {self.name}: phase change seen at {t_star:.2f}s ({'bright→dark' if before > after else 'dark→bright'}), logged at {expected:.2f}s → calib {self.calib:+.2f}s")

    def music_intervals(self):
        """[(start_vt, end_vt, title)]"""
        open_by_player, out = {}, []
        for e in self.events:
            if e["event"] == "music.start":
                open_by_player[e["player"]] = (self.vt(e["t"]), os.path.splitext(e["file"])[0], e.get("volume", 0.38))
            elif e["event"] == "music.stop" and e["player"] in open_by_player:
                s, title, vol = open_by_player.pop(e["player"])
                out.append((s, self.vt(e["t"]), title, vol))
        for s, title, vol in open_by_player.values():
            out.append((s, self.duration, title, vol))
        return out

    def chimes(self):
        return [(self.vt(e["t"]), e["variant"]) for e in self.events if e["event"] == "chime"]


def phase_spans(take, plan):
    """[(start_vt, end_vt, phase)] over the cut window."""
    phases = take.phases
    if "skip_until" in plan:
        idx = next(i for i, p in enumerate(phases) if p["phase"] == plan["skip_until"])
        phases = phases[idx:]
    spans = []
    for i, p in enumerate(phases):
        start = take.vt(p["t"])
        end = take.vt(phases[i + 1]["t"]) if i + 1 < len(phases) else min(take.duration - 0.3, start + plan["tail"])
        spans.append((start, end, p["phase"]))
    return spans


def captions_for(take, span_start, span_end, phase, plan, take_name):
    """[(start, end, key, now_playing)] within one phase span."""
    L = span_end - span_start
    def pieces(keys_at):  # [(offset, key)]
        out = []
        for i, (off, key) in enumerate(keys_at):
            a = span_start + off
            b = span_start + keys_at[i + 1][0] if i + 1 < len(keys_at) else span_end
            if b - a > 0.2:
                out.append((a, b, key, None))
        return out

    if take_name == "s1_resident":
        if phase == "supervisorWelcome":
            return [(span_start - plan["lead_in"], span_start, "open", None)] + pieces([(0, "welcome")])
        if phase == "carePatientList":
            return pieces([(0, "roster")]) if span_start < take.vt(take.phases[-1]["t"]) else pieces([(0, "done")])
        if phase == "carePatientDetail":
            return pieces([(0, "profile"), (max(0, L - 3.0), "handoff")])
        if phase == "residentProfile":
            keys = [(0, "surface")]
            starts = [s for s, _, _, _ in take.music_intervals() if span_start <= s < span_end]
            stops = [e for _, e, _, _ in take.music_intervals() if span_start <= e < span_end]
            chimes = [c for c, _ in take.chimes() if span_start <= c < span_end]
            if starts:
                keys.append((starts[0] - span_start, "play"))
                likes = [c for c in chimes if starts[0] + 1.5 < c < (starts[1] if len(starts) > 1 else span_end) - 0.5]
                if likes:
                    keys.append((likes[0] - span_start, "sun"))
                if len(starts) > 1:
                    keys.append((starts[1] - span_start, "switch"))
                    skip = [e for e in stops if e > starts[1] + 1.0 and not any(abs(s - e) < 0.6 for s in starts)]
                    if skip:
                        keys.append((skip[0] - span_start, "cloud"))
            out = pieces(sorted(keys))
            # now-playing tag while music runs
            res = []
            for a, b, key, _ in out:
                np_ = None
                for s, e, title, _ in take.music_intervals():
                    if s <= a + 0.05 and e > a + 0.5:
                        np_ = (title, GENRE.get(title, ""))
                res.append((a, b, key, np_))
            return res
        if phase == "careSessionSentimentFeedback":
            return pieces([(0, "captured"), (min(5.0, L / 2), "ratings")])
        if phase == "careSessionInsight":
            return pieces([(0, "insight"), (min(8.0, L * 0.55), "copy")])
    if take_name == "s2_discovery":
        if phase == "careDiscoveryAgeInput":
            return pieces([(0, "newres"), (min(3.5, L / 2), "agenat")])
        if phase == "careDiscoveryCalibration":
            return pieces([(0, "clips"), (min(11, L / 3), "clipstap"), (min(24, 2 * L / 3), "clipsall")])
        if phase == "residentProfile":
            return pieces([(0, "result")])
        if phase == "careNewResidentProfile":
            return pieces([(0, "saveres")])
        if phase == "carePatientList":
            return pieces([(0, "saved")])
    if take_name == "s3_group":
        if phase == "careGroupSession":
            res = pieces([(0, "group"), (min(9, L / 2), "groupctl")])
            out = []
            for a, b, key, _ in res:
                np_ = None
                for s, e, title, _ in take.music_intervals():
                    if s <= a + 0.05 and e > a + 0.5:
                        np_ = (title, GENRE.get(title, ""))
                out.append((a, b, key, np_))
            return out
        if phase == "careGroupSessionFeedback":
            return pieces([(0, "groupfb")])
        if phase == "carePatientList":
            return pieces([(0, "groupsaved")])
    if take_name == "s4_admin":
        if phase == "careHomePicker":
            return pieces([(0, "picker")])
        if phase == "careHomeAdminWelcome":
            return pieces([(0, "adminwelcome")])
        if phase == "careHomeAdminDashboard":
            return pieces([(0, "dash"), (min(9, L / 2), "impact")])
    return pieces([(0, "roster")])


def main(out_path):
    os.makedirs(PNG, exist_ok=True)
    takes = {name: Take(name) for name in TAKE_PLAN}
    print("calibrating takes…")
    for t in takes.values():
        t.calibrate()

    B.save(B.background(True), "bg.png")
    segments, overlays = [], []
    chrome_cache, caption_cache = {}, {}
    chapter_spans, caption_spans = [], []
    t_out = 0.0
    audio_pieces = []   # (take, srcStart, srcEnd, outStart)

    def add_card(png, dur, src_take, src_t):
        nonlocal t_out
        segments.append({"kind": "card", "src": src_take, "outStart": t_out, "outEnd": t_out + dur, "srcStart": src_t, "srcEnd": src_t})
        overlays.append({"png": png, "start": max(0.0, t_out - B.CARD_FADE), "end": t_out + dur + B.CARD_FADE,
                         "fadeIn": B.CARD_FADE if t_out > 0 else 0.0, "fadeOut": B.CARD_FADE, "layer": 2})
        t_out += dur

    def add_clip(take, src_start, src_end, chapter, caps, new_chapter):
        nonlocal t_out
        src_start = max(0.0, src_start); src_end = min(take.duration, src_end)
        dur = src_end - src_start
        if dur <= 0.05:
            return
        segments.append({"kind": "clip", "src": take.name, "outStart": t_out, "outEnd": t_out + dur,
                         "srcStart": src_start, "srcEnd": src_end, "xfade": 0.0})
        audio_pieces.append((take, src_start, src_end, t_out))
        if chapter not in chrome_cache:
            chrome_cache[chapter] = B.save(B.chrome(chapter), f"chrome_{chapter}.png")
        if chapter_spans and chapter_spans[-1][2] == chapter:
            chapter_spans[-1][1] = t_out + dur
        else:
            chapter_spans.append([t_out, t_out + dur, chapter])
        for a, b, key, np_ in caps:
            a2, b2 = max(a, src_start), min(b, src_end)
            if b2 - a2 < 0.15:
                continue
            ck = (key, np_)
            if ck not in caption_cache:
                caption_cache[ck] = B.save(B.caption_layer(CAPTIONS[key], np_), f"cap_{len(caption_cache):02d}.png")
            oa, ob = t_out + (a2 - src_start), t_out + (b2 - src_start)
            if caption_spans and caption_spans[-1][2] == ck and abs(caption_spans[-1][1] - oa) < 1e-6:
                caption_spans[-1][1] = ob
            else:
                caption_spans.append([oa, ob, ck, new_chapter and abs(oa - t_out) < 1e-6])
        t_out += dur

    first_take = takes["s1_resident"]
    add_card(B.save(B.intro_card(), "intro.png"), B.INTRO_DUR, first_take.name, 0.0)

    current_chapter = None
    for name, plan in TAKE_PLAN.items():
        take = takes[name]
        spans = phase_spans(take, plan)
        for i, (a, b, phase) in enumerate(spans):
            chapter = plan["chapters"].get(phase, current_chapter if current_chapter is not None else 0)
            if name == "s1_resident" and phase == "carePatientList" and i == len(spans) - 1:
                chapter = plan["last_phase_chapter"]
            caps = captions_for(take, a, b, phase, plan, name)
            clip_start = a - plan["lead_in"] if i == 0 else a
            new_chapter = chapter != current_chapter
            if new_chapter and chapter != 0:
                add_card(B.save(B.chapter_card(chapter), f"chapter_{chapter}.png"), B.CHAPTER_DUR, take.name, clip_start)
            add_clip(take, clip_start, b, chapter, caps, new_chapter)
            current_chapter = chapter

    outro_t = t_out
    segments.append({"kind": "card", "src": "s4_admin", "outStart": t_out, "outEnd": t_out + B.OUTRO_DUR,
                     "srcStart": takes["s4_admin"].duration - 0.5, "srcEnd": takes["s4_admin"].duration - 0.5})
    overlays.append({"png": B.save(B.outro_card(), "outro.png"), "start": t_out - B.CARD_FADE, "end": t_out + B.OUTRO_DUR,
                     "fadeIn": B.CARD_FADE, "fadeOut": 0.0, "layer": 2})
    t_out += B.OUTRO_DUR

    for a, b, ch in chapter_spans:
        overlays.append({"png": chrome_cache[ch], "start": a, "end": b, "fadeIn": 0.0, "fadeOut": 0.0, "layer": 0})
    for i, (a, b, ck, starts_chapter) in enumerate(caption_spans):
        last = i == len(caption_spans) - 1 or caption_spans[i + 1][3]
        overlays.append({"png": caption_cache[ck], "start": a, "end": b + (0.0 if last else B.CAPTION_FADE),
                         "fadeIn": 0.0 if starts_chapter else B.CAPTION_FADE,
                         "fadeOut": 0.0 if last else B.CAPTION_FADE, "layer": 1})
    overlays.sort(key=lambda o: (o["layer"], o["start"]))

    plan = {
        "width": B.W, "height": B.H, "fps": B.FPS, "duration": t_out,
        "screen": {"x": B.SCREEN[0], "y": B.SCREEN[1], "w": B.SCREEN[2], "h": B.SCREEN[3], "radius": B.SCREEN_RADIUS},
        "background": os.path.join(PNG, "bg.png"),
        "sources": {t.name: t.video for t in takes.values()},
        "segments": segments, "overlays": overlays,
    }
    plan_path = os.path.join(WORK, "plan_v3.json")
    json.dump(plan, open(plan_path, "w"), indent=1)
    print(f"plan: {t_out:.1f}s, {len(segments)} segments, {len(overlays)} overlays, {len(caption_cache)} captions")

    video_only = os.path.join(WORK, "video_only_v3.mp4")
    print("rendering video…")
    subprocess.run([RENDER, plan_path, video_only], check=True)

    print("mixing audio…")
    SR = M.SR
    buf = np.zeros((int(t_out * SR) + SR, 2), dtype=np.float32)
    tracks, chime_buf = {}, {}
    for take, s, e, out_start in audio_pieces:
        if take.audio:
            tmp = os.path.join(WORK, f"a_{take.name}_{int(s * 100)}.wav")
            run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", take.video,
                 "-vn", "-ac", "2", "-ar", str(SR), "-f", "wav", tmp])
            with wave.open(tmp) as w:
                data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
            M.place(buf, data.reshape(-1, 2), out_start, fade_in=0.05, fade_out=0.05)
            continue
        for a, b, title, vol in take.music_intervals():
            ov_s, ov_e = max(a, s), min(b, e)
            if ov_e - ov_s < 0.05:
                continue
            if title not in tracks:
                tracks[title] = M.load_track(title)
            data = tracks[title]
            i0 = int((ov_s - a) * SR)
            piece = data[i0:i0 + int((ov_e - ov_s) * SR)].copy()
            fi = M.CLIP_FADE if ov_s > a + 0.01 else 0.02
            fo = M.CLIP_FADE if ov_e < b - 0.01 else 0.02
            M.place(buf, piece, out_start + (ov_s - s), gain=vol, fade_in=fi, fade_out=fo)
        for ct, variant in take.chimes():
            if s <= ct < e:
                if variant not in chime_buf:
                    chime_buf[variant] = M.chime(variant)
                M.place(buf, chime_buf[variant].copy(), out_start + (ct - s))
    bed = M.load_track("Velvet Cadenza")
    for a, b in ((0.0, B.INTRO_DUR), (outro_t, t_out)):
        n = int((b - a) * SR)
        M.place(buf, bed[:n].copy(), a, gain=0.16, fade_in=1.2, fade_out=2.0)
    peak = float(np.max(np.abs(buf))) or 1.0
    gain = min(2.6, 0.89 / peak)
    mixed = np.clip(np.tanh(buf * gain * 1.05) / math.tanh(1.05), -1, 1)
    wav_path = os.path.join(WORK, "soundtrack_v3.wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((mixed * 32767).astype(np.int16).tobytes())

    print("muxing…")
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", video_only, "-i", wav_path,
         "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", out_path])
    print(f"wrote {out_path} ({duration(out_path):.1f}s)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "NoteStalgia-Walkthrough-v3.mp4"))
