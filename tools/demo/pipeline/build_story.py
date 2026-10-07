"""Assemble the narrated, subtitled walkthrough from the three story takes (a_story, b_story, c_story).

Each take is one continuous, chronological run of `DemoWalkthroughUITests` recorded by
`tools/demo/walkthrough.sh`. Alongside the video it leaves:

  <take>.markers.log   `epoch|label` lines the script wrote at every step (see narration.py)
  <take>.log.jsonl     the app's own demo log (phases, music start/stop, chimes)
  <take>.sync.json     recording start + trim, mapping those clocks onto the video

Markers drive everything: chapter cards are cut in where a marker's flow changes, each marker's
caption is shown until the next one, and its narration line (macOS `say`) is queued at the marker —
never overlapping the previous line — with the music ducked underneath. The soundtrack is the take's
own audio when BlackHole captured it, otherwise rebuilt from the log exactly as in v3.

Subtitles: every narration cue (sentence timings from the voice engine, long sentences split) is
rendered as a strip under the device and composited with the picture; the same cues go to a sidecar
.srt next to the video.

    python3 tools/demo/pipeline/build_story.py                 # → NoteStalgia-Walkthrough-v5.mp4 + .srt
    python3 tools/demo/pipeline/build_story.py --reuse-video   # narration/mix only: keeps the rendered picture
                                                               # (only valid while captions, cuts and subtitles are unchanged)
"""
import json
import math
import os
import subprocess
import sys
import wave

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build as B            # noqa: E402  card / caption renderers, FLOWS, layout constants
import build_v3 as V3        # noqa: E402  Take (sync, calibration, music intervals, chimes)
import mix_v2 as M           # noqa: E402  track loading, chime synthesis, placement
import narration as N        # noqa: E402  marker → chapter / caption / spoken line

REPO = V3.REPO
WORK = V3.WORK
TAKES = V3.TAKES
PNG = os.path.join(WORK, "png_story")
RENDER = V3.RENDER
B.PNG = PNG

TAKE_NAMES = ["a_story", "b_story", "c_story"]
LEAD_IN = 1.2        # seconds of take kept before its first marker
TAIL = 1.5           # seconds kept after the "end" marker
INTRO_DUR = 15.0
CHAPTER_DUR = 3.4
OUTRO_DUR = 12.0
VOICE_DELAY = 0.45   # narration starts this long after its marker
VOICE_GAP = 0.5      # minimum silence between two lines
DUCK = 0.33          # music gain under narration
DUCK_RAMP = 0.3
B.INTRO_DUR, B.CHAPTER_DUR, B.OUTRO_DUR = INTRO_DUR, CHAPTER_DUR, OUTRO_DUR
# Layout: the device is a little smaller than in v3/v4 so a subtitle band fits under it, and the
# flow index in the right-hand panel moves up out of that band.
B.SCREEN = (208, 40, 619, 890)
B.INDEX_Y = 690
SUB_Y = 940          # top of the 1920×150 subtitle strip
SUB_FADE = 0.12


class StoryTake(V3.Take):
    def __init__(self, name):
        super().__init__(name)
        self.anchors = []
        self.calibrated = False
        path = os.path.join(TAKES, f"{name}.markers.log")
        self.marks = []
        for line in open(path):
            if "|" not in line:
                continue
            t, label = line.strip().split("|", 1)
            self.marks.append((float(t), label))
        self.marks.sort()
        if not self.marks:
            raise SystemExit(f"{name}: no markers")

    # The simulator recorder does not keep perfect wall-clock time: under heavy load (app launch,
    # discovery media loading) it loses a second or two, so one offset per take is not enough.
    # Every clear phase change is measured and the offset is interpolated between them.
    def raw_vt(self, t):
        return (t - self.sync["start"]) - self.sync["trim"]

    def vt(self, t):
        raw = self.raw_vt(t)
        if not self.anchors:
            return raw + self.calib
        xs = [a for a, _ in self.anchors]
        ys = [o for _, o in self.anchors]
        return raw + float(np.interp(raw, xs, ys))

    def calibrate(self):
        self.anchors = []
        raws = [self.raw_vt(p["t"]) for p in self.phases]
        for i, raw in enumerate(raws):
            if raw < 3.0:
                continue
            # Two phase changes inside one ±4 s window can't be told apart (the welcome → roster step
            # would be credited to the sign-in → welcome stamp), so skip close pairs.
            near = [r for j, r in enumerate(raws) if j != i and abs(r - raw) < 4.5]
            if near:
                continue
            off = self._offset_at(raw)
            if off is not None:
                self.anchors.append((raw, off))
        self.anchors.sort()
        # Drop an interior outlier: an anchor that disagrees with both neighbours by >1.5 s while they
        # agree with each other (the recorder only ever loses time, so a V-shape is a misdetection).
        # Endpoints are kept — a real jump often sits right after a heavy load such as app launch.
        kept = []
        for i, (raw, off) in enumerate(self.anchors):
            neigh = [o for j, (_, o) in enumerate(self.anchors) if abs(j - i) == 1]
            if len(neigh) == 2 and all(abs(o - off) > 1.5 for o in neigh) and abs(neigh[0] - neigh[1]) < 0.6:
                print(f"  {self.name}: dropping anchor at {raw:.0f}s ({off:+.1f}s) — disagrees with its neighbours")
                continue
            kept.append((raw, off))
        self.anchors = kept
        self.calibrated = bool(self.anchors)
        if not self.anchors:
            print(f"  {self.name}: no usable phase step")
            return
        offs = [o for _, o in self.anchors]
        self.calib = float(np.median(offs))
        print(f"  {self.name}: {len(self.anchors)} anchors, offset {min(offs):+.2f}…{max(offs):+.2f}s "
              + " ".join(f"({a:.0f}s {o:+.1f})" for a, o in self.anchors))

    def _offset_at(self, expected):
        """Offset (seconds) between where a phase change shows in the picture and where the log
        puts it, or None when the surrounding frames give no clean single step."""
        import tempfile
        lo = max(0.0, expected - 4.0)
        tmp = tempfile.mkdtemp(prefix="calib_")
        V3.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{lo:.3f}", "-t", "8", "-i", self.video,
                "-vf", "fps=10,scale=164:-1", os.path.join(tmp, "%03d.png")])
        frames = sorted(f for f in os.listdir(tmp) if f.endswith(".png"))
        if len(frames) < 40:
            return None
        lum = []
        for f in frames:
            im = np.asarray(Image.open(os.path.join(tmp, f)).convert("L"), dtype=float)
            h, w = im.shape
            lum.append(im[int(h * 0.30):int(h * 0.60), int(w * 0.20):int(w * 0.80)].mean())
            os.remove(os.path.join(tmp, f))
        lum = np.array(lum)
        n = len(lum) // 8
        before, after = np.median(lum[:n]), np.median(lum[-n:])
        if abs(before - after) < 12 or lum[-n:].std() > 4.0:      # the new screen must be static
            return None
        thr = (before + after) / 2
        crossings = [i for i in range(1, len(lum)) if (lum[i] - thr) * (lum[i - 1] - thr) < 0]
        if len(crossings) != 1:                                    # one clean step only
            return None
        t_star = lo + crossings[0] / 10.0
        # `transitionToPhase` fades the old screen out (0.38 s), stamps the phase, then fades the new
        # one in (~0.45 s): a bright→dark step crosses ≈0.28 s after the stamp, dark→bright ≈0.21 s before.
        stamp = t_star - 0.28 if before > after else t_star + 0.21
        return stamp - expected

    def marker_spans(self):
        """[(start_vt, end_vt, label)] — each marker runs until the next one; a long hold is split
        where narration.EXTRA schedules a follow-on line (only if ≥3 s of the hold remain)."""
        out = []
        for i, (t, label) in enumerate(self.marks):
            a = self.vt(t)
            b = self.vt(self.marks[i + 1][0]) if i + 1 < len(self.marks) else min(self.duration - 0.2, a + TAIL)
            pieces = [(a, label)] + [(a + off, key) for off, key in N.EXTRA.get(label, []) if a + off < b - 3.0]
            for j, (pa, pk) in enumerate(pieces):
                pb = pieces[j + 1][0] if j + 1 < len(pieces) else b
                out.append((pa, pb, pk))
        return out

    def now_playing(self, at):
        for s, e, title, _ in self.music_intervals():
            if s <= at + 0.6 and e > at + 0.8:
                return (title, V3.GENRE.get(title, ""))
        return None


def main(out_path, reuse_video=False):
    os.makedirs(PNG, exist_ok=True)
    takes = {name: StoryTake(name) for name in TAKE_NAMES}
    print("calibrating takes…")
    for t in takes.values():
        t.calibrate()
    measured = [t.calib for t in takes.values() if t.calibrated]
    for t in takes.values():
        if not t.calibrated and measured:
            t.calib = float(np.median(measured))   # same recorder, same start latency
            print(f"  {t.name}: using the other takes' median calib {t.calib:+.2f}s")

    B.save(B.background(True), "bg.png")
    segments, overlays = [], []
    chrome_cache, caption_cache = {}, {}
    chapter_spans, caption_spans = [], []
    voice_cues = []          # (out_time, key)
    audio_pieces = []        # (take, srcStart, srcEnd, outStart)
    bed_spans = []           # (outStart, outEnd, gain)
    t_out = 0.0

    def add_card(png, dur, src_take, src_t, bed_gain):
        nonlocal t_out
        segments.append({"kind": "card", "src": src_take, "outStart": t_out, "outEnd": t_out + dur,
                         "srcStart": src_t, "srcEnd": src_t})
        overlays.append({"png": png, "start": max(0.0, t_out - B.CARD_FADE), "end": t_out + dur + B.CARD_FADE,
                         "fadeIn": B.CARD_FADE if t_out > 0 else 0.0, "fadeOut": B.CARD_FADE, "layer": 2})
        bed_spans.append((t_out, t_out + dur, bed_gain))
        t_out += dur

    def add_clip(take, src_start, src_end, chapter, caps, new_chapter):
        """caps: [(src_a, src_b, key)] — captions + voice cues inside this clip."""
        nonlocal t_out
        src_start = max(0.0, src_start)
        src_end = min(take.duration, src_end)
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
        for a, b, key in caps:
            a2, b2 = max(a, src_start), min(b, src_end)
            if b2 - a2 < 0.15:
                continue
            if abs(a - a2) < 1e-6:                        # the marker itself is inside this clip
                voice_cues.append((t_out + (a - src_start), key))
            text = N.caption(key)
            if not text:
                continue
            np_ = take.now_playing(a2)
            ck = (key, np_)
            if ck not in caption_cache:
                caption_cache[ck] = B.save(B.caption_layer(text, np_), f"cap_{len(caption_cache):02d}.png")
            oa, ob = t_out + (a2 - src_start), t_out + (b2 - src_start)
            if caption_spans and caption_spans[-1][2] == ck and abs(caption_spans[-1][1] - oa) < 1e-6:
                caption_spans[-1][1] = ob
            else:
                caption_spans.append([oa, ob, ck, new_chapter and abs(oa - t_out) < 1e-6])
        t_out += dur

    # Title card, narrated.
    first = takes[TAKE_NAMES[0]]
    voice_cues.append((1.2, "intro"))
    add_card(B.save(B.intro_card(), "intro.png"), INTRO_DUR, first.name, 0.0, 0.16)

    current_chapter = None
    for name in TAKE_NAMES:
        take = takes[name]
        spans = take.marker_spans()
        # Group consecutive markers into runs with the same chapter; cut a card where it changes.
        runs = []
        for a, b, label in spans:
            ch = N.chapter(label)
            if ch is None:
                ch = runs[-1][0] if runs else current_chapter if current_chapter is not None else 0
            if runs and runs[-1][0] == ch:
                runs[-1][1].append((a, b, label))
            else:
                runs.append([ch, [(a, b, label)]])
        for i, (chapter, caps) in enumerate(runs):
            clip_start = caps[0][0] - LEAD_IN if i == 0 else caps[0][0]
            clip_end = caps[-1][1]
            new_chapter = chapter != current_chapter
            if new_chapter and chapter != 0:
                add_card(B.save(B.chapter_card(chapter), f"chapter_{chapter}.png"), CHAPTER_DUR,
                         take.name, max(0.0, clip_start), 0.11)
            add_clip(take, clip_start, clip_end, chapter, caps, new_chapter)
            current_chapter = chapter

    outro_t = t_out
    last = takes[TAKE_NAMES[-1]]
    voice_cues.append((t_out + 1.0, "outro"))
    segments.append({"kind": "card", "src": last.name, "outStart": t_out, "outEnd": t_out + OUTRO_DUR,
                     "srcStart": last.duration - 0.5, "srcEnd": last.duration - 0.5})
    overlays.append({"png": B.save(B.outro_card(), "outro.png"), "start": t_out - B.CARD_FADE, "end": t_out + OUTRO_DUR,
                     "fadeIn": B.CARD_FADE, "fadeOut": 0.0, "layer": 2})
    bed_spans.append((t_out, t_out + OUTRO_DUR, 0.16))
    t_out += OUTRO_DUR

    # Narration schedule: lines start at their marker (+VOICE_DELAY) but never overlap the previous one.
    schedule = []            # (start, secs, key)
    last_end = 0.0
    for cue_t, key in sorted(voice_cues):
        line = N.speak(key)
        if line is None:
            continue
        secs = line[1]
        start = max(cue_t + VOICE_DELAY, last_end + VOICE_GAP)
        schedule.append((start, secs, key, start - cue_t))
        last_end = start + secs
    if schedule:
        lags = [d for _, _, _, d in schedule]
        print(f"narration: {len(schedule)} lines, start lag vs marker median {np.median(lags):.1f}s, max {max(lags):.1f}s")

    # Subtitles: one strip per cue, composited under the device; adjacent cues of one line don't fade.
    subs = []
    for start, secs, key, _ in schedule:
        for cs, ce, text in N.line_cues(key):
            subs.append((start + cs, min(start + ce, start + secs + 0.2), text))
    subs.sort()
    for i, (a, b, text) in enumerate(subs):
        joined_prev = i > 0 and a - subs[i - 1][1] < 0.05
        joined_next = i + 1 < len(subs) and subs[i + 1][0] - b < 0.05
        png = B.save(B.subtitle_strip(text), f"sub_{i:03d}.png")
        overlays.append({"png": png, "start": a, "end": b, "fadeIn": 0.0 if joined_prev else SUB_FADE,
                         "fadeOut": 0.0 if joined_next else SUB_FADE, "layer": 3, "x": 0, "y": SUB_Y})

    for a, b, ch in chapter_spans:
        overlays.append({"png": chrome_cache[ch], "start": a, "end": b, "fadeIn": 0.0, "fadeOut": 0.0, "layer": 0})
    for i, (a, b, ck, starts_chapter) in enumerate(caption_spans):
        last_cap = i == len(caption_spans) - 1 or caption_spans[i + 1][3]
        overlays.append({"png": caption_cache[ck], "start": a, "end": b + (0.0 if last_cap else B.CAPTION_FADE),
                         "fadeIn": 0.0 if starts_chapter else B.CAPTION_FADE,
                         "fadeOut": 0.0 if last_cap else B.CAPTION_FADE, "layer": 1})
    overlays.sort(key=lambda o: (o["layer"], o["start"]))

    plan = {
        "width": B.W, "height": B.H, "fps": B.FPS, "duration": t_out,
        "screen": {"x": B.SCREEN[0], "y": B.SCREEN[1], "w": B.SCREEN[2], "h": B.SCREEN[3], "radius": B.SCREEN_RADIUS},
        "background": os.path.join(PNG, "bg.png"),
        "sources": {t.name: t.video for t in takes.values()},
        "segments": segments, "overlays": overlays,
    }
    plan_path = os.path.join(WORK, "plan_story.json")
    json.dump(plan, open(plan_path, "w"), indent=1)
    print(f"plan: {t_out:.1f}s, {len(segments)} segments, {len(overlays)} overlays, {len(caption_cache)} captions, "
          f"{len(schedule)} lines, {len(subs)} subtitle cues")

    srt_path = os.path.splitext(out_path)[0] + ".srt"
    def srt_time(t):
        ms = int(round(t * 1000))
        return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, (a, b, text) in enumerate(subs, 1):
            f.write(f"{i}\n{srt_time(a)} --> {srt_time(b)}\n{text}\n\n")
    print(f"wrote {srt_path}")

    # ---- audio ------------------------------------------------------------------------------
    print("mixing audio…")
    SR = M.SR
    n_total = int(t_out * SR) + SR
    music = np.zeros((n_total, 2), dtype=np.float32)
    fx = np.zeros((n_total, 2), dtype=np.float32)       # chimes + narration (not ducked)
    tracks, chime_buf = {}, {}
    for take, s, e, out_start in audio_pieces:
        if take.audio:
            tmp = os.path.join(WORK, f"a_{take.name}_{int(s * 100)}.wav")
            V3.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", take.video,
                    "-vn", "-ac", "2", "-ar", str(SR), "-f", "wav", tmp])
            with wave.open(tmp) as w:
                data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
            M.place(music, data.reshape(-1, 2), out_start, fade_in=0.05, fade_out=0.05)
            os.remove(tmp)
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
            M.place(music, piece, out_start + (ov_s - s), gain=vol, fade_in=fi, fade_out=fo)
        for ct, variant in take.chimes():
            if s <= ct < e:
                if variant not in chime_buf:
                    chime_buf[variant] = M.chime(variant)
                M.place(fx, chime_buf[variant].copy(), out_start + (ct - s))
    bed = M.load_track("Velvet Cadenza")
    bed_pos = 0
    for a, b, gain in bed_spans:
        n = int((b - a) * SR)
        if bed_pos + n > len(bed):
            bed_pos = 0
        M.place(music, bed[bed_pos:bed_pos + n].copy(), a, gain=gain, fade_in=1.0, fade_out=1.6)
        bed_pos += n + int(6 * SR)

    # Narration at the scheduled times, with the music ducked underneath.
    env = np.ones(n_total, dtype=np.float32)
    ramp = int(DUCK_RAMP * SR)
    for start, secs, key, _ in schedule:
        data, _secs = N.speak(key)
        M.place(fx, data, start, gain=1.0, fade_in=0.01, fade_out=0.03)
        i0 = max(0, int((start - DUCK_RAMP) * SR))
        i1 = min(n_total, int((start + secs + 0.35) * SR))
        env[i0:i1] = np.minimum(env[i0:i1], DUCK)
        # soften the duck edges
        lo, hi = max(0, i0 - ramp), min(n_total, i1 + ramp)
        env[lo:i0] = np.minimum(env[lo:i0], np.linspace(1.0, DUCK, i0 - lo, dtype=np.float32))
        env[i1:hi] = np.minimum(env[i1:hi], np.linspace(DUCK, 1.0, hi - i1, dtype=np.float32))

    mixed = music * env[:, None] + fx
    del music, fx, env
    peak = float(np.max(np.abs(mixed))) or 1.0
    gain = min(2.0, 0.92 / peak)
    mixed = np.clip(np.tanh(mixed * gain * 1.05) / math.tanh(1.05), -1, 1)
    wav_path = os.path.join(WORK, "soundtrack_story.wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((mixed * 32767).astype(np.int16).tobytes())
    del mixed

    video_only = os.path.join(WORK, "video_only_story.mp4")
    if reuse_video and os.path.exists(video_only) and abs(V3.duration(video_only) - t_out) < 0.5:
        print("reusing rendered video…")
    else:
        print("rendering video…")
        subprocess.run([RENDER, plan_path, video_only], check=True)

    print("muxing…")
    V3.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", video_only, "-i", wav_path,
            "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", out_path])
    print(f"wrote {out_path} ({V3.duration(out_path):.1f}s)")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0] if args else os.path.join(REPO, "NoteStalgia-Walkthrough-v5.mp4"), reuse_video="--reuse-video" in sys.argv)
