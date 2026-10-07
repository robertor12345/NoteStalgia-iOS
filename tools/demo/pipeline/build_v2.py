"""v2 walkthrough: four takes recorded with the app's demo audio log.

Clip times are "labels" = seconds since that take's REC_START marker; video time = label + OFFSETS[take].
The app's own sounds (music + chimes) come from the audio log and are mixed by mix_v2.py.
"""
import json
import os

import build as B

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
# All intermediates (takes, PNG cards, plans, wav cache) live outside the repo tree unless overridden.
SCRATCH = os.environ.get("DEMO_WORKDIR", os.path.join(REPO, ".demo-work"))
MUSIC = os.path.join(REPO, "App", "Resources", "Music")
V2 = os.path.join(SCRATCH, "v2")
B.PNG = os.path.join(SCRATCH, "png_v2")
PNG = B.PNG

SOURCES = {k: os.path.join(V2, f"take{n}s.mp4") for k, n in zip("abcd", (1, 2, 3, 4))}
TAKE_NO = {"a": 1, "b": 2, "c": 3, "d": 4}
OFFSETS = {"a": 1.4, "b": 1.7, "c": 1.6, "d": 1.5}

GENRE = {
    "Velvet Afterhours": "Jazz", "Velvet Cadenza": "Classical", "Echoes of Yesterday": "Pop",
    "Velvet Highway": "Rock", "Pine Smoke Drift": "Country", "Pine Smoke Drift (1)": "Gospel",
    "Drift Between Rooms": "Soul",
}

CAPTIONS = dict(B.CAPTIONS)
CAPTIONS.update({
    "roster": "Today's roster: pinned, recently seen and 'due a visit' residents come first. Each card shows where they are, when they were last visited and how settled they were.",
    "wing": "Tap a wing and the whole roster focuses on it — the count updates and every section filters to that wing.",
    "search": "Search finds anyone in the home by name, room or wing — results appear right under the field.",
    "profile": "Each profile opens with the one thing a carer needs most — the button to start the resident's calm session — then their trends and playlists.",
    "handoff": "When it's time, the carer opens the calm surface and hands the iPad over.",
    "hold": "To take the iPad back, staff press and hold the corner button. A resident's stray tap only shows a gentle hint — their session carries on.",
    "captured": "What the resident did is captured automatically: time on the surface (stopping the moment staff take over), genres explored, likes, skips and listening time.",
    "done": "Done. The session is saved and the roster already shows the new visit.",
    "clipsall": "Seven clips in all — pop, soul, jazz, rock, classical, country and gospel — in an order tuned to the resident.",
    "result": "Their reactions build a first set of playlists. Here the calm surface opens with jazz, pop and rock.",
    "saved": "Saved. Edith is on the roster — top of Recent — with her first session and starter playlists already logged.",
    "group": "Group mode builds one shared-room playlist from what residents on this roster enjoy — and plays exactly the track it shows.",
})

# (chapter or None, take, start_label, end_label, caption, hold)
CLIPS = [
    (None, "a", 3.0, 9.6, "open", 0),
    (0, "a", 10.0, 19.0, "signin", 0),
    (0, "a", 36.5, 44.0, "welcome", 0),
    (1, "a", 44.0, 50.0, "roster", 0),
    (1, "a", 50.0, 59.0, "wing", 0),
    (1, "a", 88.0, 97.0, "search", 0),
    (2, "a", 113.0, 121.5, "profile", 0),
    (2, "a", 121.5, 131.0, "comfort", 0),
    (2, "a", 145.0, 148.6, "handoff", 0),
    (2, "b", -1.2, 2.0, "handoff", 0),
    (3, "b", 2.0, 8.2, "surface", 0),
    (3, "b", 8.2, 20.0, "play", 0),
    (3, "b", 29.6, 35.0, "sun", 0),
    (3, "b", 54.2, 64.0, "switch", 0),
    (3, "b", 78.2, 84.0, "cloud", 0),
    (3, "b", 84.0, 91.5, "hold", 0),
    (4, "b", 91.5, 99.0, "captured", 0),
    (4, "b", 100.0, 116.0, "tags", 0),
    (4, "b", 131.8, 140.0, "ratings", 0),
    (4, "b", 164.0, 176.0, "insight", 0),
    (4, "b", 176.0, 183.0, "copy", 0),
    (4, "b", 191.5, 196.0, "copy", 0),
    (4, "b", 208.5, 213.5, "done", 0),
    (5, "c", 8.0, 13.5, "newres", 0),
    (5, "c", 24.0, 31.0, "agenat", 0),
    (5, "c", 50.5, 62.5, "clips", 0),
    (5, "c", 62.5, 76.5, "clipstap", 0),
    (5, "c", 96.5, 116.0, "clipsall", 0),
    (5, "c", 116.0, 122.0, "result", 0),
    (5, "c", 131.5, 140.5, "result", 0),
    (5, "c", 140.5, 147.5, "saveres", 0),
    (5, "c", 159.5, 166.0, "saveres", 0),
    (5, "c", 174.0, 178.5, "saveres", 0),
    (5, "c", 194.5, 199.0, "saveres", 0),
    (5, "c", 205.5, 213.0, "saved", 0),
    (6, "d", 0.5, 12.0, "group", 0),
    (6, "d", 19.8, 27.5, "groupctl", 0),
    (6, "d", 27.5, 34.0, "groupfb", 0),
    (6, "d", 44.0, 50.5, "groupfb", 0),
    (6, "d", 63.5, 72.0, "groupsaved", 0),
    (7, "d", 88.5, 96.0, "adminsign", 0),
    (7, "d", 107.5, 117.0, "picker", 0),
    (7, "d", 117.0, 131.0, "dash", 0),
    (7, "d", 139.0, 147.0, "expand", 0),
    (7, "d", 147.0, 161.0, "impact", 0),
]


def rec_start(take):
    with open(os.path.join(V2, f"markers{TAKE_NO[take]}.log")) as fh:
        for line in fh:
            if line.strip().endswith("|REC_START"):
                return float(line.split("|")[0])
    raise ValueError(take)


def load_log():
    with open(os.path.join(V2, "audio4.jsonl")) as fh:
        return [json.loads(l) for l in fh if l.strip()]


def music_intervals(events, take):
    """[(start_label, end_label, title)] for one take."""
    r0 = rec_start(take)
    open_by_player, out = {}, []
    for e in sorted(events, key=lambda e: e["t"]):
        if e["event"] == "music.start":
            title = os.path.splitext(e["file"])[0]
            open_by_player[e["player"]] = (e["t"] - r0, title)
        elif e["event"] == "music.stop" and e["player"] in open_by_player:
            s, title = open_by_player.pop(e["player"])
            out.append((s, e["t"] - r0, title))
    for s, title in open_by_player.values():
        out.append((s, 1e9, title))
    return out


def main():
    os.makedirs(PNG, exist_ok=True)
    B.save(B.background(True), "bg.png")
    events = load_log()
    intervals = {k: music_intervals(events, k) for k in SOURCES}

    segments, overlays = [], []
    t = 0.0

    def add_card(path, dur, take, label):
        nonlocal t
        v = label + OFFSETS[take]
        segments.append({"kind": "card", "src": take, "outStart": t, "outEnd": t + dur, "srcStart": v, "srcEnd": v})
        overlays.append({"png": path, "start": max(0.0, t - B.CARD_FADE), "end": t + dur + B.CARD_FADE,
                         "fadeIn": B.CARD_FADE if t > 0 else 0.0, "fadeOut": B.CARD_FADE, "layer": 2})
        t += dur

    add_card(B.save(B.intro_card(), "intro.png"), B.INTRO_DUR, CLIPS[0][1], CLIPS[0][2])

    chrome_cache, caption_cache = {}, {}
    chapter_spans, caption_spans = [], []
    prev_chapter, prev_clip = "unset", None

    for chapter, take, s, e, cap, hold in CLIPS:
        if chapter != prev_chapter and prev_chapter != "unset" and chapter is not None:
            add_card(B.save(B.chapter_card(chapter), f"chapter_{chapter}.png"), B.CHAPTER_DUR, take, s)
        new_chapter = chapter != prev_chapter
        prev_chapter = chapter
        o = OFFSETS[take]
        dur = (e - s) + hold
        contiguous = prev_clip is not None and prev_clip[1] == take and abs(prev_clip[3] - s) < 0.05 and not new_chapter
        segments.append({"kind": "clip", "src": take, "outStart": t, "outEnd": t + dur,
                         "srcStart": s + o, "srcEnd": e + o, "xfade": 0.0 if (contiguous or new_chapter) else 0.28})

        sub, cursor = [], s
        for (a, b, title) in intervals[take]:
            ov_s, ov_e = max(a, s), min(b, e)
            if ov_e <= ov_s:
                continue
            if ov_s > cursor:
                sub.append((t + cursor - s, t + ov_s - s, None))
            sub.append((t + ov_s - s, t + ov_e - s, (title, GENRE.get(title, ""))))
            cursor = ov_e
        if cursor < e:
            sub.append((t + cursor - s, t + dur, None))

        if chapter not in chrome_cache:
            chrome_cache[chapter] = B.save(B.chrome(chapter), f"chrome_{'open' if chapter is None else chapter}.png")
        if chapter_spans and chapter_spans[-1][2] == chapter:
            chapter_spans[-1][1] = t + dur
        else:
            chapter_spans.append([t, t + dur, chapter])

        for (a, b, np_) in sub:
            if b - a < 0.05:
                continue
            key = (cap, np_)
            if key not in caption_cache:
                caption_cache[key] = B.save(B.caption_layer(CAPTIONS[cap], np_), f"cap_{len(caption_cache):02d}.png")
            if caption_spans and caption_spans[-1][2] == key and abs(caption_spans[-1][1] - a) < 1e-6:
                caption_spans[-1][1] = b
            else:
                caption_spans.append([a, b, key, new_chapter and abs(a - t) < 1e-6])
        t += dur
        prev_clip = (chapter, take, s, e)

    outro = B.save(B.outro_card(), "outro.png")
    last_take, last_e = prev_clip[1], prev_clip[3]
    segments.append({"kind": "card", "src": last_take, "outStart": t, "outEnd": t + B.OUTRO_DUR,
                     "srcStart": last_e + OFFSETS[last_take], "srcEnd": last_e + OFFSETS[last_take]})
    overlays.append({"png": outro, "start": t - B.CARD_FADE, "end": t + B.OUTRO_DUR, "fadeIn": B.CARD_FADE, "fadeOut": 0.0, "layer": 2})
    t += B.OUTRO_DUR

    for (a, b, key) in chapter_spans:
        overlays.append({"png": chrome_cache[key], "start": a, "end": b, "fadeIn": 0.0, "fadeOut": 0.0, "layer": 0})
    for i, (a, b, key, starts_chapter) in enumerate(caption_spans):
        last = i == len(caption_spans) - 1 or caption_spans[i + 1][3]
        overlays.append({"png": caption_cache[key], "start": a, "end": b + (0.0 if last else B.CAPTION_FADE),
                         "fadeIn": 0.0 if starts_chapter else B.CAPTION_FADE,
                         "fadeOut": 0.0 if last else B.CAPTION_FADE, "layer": 1})
    overlays.sort(key=lambda o: (o["layer"], o["start"]))

    plan = {
        "width": B.W, "height": B.H, "fps": B.FPS, "duration": t,
        "screen": {"x": B.SCREEN[0], "y": B.SCREEN[1], "w": B.SCREEN[2], "h": B.SCREEN[3], "radius": B.SCREEN_RADIUS},
        "background": os.path.join(PNG, "bg.png"),
        "sources": SOURCES,
        "segments": segments,
        "overlays": overlays,
        "audio": {"recStart": {k: rec_start(k) for k in SOURCES}, "offsets": OFFSETS,
                  "log": os.path.join(V2, "audio4.jsonl"),
                  "intro": [0.0, B.INTRO_DUR], "outro": [t - B.OUTRO_DUR, t]},
    }
    with open(os.path.join(SCRATCH, "plan_v2.json"), "w") as fh:
        json.dump(plan, fh, indent=1)
    print(f"total {t:.1f}s  segments {len(segments)}  overlays {len(overlays)}  captions {len(caption_cache)}")


if __name__ == "__main__":
    main()
