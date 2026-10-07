"""Rebuilds the app's own soundtrack for the v2 walkthrough from the demo audio log.

Music: the bundled MP3 that was playing, from the logged start offset, at the logged player volume.
Chimes: re-synthesised with the exact parameters from `DiscoveryEtherealTapChime` (button / light /
success), placed at the logged tap times. Only the title and closing cards get a soft bed (a bundled
app track); everything else is exactly what the app played.
"""
import json
import math
import os
import subprocess
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
# All intermediates (takes, PNG cards, plans, wav cache) live outside the repo tree unless overridden.
SCRATCH = os.environ.get("DEMO_WORKDIR", os.path.join(REPO, ".demo-work"))
MUSIC = os.path.join(REPO, "App", "Resources", "Music")
SR = 44100
CACHE = os.path.join(SCRATCH, "wav_cache")
CLIP_FADE = 0.12  # de-click at edit points


def load_track(title):
    os.makedirs(CACHE, exist_ok=True)
    out = os.path.join(CACHE, title.replace(" ", "_").replace("(", "").replace(")", "") + ".wav")
    if not os.path.exists(out):
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "2",
                        os.path.join(MUSIC, title + ".mp3"), out], check=True)
    with wave.open(out) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        ch = w.getnchannels()
    return data.reshape(-1, ch)


def chime(variant):
    """Port of ChimeEngine.render — same frequencies, envelope and level."""
    params = {
        "button": (0.34, (294.0, 294.0 * 1.498, 294.0 * 2.01), (0.16, 5.0, 0.020, 0.04)),
        "light": (0.46, (330.0, 330.0 * 1.498, 330.0 * 2.015), (0.20, 4.6, 0.026, 0.07)),
        "success": (0.74, (392.0, 392.0 * 1.335, 392.0 * 2.0), (0.26, 3.35, 0.040, 0.06)),
    }
    duration, (f1, f2, f3), (volume, decay, attack_s, swirl_amt) = params[variant]
    t = np.arange(int(SR * duration)) / SR
    env = np.minimum(1, t / attack_s) * np.exp(-t * decay)
    swirl = np.sin(2 * math.pi * 9.7 * t) * swirl_amt
    body = (np.sin(2 * math.pi * f1 * t) * 0.74 + np.sin(2 * math.pi * f2 * t) * 0.42
            + np.sin(2 * math.pi * f3 * t) * 0.14)
    s = (body * env * (1 + swirl) * volume).astype(np.float32)
    return np.stack([s, s], axis=1)


def place(buf, src, at, gain=1.0, fade_in=0.0, fade_out=0.0):
    i0 = int(round(at * SR))
    if i0 >= len(buf):
        return
    if i0 < 0:
        src = src[-i0:]
        i0 = 0
    n = min(len(src), len(buf) - i0)
    if n <= 0:
        return
    seg = src[:n] * gain
    if fade_in > 0:
        k = min(n, int(fade_in * SR))
        seg[:k] *= np.linspace(0, 1, k, dtype=np.float32)[:, None]
    if fade_out > 0:
        k = min(n, int(fade_out * SR))
        seg[n - k:] *= np.linspace(1, 0, k, dtype=np.float32)[:, None]
    buf[i0:i0 + n] += seg


def main(plan_path, out_wav):
    plan = json.load(open(plan_path))
    audio = plan["audio"]
    total = plan["duration"]
    buf = np.zeros((int(total * SR) + SR, 2), dtype=np.float32)
    events = [json.loads(l) for l in open(audio["log"]) if l.strip()]
    events.sort(key=lambda e: e["t"])
    rec, offs = audio["recStart"], audio["offsets"]

    def vtime(take, epoch):
        return epoch - rec[take] + offs[take]

    # Music intervals per take in video time: (start, end, title, volume)
    intervals = {}
    for take in rec:
        open_p, out = {}, []
        for e in events:
            if e["event"] == "music.start":
                open_p[e["player"]] = (vtime(take, e["t"]), os.path.splitext(e["file"])[0], e.get("volume", 0.38))
            elif e["event"] == "music.stop" and e["player"] in open_p:
                s, title, vol = open_p.pop(e["player"])
                out.append((s, vtime(take, e["t"]), title, vol))
        intervals[take] = out
    chimes = {take: [(vtime(take, e["t"]), e["variant"]) for e in events if e["event"] == "chime"] for take in rec}

    tracks, chime_buf = {}, {}
    placed_music = placed_chimes = 0
    for seg in plan["segments"]:
        if seg["kind"] != "clip":
            continue
        take, s, e, T = seg["src"], seg["srcStart"], seg["srcEnd"], seg["outStart"]
        for (a, b, title, vol) in intervals[take]:
            ov_s, ov_e = max(a, s), min(b, e)
            if ov_e - ov_s < 0.05:
                continue
            if title not in tracks:
                tracks[title] = load_track(title)
            data = tracks[title]
            i0 = int((ov_s - a) * SR)
            piece = data[i0:i0 + int((ov_e - ov_s) * SR)].copy()
            fi = CLIP_FADE if ov_s > a + 0.01 else 0.02
            fo = CLIP_FADE if ov_e < b - 0.01 else 0.02
            place(buf, piece, T + (ov_s - s), gain=vol, fade_in=fi, fade_out=fo)
            placed_music += 1
        for (ct, variant) in chimes[take]:
            if s <= ct < e:
                if variant not in chime_buf:
                    chime_buf[variant] = chime(variant)
                # Let a chime ring out past the cut, but not beyond the clip by more than its length.
                place(buf, chime_buf[variant].copy(), T + (ct - s))
                placed_chimes += 1

    # Soft bed under the title and closing cards only — the app's own classical stem.
    bed = load_track("Velvet Cadenza")
    for (a, b) in (audio["intro"], audio["outro"]):
        n = int((b - a) * SR)
        place(buf, bed[:n].copy(), a, gain=0.16, fade_in=1.2, fade_out=2.0)

    # Master: lift to a comfortable listening level, soft-limit peaks.
    peak = float(np.max(np.abs(buf))) or 1.0
    gain = min(2.6, 0.89 / peak)
    out = np.tanh(buf * gain * 1.05) / math.tanh(1.05)
    out = np.clip(out, -1, 1)
    pcm = (out * 32767).astype(np.int16)
    with wave.open(out_wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"music pieces {placed_music}, chimes {placed_chimes}, master gain {gain:.2f}, duration {len(pcm)/SR:.1f}s")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
