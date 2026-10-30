"""v7 — what's new since v6, assembled from three takes recorded against the live backend:

    e_live       testStoryPartE_LiveBackend     sign-in → synced profile → group activities → find a song → real-time queue → sleeve
    f_discovery  testStoryPartF_OnlineDiscovery seven real songs in the orb → taste profile → first playlist
    h_group      testStoryPartH_GroupSession    planner from shared tastes → playlist ranked for the room → check-in
    g_admin      testStoryPartG_GroupProgramme  home lead's dashboard → Group programme card
    i_onboarding testStoryPartI_Onboarding      request a workspace → verify → activate → six-step set-up → a supervisor joins

Same engine as build_story.py (markers → chapter cards, captions, narration, subtitles); this file only
swaps the flow list, the cards and the take names, and teaches the mixer to rebuild streamed Apple
previews from the log (the app logs `title` + `url` with every music.start), so the takes are recorded
video-only (DEMO_AUDIO_DEVICE="") and the soundtrack is deterministic.

    tools/demo/reset-backend.sh
    for s in testStoryPartE_LiveBackend:e_live testStoryPartF_OnlineDiscovery:f_discovery testStoryPartH_GroupSession:h_group testStoryPartG_GroupProgramme:g_admin testStoryPartI_Onboarding:i_onboarding; do
      DEMO_AUDIO_DEVICE="" TEST_RUNNER_API_BASE_URL=https://notestalgia-api.fitraclesub.workers.dev tools/demo/walkthrough.sh "${s%%:*}" "${s##*:}"
    done
    python3 tools/demo/pipeline/build_v7.py        # → NoteStalgia-Walkthrough-v7.mp4 + .srt
"""
import hashlib
import json
import os
import subprocess
import sys
import urllib.request
import wave

import numpy as np
from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build as B            # noqa: E402
import build_story as S      # noqa: E402
import build_v3 as V3        # noqa: E402
import mix_v2 as M           # noqa: E402
import narration as N        # noqa: E402
import narration_v7          # noqa: E402,F401  (replaces the v7 lines with the detailed ones)

FLOWS = [
    "A live backend",
    "Synced roster & profile",
    "Group activities",
    "Find a song they love",
    "Real-time song selection",
    "Cover art on the calm surface",
    "Online discovery",
    "Group sessions from shared tastes",
    "Home admin: group programme",
    "A new organisation",
]
FLOW_SUBTITLES = [
    "A Cloudflare Worker behind every tap — offline-first on the iPad",
    "Shared across every iPad in the home",
    "Who joins in, and how they like to take part",
    "A curated catalogue with Apple previews and cover art",
    "Age, origin, liked genres — and songs like the ones they love",
    "The sleeve is the picture",
    "Seven real songs, chosen for her generation",
    "A playlist ranked for the whole room",
    "The group programme at a glance",
    "Request, verify, activate, set up — without an engineer",
]
B.FLOWS[:] = FLOWS
B.FLOW_SUBTITLES[:] = FLOW_SUBTITLES
S.TAKE_NAMES[:] = ["e_live", "f_discovery", "h_group", "g_admin", "i_onboarding"]
# The cards stay up for as long as their (long) narration plus a beat.
S.INTRO_DUR = round((N.speak("intro7") or (None, 25.0))[1] + 4.5, 1)
B.INTRO_DUR = S.INTRO_DUR
S.OUTRO_DUR = round((N.speak("outro7") or (None, 12.0))[1] + 4.0, 1)
B.OUTRO_DUR = S.OUTRO_DUR
B.INDEX_Y = 672          # ten flows → five rows per column (same as build_story)
N.SCRIPT["intro"] = N.SCRIPT["intro7"]
N.SCRIPT["outro"] = N.SCRIPT["outro7"]


def intro_card():
    img = B.background(False).convert("RGBA")
    d = ImageDraw.Draw(img)
    f_w = B.font(B.ROUNDED, 150, "Semibold")
    t = "NoteStalgia"
    B.glow_text(img, (B.W / 2 - f_w.getlength(t) / 2, 170), t, f_w, B.TEXT, (211, 111, 176, 200), 26)
    f_s = B.font(B.ROUNDED, 44, "Regular")
    s = "Sound that takes you back"
    d.text((B.W / 2 - f_s.getlength(s) / 2, 365), s, font=f_s, fill=B.MUTED)
    f_l = B.font(B.SANS, 26, "Semibold")
    l = "WHAT'S NEW IN VERSION 7  ·  IPAD + LIVE BACKEND  ·  OCTOBER 2026"
    B.tracked(d, (B.W / 2 - B.tracked_width(l, f_l, 4) / 2, 450), l, f_l, B.GOLD, 4)
    f_h = B.font(B.SANS, 26, "Semibold")
    h = "IN THIS VIDEO"
    B.tracked(d, (B.W / 2 - B.tracked_width(h, f_h, 4) / 2, 590), h, f_h, B.DIM, 4)
    f_i = B.font(B.SANS, 34, "Regular")
    f_n = B.font(B.SANS, 34, "Semibold")
    colw = 520
    x0 = B.W / 2 - colw
    for i, name in enumerate(FLOWS):
        col, row = divmod(i, (len(FLOWS) + 1) // 2)
        x = x0 + col * colw + 60
        y = 650 + row * 60
        d.text((x, y), f"{i + 1}", font=f_n, fill=B.CYAN)
        d.text((x + 46, y), name, font=f_i, fill=B.TEXT)
    return img


def outro_card():
    img = B.background(False).convert("RGBA")
    d = ImageDraw.Draw(img)
    f_t = B.font(B.ROUNDED, 88, "Semibold")
    t = "Thanks for watching"
    B.glow_text(img, (B.W / 2 - f_t.getlength(t) / 2, 150), t, f_t, B.TEXT, (95, 208, 232, 150), 22)
    f_h = B.font(B.SANS, 30, "Semibold")
    h = "WE'D LOVE YOUR FEEDBACK ON"
    B.tracked(d, (B.W / 2 - B.tracked_width(h, f_h, 4) / 2, 320), h, f_h, B.GOLD, 4)
    qs = [
        "Does the live sync feel reliable enough for a shared iPad on the floor?",
        "Would family searching and adding songs change how music reaches a resident?",
        "Do the song choices after a pick or a sun feel right — and fast enough?",
        "Does cover art inside the orb and behind the glyph help, or distract?",
        "Could a registered manager set up a home with this, without our help?",
    ]
    f_q = B.font(B.SANS, 38, "Regular")
    widest = max(f_q.getlength(q) for q in qs)
    x = B.W / 2 - widest / 2
    for i, q in enumerate(qs):
        y = 400 + i * 78
        d.ellipse((x - 34, y + 17, x - 20, y + 31), fill=B.CYAN)
        d.text((x, y), q, font=f_q, fill=B.TEXT)
    f_f = B.font(B.SANS, 26, "Regular")
    foot = "Prototype build  ·  demo residents and data  ·  live Cloudflare backend  ·  Apple Music previews"
    d.text((B.W / 2 - f_f.getlength(foot) / 2, 830), foot, font=f_f, fill=B.DIM)
    B.progress_row(d, 930, len(FLOWS))
    return img


B.intro_card = intro_card
B.outro_card = outro_card

# ---- streamed previews in the soundtrack --------------------------------------------------------
# The app logs every music.start with `title` and `url`; bundled stems keep going through mix_v2's
# afconvert path, previews are fetched once into the wav cache (they are 30 s AAC on Apple's CDN).
PREVIEW_URLS = {}


def music_intervals(self):
    open_by_player, out = {}, []
    for e in self.events:
        if e["event"] == "music.start":
            title = e.get("title") or os.path.splitext(e["file"])[0]
            if e.get("url", "").startswith("http"):
                PREVIEW_URLS.setdefault(title, e["url"])
            open_by_player[e["player"]] = (self.vt(e["t"]), title, e.get("volume", 0.38))
        elif e["event"] in ("music.stop", "music.end") and e["player"] in open_by_player:
            s, title, vol = open_by_player.pop(e["player"])
            out.append((s, self.vt(e["t"]), title, vol))
    for s, title, vol in open_by_player.values():
        out.append((s, self.duration, title, vol))
    return out


S.StoryTake.music_intervals = music_intervals
_load_bundled = M.load_track


def load_track(title):
    if os.path.exists(os.path.join(M.MUSIC, title + ".mp3")):
        return _load_bundled(title)
    url = PREVIEW_URLS.get(title)
    if not url:
        print(f"  no audio source for '{title}' — silent")
        return np.zeros((M.SR, 2), dtype=np.float32)
    os.makedirs(M.CACHE, exist_ok=True)
    key = hashlib.sha256(url.encode()).hexdigest()[:20]
    src = os.path.join(M.CACHE, f"preview_{key}.m4a")
    out = os.path.join(M.CACHE, f"preview_{key}.wav")
    if not os.path.exists(out):
        if not os.path.exists(src):
            urllib.request.urlretrieve(url, src)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-ac", "2", "-ar", str(M.SR), "-f", "wav", out], check=True)
    with wave.open(out) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        ch = w.getnchannels()
    return data.reshape(-1, ch)


M.load_track = load_track

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    S.main(args[0] if args else os.path.join(S.REPO, "NoteStalgia-Walkthrough-v7.mp4"), reuse_video="--reuse-video" in sys.argv)
