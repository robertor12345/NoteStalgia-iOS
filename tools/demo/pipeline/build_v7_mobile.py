"""v7 on the phone — every onboarding and admin screen, recorded on an iPhone, narrated in detail.

    m_request  testMobileA_Request                      request → typo caught → code → approval → activation
    m_setup1   testMobileB_SetupOrganisationHomesTeam   organisation → homes (address, wings, export) → team (invites)
    m_setup2   testMobileC_SetupResidentsIpadsReady     resume from the dashboard → residents → iPads → ready → finish
    m_join     testMobileD_ColleagueJoins               Sam accepts the invite
    m_admin    testMobileE_HomeAdminDashboard           the home lead's dashboard, section by section
    m_team     testMobileF_ManageTheTeam                pending invites, staff, suspend / restore / reset PIN

Same engine as build_v7.py / build_story.py (markers → chapter cards, captions, narration, subtitles); this file swaps
the flow list, the cards, the take names and the device rectangle (a phone, not an iPad). Record with the iPhone
simulator booted and no other simulator running:

    tools/demo/reset-backend.sh
    export DEMO_AUDIO_DEVICE=""  TEST_RUNNER_API_BASE_URL=https://notestalgia-api.fitraclesub.workers.dev
    python3 tools/demo/pipeline/narration.py --durations .demo-work/narration-durations.json   # pace follows the voice
    for s in testMobileA_Request:m_request testMobileB_SetupOrganisationHomesTeam:m_setup1 \\
             testMobileC_SetupResidentsIpadsReady:m_setup2 testMobileD_ColleagueJoins:m_join \\
             testMobileE_HomeAdminDashboard:m_admin testMobileF_ManageTheTeam:m_team; do
      TEST_RUNNER_DEMO_NARRATION_FILE=$PWD/.demo-work/narration-durations.json tools/demo/walkthrough.sh "${s%%:*}" "${s##*:}"
    done
    python3 tools/demo/pipeline/build_v7_mobile.py     # → NoteStalgia-Walkthrough-v7-mobile.mp4 + .srt
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build as B            # noqa: E402
import build_story as S      # noqa: E402
import narration as N        # noqa: E402
import narration_mobile      # noqa: E402,F401  (adds the m_* lines to N.SCRIPT)

FLOWS = [
    "Request a workspace",
    "Verify and activate",
    "Organisation",
    "Homes",
    "Team and invites",
    "Residents",
    "iPads and ready",
    "A colleague joins",
    "Home admin dashboard",
    "Managing the team",
]
FLOW_SUBTITLES = [
    "From the sign-in screen, with typos caught on the spot",
    "A code to the work email, approval, and a PIN of your own",
    "Details, address, domains and defaults, a page at a time",
    "Add a home in four pages; export it when you need to",
    "Invite one or many; resend, revoke, scope to homes",
    "A spreadsheet, checked row by row, then imported",
    "Shared tablets, a live checklist and an audit trail",
    "An invite, a preview, a PIN, and the roster",
    "Trends, tiles, wings, groups and sessions in one column",
    "Suspend, restore, reset a PIN: all on the record",
]
B.FLOWS[:] = FLOWS
B.FLOW_SUBTITLES[:] = FLOW_SUBTITLES
S.TAKE_NAMES[:] = ["m_request", "m_setup1", "m_setup2", "m_join", "m_admin", "m_team"]

# A phone is 402×874 pt (0.46), an iPad 820×1180 (0.70): the device column keeps its height and narrows,
# centred in the left half of the frame; the corner radius follows the iPhone's.
B.SCREEN = (275, 40, 410, 890)
B.SCREEN_RADIUS = 54
B.INDEX_Y = 672
N.SCRIPT["intro"] = N.SCRIPT["intro_mobile"]
N.SCRIPT["outro"] = N.SCRIPT["outro_mobile"]


def _line_seconds(key):
    spoken = N.speak(key)
    return spoken[1] if spoken else 0.0


# Cards are held for as long as their narration plus a beat (the lines are long).
S.INTRO_DUR = round(_line_seconds("intro") + 4.5, 1)
B.INTRO_DUR = S.INTRO_DUR
S.OUTRO_DUR = round(_line_seconds("outro") + 4.0, 1)
B.OUTRO_DUR = S.OUTRO_DUR


def intro_card():
    img = B.background(False).convert("RGBA")
    d = ImageDraw.Draw(img)
    f_w = B.font(B.ROUNDED, 150, "Semibold")
    t = "NoteStalgia"
    B.glow_text(img, (B.W / 2 - f_w.getlength(t) / 2, 170), t, f_w, B.TEXT, (211, 111, 176, 200), 26)
    f_s = B.font(B.ROUNDED, 44, "Regular")
    s = "Set-up and admin, on the phone"
    d.text((B.W / 2 - f_s.getlength(s) / 2, 365), s, font=f_s, fill=B.MUTED)
    f_l = B.font(B.SANS, 26, "Semibold")
    l = "VERSION 7  ·  ONBOARDING + ADMIN SCREENS ON THE IPHONE  ·  OCTOBER 2026"
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
        "Could a registered manager set up a whole home from a phone, without our help?",
        "Are the messages under each field clear enough to fix a mistake on the first try?",
        "Is anything on the dashboard too long to read one-handed on a phone?",
        "Are suspend, restore and reset PIN in the right place, and safe enough to tap?",
        "Is anything an admin needs missing from the audit trail?",
    ]
    f_q = B.font(B.SANS, 38, "Regular")
    widest = max(f_q.getlength(q) for q in qs)
    x = B.W / 2 - widest / 2
    for i, q in enumerate(qs):
        y = 400 + i * 78
        d.ellipse((x - 34, y + 17, x - 20, y + 31), fill=B.CYAN)
        d.text((x, y), q, font=f_q, fill=B.TEXT)
    f_f = B.font(B.SANS, 26, "Regular")
    foot = "Prototype build  ·  demo organisation and data  ·  live Cloudflare backend  ·  recorded on iPhone 17 Pro"
    d.text((B.W / 2 - f_f.getlength(foot) / 2, 830), foot, font=f_f, fill=B.DIM)
    B.progress_row(d, 930, len(FLOWS))
    return img


B.intro_card = intro_card
B.outro_card = outro_card

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    S.main(args[0] if args else os.path.join(S.REPO, "NoteStalgia-Walkthrough-v7-mobile.mp4"), reuse_video="--reuse-video" in sys.argv)
