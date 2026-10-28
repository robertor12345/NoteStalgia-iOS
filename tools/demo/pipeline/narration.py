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
    "planner": (6,
        "Group activities start with a plan: the app suggests an activity built around shared tastes, flags who has been overlooked, and staff choose who joins.",
        "Group activities now start with a plan. The app suggests an activity built around what residents respond to, flags anyone who has "
        "been overlooked, and staff choose who joins — every suggestion is just a suggestion."),
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
    # --- Part D · Care at home (flow 9)
    "home_open": (8,
        "NoteStalgia isn't only for care homes. A family member or a private carer can use the same app at home, for one person.",
        "NoteStalgia isn't only for care homes. A family member or a private carer can use the same app at home, for one person. "
        "It starts from the same sign-in screen."),
    "home_signup": (8,
        "Create an account: a name, their own email, family member or private carer, and a six-digit PIN. In the prototype, everything stays on the iPad.",
        "They create an account: a name, their own email, whether they're family or a private carer, and a six digit PIN, entered twice. "
        "In this prototype everything stays on the iPad."),
    "home_register": (8,
        "Who are you caring for? A name, their age and background, and an optional photo — the same details that shape the music in a care home.",
        "Then: who are you caring for? A name, their age and their background, and an optional photo. These are the same details that "
        "shape the music for a resident in a care home."),
    "home_choice": (8,
        "Run the listening discovery now, or set up without it and run it later from the home screen.",
        "They can run the listening discovery straight away, or set up without it and run it later from the home screen."),
    "home_home": (8,
        "The household home screen: one person, the calm surface a tap away, their insights and trends, the full profile, and the listening discovery.",
        "This is the household home screen. One person. The calm surface is one tap away, and below it their insights and trends, "
        "their full profile with playlists and comfort notes, and the listening discovery."),
    "home_surface": (8,
        "The calm surface is exactly the same as in a care home — their music as floating artwork, the sun and the cloud, and press-and-hold to take the iPad back.",
        "The calm surface is exactly the same as in a care home: their music as floating artwork, the sun and the cloud, "
        "and the press and hold to take the iPad back."),
    "home_observe": (8,
        "And the same quick observations afterwards. Each one builds their history.",
        "And the same quick observations afterwards — mood, alertness, emotional presentation and orientation. Each one builds their history."),
    "home_summary": (8,
        "The session summary, with the write-up in a family voice. Done takes the carer back to the home screen.",
        "The session summary is the same too, with the write-up in a family voice ready to share. Done takes the carer back to the home screen."),
    "home_insights1": (8,
        "Insights and trends now holds the first session.",
        "Insights and trends now holds Arun's first session. The trends build from here."),
    "home_demo": (8,
        "After a couple of weeks it looks like this. Claire cares for her father Harold at home.",
        "After a couple of weeks it looks like this. Claire is a family member who cares for her father Harold at home, and signs in with her own account."),
    "home_insights2": (8,
        "Trends over fourteen days, totals including time with music, the carer's own observations, and what Harold responds to — the same measures a care home sees, for one person.",
        "Harold's insights: trends over the last fourteen days, totals including time with music, Claire's own observations as averages, "
        "and what Harold responds to. The same measures a care home sees, for one person."),
    "home_next": (8,
        "A suggested next step and every recent session. The same taps, the same evidence — at home.",
        "A suggested next step, and every recent session with how it compared. The same taps, the same evidence — at home."),
    "home_surface2": (8,
        "Taking the iPad back is the same press and hold — nothing for the family to learn twice.",
        "Taking the iPad back is the same press and hold. Nothing for the family to learn twice."),
    "home_observe2": (8,
        "Four ratings, each moving on to the next, then save.",
        "Four ratings, each one moving straight on to the next, then save."),
    "home_summary2": (8,
        "The family write-up copies into a message, just as a care home copies a handover.",
        "The family write-up copies into a message, just as a care home would copy a handover."),
    "home_insights1b": (8,
        "One session on file; averages and trends fill in as the history grows.",
        "One session on file so far. Averages and trends fill in as the history grows."),
    "home_demo2": (8,
        "Same welcome, same home screen — Harold's details and two weeks of sessions.",
        "The same welcome and the same home screen, with Harold's details and two weeks of sessions behind them."),
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
        "signing in to the home manager's dashboard, and then the same app used at home by a family — nine flows, end to end, "
        "exactly as they happen on the iPad."),
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
    "home_surface": [(15.0, "home_surface2")],
    "home_observe": [(13.0, "home_observe2")],
    "home_summary": [(12.0, "home_summary2")],
    "home_insights1": [(11.0, "home_insights1b")],
    "home_demo": [(13.0, "home_demo2")],
}


# ---- v7: what's new since v6 (tools/demo/pipeline/build_v7.py) — flow indices refer to build_v7.FLOWS ----
SCRIPT.update({
    "intro7": (None, "",
        "NoteStalgia, version seven. Since the last walkthrough the iPad has gained a real backend, a song catalogue "
        "with Apple previews and cover art, a recommender that learns in real time, and a way for a new care "
        "organisation to set itself up without anyone from our side. This video shows only what is new, with a pause "
        "after every tap so you can follow along."),
    "outro7": (None, "",
        "Thanks for watching. We'd love your feedback on these five questions. Everything you have seen runs on the "
        "iPad against a live backend, with demo residents and demo data."),
    "v7_open": (0,
        "Same orb, same calm opening — but every tap now talks to a live server.",
        "The same calm opening. Behind it, every tap now talks to a live server: a Cloudflare Worker and a database on "
        "the free tier, with the iPad working offline first and syncing whenever it can."),
    "v7_signin": (0,
        "Sign-in is checked by the server — the PIN is never stored on the iPad.",
        "Max signs in as before, with a work email and a six digit PIN. Now the server checks it: the PIN is hashed with "
        "a secret the iPad never sees, and five wrong attempts lock the account."),
    "v7_welcome": (0,
        "Syncing: the iPad pulls Maple Lodge from the server.",
        "While the welcome plays, the iPad pulls Maple Lodge from the server and caches it, so the roster keeps working "
        "offline."),
    "v7_roster": (1,
        "The roster you know — now built from synced data. A session saved on one iPad reaches every other.",
        "This is the same roster, built from synced data. A session saved on one iPad appears on every other iPad in "
        "the home, and anything done offline is pushed when the network is back."),
    "v7_profile": (1,
        "Irene's profile, from the server: observations, playlists on file, comfort notes.",
        "Irene's profile comes from the server too: carer observations, playlists on file and comfort notes, exactly as "
        "staff left them on another device."),
    "v7_group": (2,
        "New: Group activities — how often Irene joins in, the last activity, and how engaged she was.",
        "New since the last walkthrough: a Group activities card. It shows how often Irene has joined a group activity in "
        "the last fortnight, which one was last, and how engaged she was."),
    "v7_comfort": (2,
        "'In company' tells the group planner how she likes to take part — Small groups here. Saved to the server at once.",
        "In company tells the group planner how she likes to take part. Setting her to small groups means the planner only "
        "suggests her for smaller sessions. The change is saved to the server straight away."),
    "v7_songs": (3,
        "New: 'Find a song they love' — a curated catalogue of songs from residents' younger years.",
        "Also new: Find a song they love. Family and staff can search a curated catalogue of more than one hundred and "
        "sixty songs from residents' younger years, each with an Apple Music preview."),
    "v7_search": (3,
        "Results show the sleeve, artist, year and the genre glyph the song will live under, with a link to Apple Music.",
        "Searching for Vera Lynn. Each result shows the cover art, the artist, the year, and the genre glyph the song will "
        "live under, with a link to the full song on Apple Music."),
    "v7_preview": (3,
        "Tap the sleeve to hear a 30-second preview before adding it.",
        "Tapping the sleeve plays a thirty second preview, so a carer can check it is the right recording before adding it."),
    "v7_add": (4,
        "Add files the song on Irene's profile — and tells the recommender, in real time.",
        "Add files the song on Irene's profile. In the same moment the iPad tells the recommender: a staff pick is strong "
        "evidence, and the catalogue grows around the artist so there are similar songs to offer."),
    "v7_added": (4,
        "Within seconds the server has re-ranked her Pop queue: this song first, then more Vera Lynn, then British pop of her era.",
        "Back on the profile, the song sits with her suggested likes. Within seconds the server has re-ranked her Pop queue "
        "from four things: her age, where she is from, the genres she has responded to, and songs like the ones she loves. "
        "This song first, then more from Vera Lynn, then British pop of her era."),
    "v7_added2": (4,
        "Real time means every staff pick, every sun and every session re-ranks the queues within seconds.",
        "That is what real time means here: every staff pick, every sun and every finished session re-ranks her queues "
        "within seconds, and the next tap plays the new order."),
    "v7_surface": (5,
        "On the calm surface a Pop glyph has appeared, built from the new playlist.",
        "Opening her calm surface. A Pop glyph has appeared, built from the new playlist."),
    "v7_pop": (5,
        "We'll Meet Again plays — and the record sleeve fills the screen behind the glyph.",
        "A tap on the glyph plays We'll Meet Again, streamed from Apple, and the record sleeve fills the screen behind the "
        "glyph. For a resident, the picture is the song."),
    "v7_next": (5,
        "Swipe: the next song is more Vera Lynn, chosen by the model, with its own sleeve.",
        "A swipe moves to the next song. It is more Vera Lynn, chosen by the model because she likes her, with its own "
        "sleeve. Each preview plays once and the queue moves on by itself."),
    "v7_sun": (5,
        "The sun is a signal too: it raises this song and its genre for next time.",
        "The sun is a signal too. It raises this song and its genre in her profile, and the next session will reflect it."),
    "v7_staffkey": (5,
        "Press and hold to take the iPad back — the session and its signals go to the server.",
        "Pressing and holding the key takes the iPad back. The session is saved to the server, and the listening signals "
        "go with it."),
    "v7_summary": (5,
        "The summary as before — and her queues are refreshed behind the scenes.",
        "The session summary is as before. Behind the scenes the signals have been applied and her queues refreshed, so "
        "the next session starts from what she responded to today."),
    "v7_disc_start": (6,
        "Discovery is now online: the server plans seven real songs for Irene's age and origin.",
        "Discovery is now online. Instead of seven fixed clips, the server plans seven real songs for Irene's age and "
        "origin: one per genre, the most familiar song of her generation in each."),
    "v7_disc_orb": (6,
        "The song's own cover art fills the orb; the small caption tells staff what is playing.",
        "The song's own cover art fills the orb behind the three faces, and a small caption at the bottom tells staff "
        "what is playing: title, artist and year."),
    "v7_disc_tap": (6,
        "Each face is sent to the server as evidence for the genre, the decade and the song.",
        "Each face goes to the server as evidence: for the genre, for the decade, and for the song itself."),
    "v7_disc_more": (6,
        "A red lowers a genre without removing it; a green brings its playlist forward. Slot three is the genre the model knows least.",
        "A red face lowers a genre without removing it. A green brings that genre's playlist forward. Slot three is always "
        "the genre the model knows least about, so every pass teaches it something."),
    "v7_disc_result": (6,
        "The faces become a taste profile: playlists for the genres she enjoyed, and a queue for every glyph.",
        "At the end the faces become a taste profile. Playlists are written for the genres she enjoyed, and every glyph "
        "gets a queue, with a short retry queue even for a genre she turned down."),
    "v7_disc_play": (6,
        "Her first discovery playlist plays with its sleeve.",
        "Her first discovery playlist plays, with its sleeve."),
    "v7_disc_done": (6,
        "Saved to the server, like every session.",
        "The session is saved to the server like every other one."),
    "v7_admin": (8,
        "Alex's dashboard: the same insights, now computed from synced data.",
        "Alex, the home lead, opens the Maple Lodge dashboard. The insights are the same, now computed on the iPad from "
        "the synced data."),
    "v7_programme": (8,
        "New: the Group programme card — activities this fortnight, who joined, and who has been overlooked.",
        "New: the Group programme card. It shows how many group activities ran this fortnight, who joined them, and which "
        "residents have been overlooked, so the next session can include them."),
})
SCRIPT.update({
    "v7_grp_open": (7,
        "Group activities: the planner suggests who to bring together, and what to play.",
        "Group activities. The planner looks across the home and suggests who to bring together, and what to play."),
    "v7_grp_planner": (7,
        "Suggestions come from shared tastes: residents who respond to the same genre, with those overdue a visit or a group first.",
        "The suggestions come from shared tastes: residents who respond to the same genre, scored by who most needs company, "
        "with those overdue a visit or a group first. Each suggestion says why, and a Shared favourites set collects residents "
        "who enjoy two or more of the home's top genres."),
    "v7_grp_pick": (7,
        "Tap a suggestion and its residents are selected. Staff keep the final say: one-to-one residents are never invited.",
        "Tapping a suggestion selects its residents. Staff keep the final say. Residents set to one-to-one are never invited, "
        "and small-group residents are flagged rather than dropped."),
    "v7_grp_people": (7,
        "Each name carries its reasoning: last visit, last group, how they did in company.",
        "Each name carries its reasoning: when they were last seen, when they last joined a group, and how they did in company."),
    "v7_grp_session": (7,
        "New: the playlist is ranked for the whole room. Every song is scored for every resident; the room's score is the mean, with a bonus when someone loves it.",
        "New with the backend: the playlist is ranked for the whole room. Every song in the catalogue is scored for every resident "
        "in it, with the same model as their own surface: age, origin, the genres they responded to, and songs like the ones they "
        "love. The room's score is the mean, with a bonus when someone in the room loves the song, and each pick says who it is for."),
    "v7_grp_next": (7,
        "Songs are taken in turn from the room's genres, two per artist at most, so the set is shared rather than one person's.",
        "Songs are taken in turn from the room's genres, two per artist at most, so the set is shared rather than one person's "
        "favourites. Previews play once and the room moves on by itself."),
    "v7_grp_list": (7,
        "The full playlist, with the sleeve and the resident each song was chosen for.",
        "The full playlist, with the sleeve and the resident each song was chosen for."),
    "v7_grp_end": (7,
        "Ending the session asks for a quick check-in on the room.",
        "Ending the session asks for a quick check-in on the room."),
    "v7_grp_checkin": (7,
        "Morale, alertness, lucidity, engagement: four taps, saved to the server with who took part and what played.",
        "Morale, alertness, lucidity and engagement: four taps. The record goes to the server with who took part and what "
        "played, and it feeds the Group programme card we will see next."),
    "v7_grp_saved": (7,
        "Back on the roster, the last group's scores are already there.",
        "Back on the roster, the last group's scores are already there."),
})
EXTRA.update({
    "v7_added": [(12.0, "v7_added2")],
})


# ---- v7 · Part I: a new organisation sets itself up (testStoryPartI_Onboarding, flow 9) ----
SCRIPT.update({
    "v7_onb_open": (9,
        "New: a care organisation can set itself up — no engineer, no seed script.",
        "Finally, something new at the very start. Until now a care organisation existed only because we seeded it. "
        "Now a registered manager can request a workspace from the sign-in screen and set everything up on the iPad."),
    "v7_onb_request": (9,
        "Organisation, your name, work email, role, how many homes, the CQC provider ID.",
        "The request asks for the organisation, the requester's name and work email, their role, how many homes they "
        "run, and optionally their CQC provider ID. An email domain another organisation has already verified is "
        "refused, by name."),
    "v7_onb_send": (9,
        "Consent is stored as a versioned record, then the request goes to the server.",
        "The consent line is stored as a versioned record with the time and the address it came from, and the request "
        "goes to the server."),
    "v7_onb_verify": (9,
        "A six-digit code to the work email — ten minutes, five attempts.",
        "A six digit code goes to the work email. It expires in ten minutes and allows five attempts. On this demo "
        "backend the code is shown on screen; in production it only ever arrives by email."),
    "v7_onb_approved": (9,
        "Approved: an ORG- activation code, single use, seven days.",
        "Verified, and approved. A real deployment waits for a NoteStalgia operator to check the organisation by hand; "
        "the demo approves at once. Either way the requester receives an activation code that works once and expires "
        "in seven days."),
    "v7_onb_code": (9,
        "One screen for activation and invites: email, code, a name, a PIN chosen here.",
        "One screen handles both activation codes and staff invites. Dana enters her name, chooses a six digit PIN, "
        "which is hashed with a secret the iPad never sees, and acknowledges how resident data is handled."),
    "v7_onb_activate": (9,
        "One transaction: organisation, admin account, consents, the first audit entry.",
        "Activation creates the organisation, her admin account, the consent records and the first audit entry in one "
        "database transaction, and signs her in."),
    "v7_onb_setup": (9,
        "Six sections, one short page at a time: nothing to scroll past, so no step is missed.",
        "She lands in the set-up, and it is deliberately a short page at a time. Six sections run along the top: "
        "organisation, homes, team, residents, iPads, ready. Each section is a few small pages, so nothing sits below "
        "the fold waiting to be missed. This first page is the organisation's name, trading name and registration."),
    "v7_onb_address": (9,
        "The head-office address: required, and kept in the United Kingdom.",
        "Next, where the organisation is based. The address is required, because it appears on exports, and the data "
        "region is shown here too."),
    "v7_onb_required": (9,
        "Leave a required field empty and it says so, under the field itself.",
        "Tapping Next with the fields empty does not just fail. Each missing field is marked, in words and an icon, "
        "right under it, and the bar counts what needs attention."),
    "v7_onb_domains": (9,
        "Email domains: verified by a code to the domain, or a DNS record.",
        "The email domains page. Dana's own domain is already verified, so staff on it are sent to staff sign-in and "
        "family carers can't register with it. More domains are proved by an emailed code or a DNS record."),
    "v7_onb_defaults": (9,
        "Defaults every home inherits: PIN re-prompt, who may invite, retention.",
        "The defaults page: how long before a shared iPad asks for a PIN again, whether home leads may invite staff, "
        "and how long session records are kept."),
    "v7_onb_home": (9,
        "A home has wings; the roster groups residents by them.",
        "Homes. Adding one is three small pages: its name, optional CQC location and beds, then its wings, then who "
        "leads it. Names only take real characters, the bed count is a number from one to two thousand, and a home "
        "lead can be invited right here or Dana can lead it herself."),
    "v7_onb_homeAdded": (9,
        "The home is in — the admin's access and this iPad's sync follow on the next token.",
        "The home appears with its counts. Behind the scenes the server re-issues Dana's token so it carries the new "
        "home, and the iPad starts syncing it."),
    "v7_onb_team": (9,
        "Invites by email: role, homes, optional end date for agency cover.",
        "The team. Staff never register themselves. An invite is two pages: who, with an email that has to be a real "
        "address, and what they can do: the role, the homes and, for agency cover, an end date after which the "
        "account stops working. A whole list can be pasted at once."),
    "v7_onb_invited": (9,
        "An INV- code: hashed at rest, single use, seven days; a resend voids the old one.",
        "The invite is pending, with a code that is stored only as a hash, works once and expires in seven days. "
        "Resending issues a new one and voids the old. The code is shown here only because this is the demo backend."),
    "v7_onb_residents": (9,
        "Residents from a spreadsheet, or one at a time through discovery.",
        "Residents. They can be imported from a spreadsheet with a name, room, wing, age or date of birth, "
        "nationality and favourite genre, or added one at a time through the discovery pass."),
    "v7_onb_preview": (9,
        "Every row is checked: unknown wings fall back, bad ages are skipped, duplicates flagged.",
        "Every row is checked on its own page before anything is written. An unknown wing falls back to the first one, "
        "an age outside the range or a name with digits in it is skipped, and a name already on the roster is flagged."),
    "v7_onb_imported": (9,
        "Three residents on the roster, pushed through the same sync as any other edit.",
        "Three residents are on the roster, marked discovery not yet run, and pushed through the same sync as any "
        "other edit."),
    "v7_onb_devices": (9,
        "Shared iPads: Guided Access, auto-lock, no personal accounts, managed deployment.",
        "The iPads. Guidance for shared tablets on the floor: Guided Access during sessions, auto-lock, no personal "
        "accounts, and managed deployment through Apple Business Manager."),
    "v7_onb_registered": (9,
        "This iPad now belongs to Willowbank Lodge.",
        "Registering the iPad needs a label, and says so if it is missing. It records which home the tablet belongs to, "
        "so one found in the wrong wing can be identified."),
    "v7_onb_ready": (9,
        "A live checklist, first-week nudges and the audit trail.",
        "The last section: a live checklist of what is in place, a nudge about the invite still waiting, and the audit "
        "trail, append only, with who did what and when."),
    "v7_onb_dashboard": (9,
        "Set-up done: the new home's dashboard, empty until the first sessions.",
        "Finishing lands on the new home's dashboard, empty until staff run their first sessions. Organisation set-up "
        "stays one tap away."),
    "v7_onb_roster": (9,
        "The roster shows the imported residents, ready for their first discovery.",
        "The roster shows the imported residents with bundled portraits, each ready for a first discovery pass."),
    "v7_onb_join": (9,
        "Sam joins with the invite code: the email must match, then a PIN of their own.",
        "Now Sam, the invited supervisor. Log out, tap I have an invite or activation code, and enter the email and "
        "the code. A wrong email reads exactly like a wrong code, so nothing about who was invited leaks."),
    "v7_onb_preview2": (9,
        "The invite shows what it unlocks before a PIN is chosen.",
        "The invite is previewed before anything is created: which organisation, which role, which homes."),
    "v7_onb_accept": (9,
        "Accepting creates the account and signs in; the home becomes active.",
        "Accepting creates Sam's account with the chosen PIN, records the consent, marks the home active and signs "
        "Sam in."),
    "v7_onb_samRoster": (9,
        "Sam's roster — the residents Dana imported, already synced.",
        "Sam's roster: the residents Dana imported a minute ago, already synced to this account. From here, everything "
        "you saw earlier applies."),
})


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
