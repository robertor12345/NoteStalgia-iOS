"""Builds the NoteStalgia annotated walkthrough: overlay PNGs + render/audio plans.

Times in CLIPS are "label" times (as on the contact sheets); video time = label + OFFSET.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
# All intermediates (takes, PNG cards, plans, wav cache) live outside the repo tree unless overridden.
SCRATCH = os.environ.get("DEMO_WORKDIR", os.path.join(REPO, ".demo-work"))
MUSIC = os.path.join(REPO, "App", "Resources", "Music")
PNG = os.path.join(SCRATCH, "png")
W, H = 1920, 1080
FPS = 30
OFFSET = 1.0
SOURCES = {
    "a": os.path.join(SCRATCH, "raw.mp4"),
    "b": os.path.join(SCRATCH, "raw2.mp4"),
}

# Device screen placement (source is 1640x2360 portrait).
SCREEN = (170, 40, 695, 1000)
SCREEN_RADIUS = 22
PANEL_X = 960
PANEL_W = 860

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"

GOLD = (230, 196, 122)
CYAN = (143, 227, 240)
PINK = (236, 150, 205)
TEXT = (242, 238, 255)
MUTED = (185, 178, 217)
DIM = (110, 104, 147)

FLOWS = [
    "Supervisor sign-in",
    "Today's roster",
    "Resident profile",
    "Resident calm surface",
    "After the session",
    "New-resident discovery",
    "Group mode",
    "Home admin insights",
]
FLOW_SUBTITLES = [
    "Fast, simple access for care staff",
    "Who to see today, at a glance",
    "Everything a carer needs before a session",
    "The resident's own, wordless music space",
    "The carer takes the iPad back — NoteStalgia drafts the paperwork",
    "Finding the music that lands, with no reading required",
    "One shared playlist for a lounge or day room",
    "Session impact across the whole home",
]

CAPTIONS = {
    "open": "NoteStalgia opens on its signature orb — the calm visual anchor that carries through every screen.",
    "signin": "Care staff sign in with their work email and a 6-digit PIN — quick on a busy floor, nothing long to remember.",
    "welcome": "A brief, calm welcome — then straight into today's roster.",
    "roster": "The roster is curated for today: pinned, recently seen and 'due a visit' residents rise to the top, under a home-wide wellbeing summary.",
    "cards": "Each card shows room, wing, recent carer-observed wellbeing and how the last visit went.",
    "search": "Search finds anyone in the home by name, room or wing.",
    "profile": "Each resident's profile: carer-observed trends, their genre playlists, and songs family know they love.",
    "comfort": "Comfort notes (light, scent, touch), sound preferences and every past session — so any carer can pick up where the last one left off.",
    "handoff": "When it's time, the carer opens the resident's calm surface and hands over the iPad.",
    "surface": "A gentle handoff veil, then the resident's own view: no words — just their music, as floating artwork around the orb.",
    "play": "One tap plays that genre. The orb blooms into full-screen, mood-matched imagery and the ring pulses with the live music.",
    "sun": "Sun = “I like this”. It's remembered, so the song comes round sooner next time.",
    "switch": "Tapping another genre gently folds the imagery back into the orb and re-blooms with the new music.",
    "cloud": "Cloud = “not for me”. The song is skipped and taken out of today's session — there are no wrong answers.",
    "captured": "What the resident did is captured automatically: time on the surface, genres explored, likes, skips and listening time.",
    "tags": "One-tap context tags for the nursing handover — time of day, how they were beforehand, the environment.",
    "ratings": "Then four quick 1–10 carer observations: mood, alertness, emotional presentation and orientation.",
    "insight": "NoteStalgia drafts the write-up: a session narrative, comparison with recent sessions and a suggested next step for the care plan.",
    "copy": "A nursing handover, a family update and a care-plan entry — each one tap to copy into the home's own systems.",
    "done": "Done. The session is saved to the resident's history and the carer is back on the roster.",
    "newres": "Someone new has arrived and nobody knows their music yet. The carer starts a listening discovery.",
    "agenat": "Age and nationality set the running order: music from their teens and twenties first, with a gentle cultural bias.",
    "clips": "Seven short clips — one per genre, each with imagery from its era. The resident simply taps a face: green, amber or red.",
    "clipstap": "Each tap moves straight on to the next clip — no reading, no wrong answers. Left alone, a clip plays for 30 seconds.",
    "clipsall": "Rock, classical, country, gospel: every genre gets a fair hearing, in an order tuned to the resident.",
    "result": "Their reactions build a first set of playlists. Here the calm surface opens with jazz, pop and rock.",
    "saveres": "Back with the carer: add a name and photo so the next person on shift recognises them.",
    "saved": "Saved. Edith is on the roster — top of Recent — with her first session and starter playlists already logged.",
    "group": "Group mode builds one shared-room playlist from the listening data of everyone on this home's roster.",
    "groupctl": "Familiar controls for the carer leading the room — pause, skip, or tap any song in the list.",
    "groupfb": "When the group finishes, four quick ratings — morale, alertness, orientation and engagement — log the session.",
    "groupsaved": "Saved — the latest group check-in is summarised right on the roster.",
    "adminsign": "Home leads and managers sign in with the same email and PIN…",
    "picker": "…and if they look after more than one home, they choose which one to review.",
    "dash": "The home dashboard: sessions, residents reached, average calm and carer-observed wellbeing over the last 14 days.",
    "expand": "Tap any trend to expand it for a closer look.",
    "impact": "Below: impact by wing, residents who are improving or need attention, and every recent session — evidence of impact for the whole home.",
}

# (chapter index or None, src, start_label, end_label, caption, hold_seconds)
CLIPS = [
    (None, "a", 3.8, 10.4, "open", 0),
    (0, "a", 27.6, 36.0, "signin", 0),
    (0, "a", 51.8, 57.8, "welcome", 0),
    (1, "a", 57.8, 65.0, "roster", 0),
    (1, "a", 98.5, 104.5, "cards", 0),
    (1, "a", 138.6, 146.5, "search", 0),
    (2, "a", 157.0, 166.5, "profile", 0),
    (2, "a", 178.6, 190.5, "comfort", 0),
    (2, "a", 198.6, 203.0, "handoff", 0),
    (2, "a", 214.6, 217.0, "handoff", 0),
    (3, "a", 217.0, 226.5, "surface", 0),
    (3, "a", 237.8, 250.5, "play", 0),
    (3, "a", 268.4, 272.6, "sun", 0),
    (3, "a", 272.6, 281.0, "switch", 0),
    (3, "a", 294.6, 303.0, "cloud", 0),
    (4, "a", 303.0, 311.0, "captured", 0),
    (4, "a", 326.6, 334.0, "tags", 0),
    (4, "a", 346.6, 350.0, "ratings", 0),
    (4, "a", 364.6, 370.6, "ratings", 0),
    (4, "a", 389.6, 392.4, "ratings", 0),
    (4, "a", 404.0, 416.0, "insight", 0),
    (4, "a", 425.0, 436.0, "copy", 0),
    (4, "a", 452.8, 458.0, "done", 0),
    (5, "a", 477.6, 482.5, "newres", 0),
    (5, "a", 494.0, 500.6, "agenat", 0),
    (5, "a", 508.6, 521.0, "clips", 0),
    (5, "a", 536.0, 549.0, "clipstap", 0),
    (5, "a", 570.5, 586.0, "clipsall", 0),
    (5, "a", 602.5, 614.0, "result", 0),
    (5, "a", 626.6, 634.6, "result", 0),
    (5, "a", 634.6, 640.5, "saveres", 0),
    (5, "a", 650.0, 654.0, "saveres", 0),
    (5, "a", 712.8, 716.0, "saveres", 0),
    (5, "a", 727.0, 733.0, "saveres", 0),
    (5, "a", 744.0, 748.6, "saveres", 0),
    (5, "a", 769.8, 777.0, "saved", 0),
    (6, "a", 791.6, 803.0, "group", 0),
    (6, "a", 812.6, 821.0, "groupctl", 0),
    (6, "a", 829.6, 837.0, "groupfb", 0),
    (6, "a", 845.6, 853.0, "groupfb", 0),
    (6, "a", 865.6, 867.85, "groupsaved", 4.35),
    (7, "b", 12.6, 23.0, "adminsign", 0),
    (7, "b", 29.2, 35.5, "picker", 0),
    (7, "b", 52.8, 64.0, "dash", 0),
    (7, "b", 64.0, 70.4, "expand", 0),
    (7, "b", 70.4, 86.0, "impact", 0),
]

# In-app music actually playing (label times, source a): (start, end, file, genre)
AUDIO_EVENTS = {
    "a": [
        (239.9, 273.2, "Velvet Afterhours", "Jazz"),
        (273.2, 296.9, "Drift Between Rooms", "Soul"),
        (510.6, 538.8, "Echoes of Yesterday", "Pop"),
        (538.8, 543.6, "Drift Between Rooms", "Soul"),
        (543.6, 572.6, "Velvet Afterhours", "Jazz"),
        (572.6, 576.8, "Velvet Highway", "Rock"),
        (576.8, 581.4, "Velvet Cadenza", "Classical"),
        (581.4, 604.5, "Pine Smoke Drift", "Country"),
        (604.5, 608.6, "Pine Smoke Drift (1)", "Gospel"),
        (628.8, 634.6, "Echoes of Yesterday", "Pop"),
        (793.6, 814.6, "Velvet Cadenza", "Classical"),
        (814.6, 830.6, "Echoes of Yesterday", "Pop"),
    ],
    "b": [],
}

INTRO_DUR = 7.0
CHAPTER_DUR = 2.4
OUTRO_DUR = 10.0
CARD_FADE = 0.45
CAPTION_FADE = 0.3
INDEX_Y = 812       # top of the "THE WALKTHROUGH" flow index in the right-hand panel


def font(path, size, variation="Regular"):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(variation)
    except Exception:
        pass
    return f


def wrap(text, f, width):
    words = text.split(" ")
    lines, line = [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if f.getlength(trial) <= width:
            line = trial
        else:
            lines.append(line)
            line = w
    if line:
        lines.append(line)
    return lines


def tracked(draw, xy, text, f, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += f.getlength(ch) + tracking
    return x


def tracked_width(text, f, tracking):
    return sum(f.getlength(ch) + tracking for ch in text) - tracking


def background(with_device):
    img = Image.new("RGB", (W, H))
    top, bot = (24, 20, 48), (36, 40, 80)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    cx = SCREEN[0] + SCREEN[2] / 2 if with_device else W / 2
    g.ellipse((cx - 520, 540 - 520, cx + 520, 540 + 520), fill=(211, 111, 176, 70))
    g.ellipse((W - 520, -300, W + 300, 420), fill=(95, 208, 232, 38))
    g.ellipse((-300, 700, 500, 1400), fill=(120, 110, 220, 40))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    rnd = random.Random(7)
    sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    s = ImageDraw.Draw(sp)
    for _ in range(260):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        r = rnd.uniform(0.6, 2.2)
        col = rnd.choice([(255, 255, 255), CYAN, PINK])
        alpha = int(rnd.uniform(40, 150))
        if with_device and x > PANEL_X - 30:
            alpha = min(alpha, 45)  # keep the caption column calm and legible
        s.ellipse((x - r, y - r, x + r, y + r), fill=col + (alpha,))
    img = Image.alpha_composite(img, sp.filter(ImageFilter.GaussianBlur(0.6)))
    if with_device:
        x, y, w, h = SCREEN
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((x - 30, y - 10, x + w + 30, y + h + 40), 60, fill=(0, 0, 0, 150))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(28)))
        d = ImageDraw.Draw(img)
        b = 15
        d.rounded_rectangle((x - b, y - b, x + w + b, y + h + b), SCREEN_RADIUS + b, fill=(14, 13, 22, 255), outline=(70, 66, 100, 255), width=2)
        d.rounded_rectangle((x, y, x + w, y + h), SCREEN_RADIUS, fill=(0, 0, 0, 255))
    return img.convert("RGB")


def chrome(chapter):
    """Static right-hand panel for one chapter: header, flow label + title, flow index."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    hdr = font(ROUNDED, 22, "Semibold")
    x = tracked(d, (PANEL_X, 60), "NOTESTALGIA", hdr, GOLD, 5)
    d.text((x + 14, 60), "·   Product walkthrough", font=font(SANS, 22, "Regular"), fill=MUTED)
    label = f"FLOW {chapter + 1} OF {len(FLOWS)}" if chapter is not None else "OPENING"
    tracked(d, (PANEL_X, 146), label, font(SANS, 24, "Semibold"), CYAN, 4)
    title = FLOWS[chapter] if chapter is not None else "Welcome to NoteStalgia"
    d.text((PANEL_X, 180), title, font=font(ROUNDED, 60, "Semibold"), fill=TEXT)
    d.rounded_rectangle((PANEL_X, 276, PANEL_X + 110, 280), 2, fill=GOLD)
    # Flow index — two columns.
    f_num = font(SANS, 20, "Semibold")
    f_lab = font(SANS, 23, "Regular")
    f_lab_cur = font(SANS, 23, "Semibold")
    d.text((PANEL_X, INDEX_Y), "THE WALKTHROUGH", font=font(SANS, 18, "Semibold"), fill=DIM)
    for i, name in enumerate(FLOWS):
        col, row = divmod(i, 4)
        cx = PANEL_X + col * 440
        cy = INDEX_Y + 44 + row * 50
        r = 15
        if chapter is not None and i == chapter:
            d.ellipse((cx, cy, cx + 2 * r, cy + 2 * r), fill=CYAN)
            numc, labc, lf = (20, 18, 40), TEXT, f_lab_cur
        elif chapter is not None and i < chapter:
            d.ellipse((cx, cy, cx + 2 * r, cy + 2 * r), outline=GOLD, width=2)
            numc, labc, lf = GOLD, MUTED, f_lab
        else:
            d.ellipse((cx, cy, cx + 2 * r, cy + 2 * r), outline=DIM, width=2)
            numc, labc, lf = DIM, DIM, f_lab
        n = str(i + 1)
        d.text((cx + r - f_num.getlength(n) / 2, cy + 3), n, font=f_num, fill=numc)
        d.text((cx + 2 * r + 14, cy + 1), name, font=lf, fill=labc)
    return img


def caption_layer(text, now_playing):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    size = 38 if len(text) <= 150 else 34 if len(text) <= 210 else 31
    f = font(SANS, size, "Regular")
    lines = wrap(text, f, PANEL_W)
    y = 318
    for line in lines:
        d.text((PANEL_X, y), line, font=f, fill=TEXT)
        y += int(size * 1.42)
    if now_playing:
        title, genre = now_playing
        fy = max(y + 34, 600)
        f_np = font(SANS, 25, "Regular")
        f_np_b = font(SANS, 25, "Semibold")
        f_note = font(SANS, 28, "Semibold")
        parts = [("Now playing   ", f_np, MUTED), (title, f_np_b, TEXT), ("   ·   " + genre, f_np, MUTED)]
        icon_w = 34
        width = icon_w + sum(fp.getlength(t) for t, fp, _ in parts)
        d.rounded_rectangle((PANEL_X, fy, PANEL_X + width + 48, fy + 56), 28, fill=(255, 255, 255, 22), outline=(255, 255, 255, 60), width=1)
        # Small equalizer glyph (the system font has no music-note glyph).
        for k, bh in enumerate((12, 22, 16, 26)):
            x0 = PANEL_X + 24 + k * 6
            d.rounded_rectangle((x0, fy + 41 - bh, x0 + 3, fy + 41), 1, fill=PINK)
        x = PANEL_X + 24 + icon_w
        for t, fp, c in parts:
            d.text((x, fy + 13), t, font=fp, fill=c)
            x += fp.getlength(t)
    return img


SUB_W, SUB_H = 1920, 150
SUB_MAX_WIDTH = 1500


def subtitle_strip(text):
    """One subtitle cue as a transparent 1920×150 strip: centred SF Medium 40 px, white with a dark
    outline, up to two lines. The compositor draws it at its own size at the plan's x/y."""
    img = Image.new("RGBA", (SUB_W, SUB_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(SANS, 40, "Medium")
    lines = wrap(text, f, SUB_MAX_WIDTH)[:2]
    lh = 50
    y = (SUB_H - lh * len(lines)) / 2
    for line in lines:
        x = SUB_W / 2 - f.getlength(line) / 2
        d.text((x, y), line, font=f, fill=(246, 244, 255), stroke_width=2, stroke_fill=(16, 13, 26, 235))
        y += lh
    return img


def progress_row(d, y, current):
    n = len(FLOWS)
    gap = 46
    x0 = W / 2 - (n - 1) * gap / 2
    for i in range(n):
        cx = x0 + i * gap
        r = 9 if i == current else 6
        col = CYAN if i == current else (GOLD if current is not None and i < current else DIM)
        d.ellipse((cx - r, y - r, cx + r, y + r), fill=col)


def chapter_card(i):
    img = background(False).convert("RGBA")
    d = ImageDraw.Draw(img)
    lab = f"FLOW {i + 1} OF {len(FLOWS)}"
    f_lab = font(SANS, 30, "Semibold")
    tracked(d, (W / 2 - tracked_width(lab, f_lab, 6) / 2, 400), lab, f_lab, CYAN, 6)
    f_t = font(ROUNDED, 104, "Semibold")
    t = FLOWS[i]
    d.text((W / 2 - f_t.getlength(t) / 2, 450), t, font=f_t, fill=TEXT)
    f_s = font(SANS, 38, "Regular")
    s = FLOW_SUBTITLES[i]
    d.text((W / 2 - f_s.getlength(s) / 2, 600), s, font=f_s, fill=MUTED)
    progress_row(d, 760, i)
    return img


def glow_text(img, xy, text, f, fill, glow_col, radius):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=f, fill=glow_col)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius)))
    ImageDraw.Draw(img).text(xy, text, font=f, fill=fill)


def intro_card():
    img = background(False).convert("RGBA")
    d = ImageDraw.Draw(img)
    f_w = font(ROUNDED, 150, "Semibold")
    t = "NoteStalgia"
    glow_text(img, (W / 2 - f_w.getlength(t) / 2, 170), t, f_w, TEXT, (211, 111, 176, 200), 26)
    f_s = font(ROUNDED, 44, "Regular")
    s = "Sound that takes you back"
    d.text((W / 2 - f_s.getlength(s) / 2, 365), s, font=f_s, fill=MUTED)
    f_l = font(SANS, 26, "Semibold")
    l = "PRODUCT WALKTHROUGH  ·  IPAD PROTOTYPE  ·  OCTOBER 2026"
    tracked(d, (W / 2 - tracked_width(l, f_l, 4) / 2, 450), l, f_l, GOLD, 4)
    f_h = font(SANS, 26, "Semibold")
    h = "IN THIS VIDEO"
    tracked(d, (W / 2 - tracked_width(h, f_h, 4) / 2, 590), h, f_h, DIM, 4)
    f_i = font(SANS, 34, "Regular")
    f_n = font(SANS, 34, "Semibold")
    colw = 520
    x0 = W / 2 - colw
    for i, name in enumerate(FLOWS):
        col, row = divmod(i, 4)
        x = x0 + col * colw + 60
        y = 650 + row * 60
        d.text((x, y), f"{i + 1}", font=f_n, fill=CYAN)
        d.text((x + 46, y), name, font=f_i, fill=TEXT)
    return img


def outro_card():
    img = background(False).convert("RGBA")
    d = ImageDraw.Draw(img)
    f_t = font(ROUNDED, 88, "Semibold")
    t = "Thanks for watching"
    glow_text(img, (W / 2 - f_t.getlength(t) / 2, 150), t, f_t, TEXT, (95, 208, 232, 150), 22)
    f_h = font(SANS, 30, "Semibold")
    h = "WE'D LOVE YOUR FEEDBACK ON"
    tracked(d, (W / 2 - tracked_width(h, f_h, 4) / 2, 320), h, f_h, GOLD, 4)
    qs = [
        "Does the resident's calm surface feel simple enough to use unaided?",
        "Would the auto-drafted handover and care-plan notes save teams time?",
        "What should a home manager see first on the insights dashboard?",
        "Anything that felt slow, confusing or missing.",
    ]
    f_q = font(SANS, 38, "Regular")
    widest = max(f_q.getlength(q) for q in qs)
    x = W / 2 - widest / 2
    for i, q in enumerate(qs):
        y = 400 + i * 78
        d.ellipse((x - 34, y + 17, x - 20, y + 31), fill=CYAN)
        d.text((x, y), q, font=f_q, fill=TEXT)
    f_f = font(SANS, 26, "Regular")
    foot = "Prototype build  ·  demo residents and data  ·  everything runs on the iPad, no backend yet"
    d.text((W / 2 - f_f.getlength(foot) / 2, 830), foot, font=f_f, fill=DIM)
    progress_row(d, 930, len(FLOWS))
    return img


def save(img, name):
    path = os.path.join(PNG, name)
    img.save(path)
    return path


def main():
    os.makedirs(PNG, exist_ok=True)
    save(background(True), "bg.png")

    segments, overlays, audio = [], [], []
    t = 0.0

    def add_card(path, dur, next_clip):
        nonlocal t
        src, start = next_clip[1], next_clip[2]
        segments.append({"kind": "card", "src": src, "outStart": t, "outEnd": t + dur,
                         "srcStart": start + OFFSET, "srcEnd": start + OFFSET})
        overlays.append({"png": path, "start": max(0.0, t - CARD_FADE), "end": t + dur + CARD_FADE,
                         "fadeIn": CARD_FADE if t > 0 else 0.0, "fadeOut": CARD_FADE, "layer": 2})
        t += dur

    intro = save(intro_card(), "intro.png")
    add_card(intro, INTRO_DUR, CLIPS[0])

    chrome_cache, caption_cache = {}, {}
    prev_chapter = "unset"
    prev_clip = None
    chapter_spans = []
    caption_spans = []

    for ci, clip in enumerate(CLIPS):
        chapter, src, s, e, cap, hold = clip
        if chapter != prev_chapter and chapter is not None and prev_chapter != "unset":
            add_card(save(chapter_card(chapter), f"chapter_{chapter}.png"), CHAPTER_DUR, clip)
        elif chapter != prev_chapter and prev_chapter == "unset":
            pass
        new_chapter = chapter != prev_chapter
        prev_chapter = chapter

        dur = (e - s) + hold
        contiguous = prev_clip is not None and prev_clip[1] == src and abs(prev_clip[3] - s) < 0.05 and not new_chapter
        seg = {"kind": "clip", "src": src, "outStart": t, "outEnd": t + dur,
               "srcStart": s + OFFSET, "srcEnd": e + OFFSET,
               "xfade": 0.0 if (contiguous or new_chapter) else 0.28}
        if hold > 0:
            # The decoder can't reach the last frames of a truncated take — hold on a clean still.
            seg["still"] = os.path.join(PNG, "hold_group.png")
        segments.append(seg)

        # Audio for this clip.
        events = AUDIO_EVENTS.get(src, [])
        sub = []  # (outStart, outEnd, now_playing)
        cursor = s
        for (as_, ae, file, genre) in events:
            ov_s, ov_e = max(as_, s), min(ae, e)
            if ov_e <= ov_s:
                continue
            extra = hold if abs(ov_e - e) < 1e-6 else 0.0
            audio.append({"file": os.path.join(MUSIC, file + ".mp3"), "outStart": t + (ov_s - s),
                          "fileOffset": ov_s - as_, "duration": (ov_e - ov_s) + extra})
            if ov_s > cursor:
                sub.append((t + (cursor - s), t + (ov_s - s), None))
            sub.append((t + (ov_s - s), t + (ov_e - s) + extra, (file, genre)))
            cursor = ov_e
        if cursor < e:
            sub.append((t + (cursor - s), t + dur, None))

        key_chrome = chapter
        if key_chrome not in chrome_cache:
            chrome_cache[key_chrome] = save(chrome(chapter), f"chrome_{'open' if chapter is None else chapter}.png")
        if chapter_spans and chapter_spans[-1][2] == key_chrome:
            chapter_spans[-1][1] = t + dur
        else:
            chapter_spans.append([t, t + dur, key_chrome])

        for (a, b, np_) in sub:
            key = (cap, np_)
            if key not in caption_cache:
                caption_cache[key] = save(caption_layer(CAPTIONS[cap], np_), f"cap_{len(caption_cache):02d}.png")
            if caption_spans and caption_spans[-1][2] == key and abs(caption_spans[-1][1] - a) < 1e-6:
                caption_spans[-1][1] = b
            else:
                caption_spans.append([a, b, key, new_chapter and abs(a - t) < 1e-6])
        t += dur
        prev_clip = clip

    outro = save(outro_card(), "outro.png")
    segments.append({"kind": "card", "src": prev_clip[1], "outStart": t, "outEnd": t + OUTRO_DUR,
                     "srcStart": prev_clip[3] + OFFSET, "srcEnd": prev_clip[3] + OFFSET})
    overlays.append({"png": outro, "start": t - CARD_FADE, "end": t + OUTRO_DUR, "fadeIn": CARD_FADE, "fadeOut": 0.0, "layer": 2})
    t += OUTRO_DUR
    total = t

    for (a, b, key) in chapter_spans:
        overlays.append({"png": chrome_cache[key], "start": a, "end": b, "fadeIn": 0.0, "fadeOut": 0.0, "layer": 0})
    for i, (a, b, key, starts_chapter) in enumerate(caption_spans):
        last = i == len(caption_spans) - 1 or caption_spans[i + 1][3]
        overlays.append({"png": caption_cache[key], "start": a, "end": b + (0.0 if last else CAPTION_FADE),
                         "fadeIn": 0.0 if starts_chapter else CAPTION_FADE,
                         "fadeOut": 0.0 if last else CAPTION_FADE, "layer": 1})

    overlays.sort(key=lambda o: (o["layer"], o["start"]))
    plan = {
        "width": W, "height": H, "fps": FPS, "duration": total,
        "screen": {"x": SCREEN[0], "y": SCREEN[1], "w": SCREEN[2], "h": SCREEN[3], "radius": SCREEN_RADIUS},
        "background": os.path.join(PNG, "bg.png"),
        "sources": SOURCES,
        "segments": segments,
        "overlays": overlays,
    }
    with open(os.path.join(SCRATCH, "plan.json"), "w") as fh:
        json.dump(plan, fh, indent=1)
    bed = {"file": os.path.join(MUSIC, "Velvet Cadenza.mp3"), "volume": 0.12, "duration": total}
    with open(os.path.join(SCRATCH, "audio.json"), "w") as fh:
        json.dump({"duration": total, "musicVolume": 0.9, "bed": bed, "segments": audio}, fh, indent=1)
    print(f"total {total:.1f}s  segments {len(segments)}  overlays {len(overlays)}  audio {len(audio)}  captions {len(caption_cache)}")


if __name__ == "__main__":
    main()
