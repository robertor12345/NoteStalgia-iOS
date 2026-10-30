"""Detailed narration for the v7 (iPad) walkthrough. Imported by build_v7.py after narration.py, it replaces the
shorter v7 lines with ones that describe what is on screen, what each control does and what the server does behind
it, and adds the lines for the pages the paged set-up wizard introduced. Flow indices follow build_v7.FLOWS (0–9);
the marker names are the ones DemoWalkthroughUITests writes."""
import narration as N

SCRIPT = {
    "intro7": (None, "",
        "NoteStalgia, version seven. Since the last walkthrough the iPad has gained a real backend that every tablet in "
        "a home shares; a catalogue of songs from residents' younger years, with Apple previews and cover art; a "
        "recommender that learns in real time from what each resident responds to; group sessions ranked for a whole "
        "room; and a way for a care organisation to set itself up, one short page at a time, without anyone from our "
        "side. This video shows only what is new. Every step is described as it happens, and the picture waits for the "
        "voice, so you can follow every tap."),
    "outro7": (None, "",
        "Thanks for watching. Everything you have seen runs on the iPad against a live backend, with demo residents and "
        "demo data. The same set-up and admin screens are shown on the phone in a second film. We would love your "
        "feedback on the five questions on screen."),

    # ---- A live backend · Synced roster & profile · Group activities --------------------------------------------------
    "v7_open": (0,
        "Same orb, same calm opening, but every tap now talks to a live server.",
        "The same calm opening, the orb breathing slowly. What has changed is behind it. Every tap now talks to a live "
        "server: a Cloudflare Worker and a database on the free tier. The iPad still works offline first, so a lost "
        "network never stops a session, and it syncs with the server whenever it can."),
    "v7_signin": (0,
        "Sign-in is checked by the server. The PIN is never stored on the iPad.",
        "Max signs in as before, with a work email and a six digit PIN. Now the server checks it. The PIN is hashed with "
        "a secret that the iPad never sees, so there is nothing on the tablet to steal. Five wrong attempts lock the "
        "account for fifteen minutes, and the message is the same whether the email or the PIN was wrong, so nobody can "
        "discover which emails exist."),
    "v7_welcome": (0,
        "Syncing: the iPad pulls Maple Lodge from the server and keeps a copy.",
        "While the welcome plays, the iPad pulls Maple Lodge from the server and keeps a copy, so the roster "
        "keeps working with no connection at all."),
    "v7_roster": (1,
        "The roster you know, now built from synced data. A session saved on one iPad reaches every other.",
        "This is the same roster, now built from synced data. The iPad asks only for what has changed since last time. "
        "A session saved on one iPad appears on every other iPad in the home within moments. Anything done while offline is queued on the tablet and pushed when the network "
        "returns, and if two tablets change the same resident, the later edit wins and neither is lost silently."),
    "v7_profile": (1,
        "Irene's profile, from the server: observations, playlists on file, comfort notes.",
        "Irene's profile also comes from the server: the carer observations from her recent sessions, the playlists on "
        "file for her, her comfort notes, exactly as staff left them on another device. Nothing here is typed twice."),
    "v7_group": (2,
        "New: Group activities. How often Irene joined in, the last activity, and how engaged she was.",
        "New since the last walkthrough: a Group activities card on the profile. It shows how many group activities "
        "Irene joined in the last fortnight, which one was the most recent, and how engaged she was, taken from the "
        "check-in staff complete at the end of each group."),
    "v7_comfort": (2,
        "'In company' tells the group planner how she likes to take part. Saved to the server at once.",
        "The In company setting tells the planner how she likes to take part: one to one, small groups, or in company. "
        "Setting her to small groups means the planner will only suggest her for smaller sessions, and a one to one "
        "resident is never invited to a group at all. The change is saved to the server straight away, so every iPad "
        "applies it."),

    # ---- Find a song they love · Real-time song selection ----------------------------------------------------------------
    "v7_songs": (3,
        "New: 'Find a song they love', a curated catalogue of songs from residents' younger years.",
        "Also new: Find a song they love. Family and staff can search a curated catalogue of more than one hundred and "
        "sixty songs from residents' younger years, from British dance bands to Caribbean calypso to Bollywood, each "
        "with an Apple Music preview. Songs are matched to the seven genres the resident sees."),
    "v7_search": (3,
        "Results show the sleeve, artist, year and the genre glyph the song will live under.",
        "Searching for Vera Lynn. Each result shows the cover art, the artist, the year the song first came out, and the "
        "genre glyph it will live under on the resident's screen, with a link to the full song on Apple Music. The "
        "catalogue is searched first; only if it comes up short does the server ask Apple, and it remembers the answer."),
    "v7_preview": (3,
        "Tap the sleeve to hear a 30-second preview before adding it.",
        "Tapping the sleeve plays a thirty second preview, so a carer can check it is the right recording before "
        "adding it. The audio streams from Apple. It is never copied or stored, and the preview is always a link back "
        "to the song on Apple Music."),
    "v7_add": (4,
        "Add files the song on Irene's profile and tells the recommender, in real time.",
        "Add files the song on Irene's profile. In the same moment the iPad tells the recommender. A staff pick is strong "
        "evidence that she will like it, and the catalogue grows around the artist, so there are similar songs to "
        "offer straight away."),
    "v7_added": (4,
        "Within seconds the server has re-ranked her Pop queue: this song first, then more Vera Lynn, then British pop of her era.",
        "Back on the profile, the song sits with her suggested likes. Within seconds the server has re-ranked her Pop queue "
        "from four things: her age, where she is from, the genres she has responded to, and songs like the ones she "
        "loves. This song first, then more from Vera Lynn, then British pop of her era. The model also adds a little "
        "chance, so it keeps trying something new, and it never plays more than two songs by one artist in a row of eight."),
    "v7_added2": (4,
        "Real time means every pick, every sun and every session re-ranks the queues within seconds.",
        "That is what real time means here. Every staff pick, every sun on the resident's screen and every finished "
        "session re-ranks her queues within seconds, and the next tap plays the new order. Older evidence fades with a "
        "half life of about twelve weeks, so the profile follows how her tastes change."),
    "v7_surface": (5,
        "On the calm surface a Pop glyph has appeared, built from the new playlist.",
        "Opening her calm surface, the screen she holds. A Pop glyph has appeared among the seven, built from the new "
        "playlist. There are no words on this screen, only the music as pictures."),
    "v7_pop": (5,
        "We'll Meet Again plays, and the record sleeve fills the screen behind the glyph.",
        "A tap on the glyph plays We'll Meet Again, streamed from Apple, and the record sleeve fills the screen behind "
        "the glyph. The level of the music drives the ring around it. For a resident, the picture is the song, and the "
        "sleeve is often what they recognise first."),
    "v7_next": (5,
        "Swipe: the next song is more Vera Lynn, chosen by the model, with its own sleeve.",
        "A swipe moves to the next song. It is more Vera Lynn, chosen by the model because she likes her, with its own "
        "sleeve. Each preview plays once and the queue moves on by itself, so the resident never has to do anything."),
    "v7_sun": (5,
        "The sun is a signal too: it raises this song and its genre for next time.",
        "The sun is a signal too. It raises this song, its genre and its decade in her profile, and the next session "
        "will reflect it. The cloud does the opposite, quietly, and never removes a genre completely."),
    "v7_staffkey": (5,
        "Press and hold to take the iPad back. The session and its signals go to the server.",
        "Pressing and holding the key takes the iPad back from the resident. The session is saved to the server, and the "
        "listening signals go with it: which songs she liked, which she skipped, how long she listened."),
    "v7_summary": (5,
        "The summary as before. Her queues are refreshed behind the scenes.",
        "The session summary is as before. Behind the scenes the signals have been applied and her queues refreshed, so "
        "the next session starts from what she responded to today."),

    # ---- Online discovery -------------------------------------------------------------------------------------------------
    "v7_disc_start": (6,
        "Discovery is now online: the server plans seven real songs for Irene's age and origin.",
        "Discovery is now online. Instead of seven fixed clips, the server plans seven real songs for Irene's age and "
        "origin: one per genre, and in each genre the song most familiar to someone of her generation and background. "
        "Her years as a young adult count most."),
    "v7_disc_orb": (6,
        "The song's own cover art fills the orb; the small caption tells staff what is playing.",
        "The song's own cover art fills the orb behind the three faces, and a small caption at the bottom tells staff "
        "what is playing: title, artist and year. The resident needs no words. They simply tap the face that matches "
        "how it makes them feel."),
    "v7_disc_tap": (6,
        "Each face goes to the server as evidence for the genre, the decade and the song.",
        "Each face goes to the server as evidence: for the genre, for the decade it came from, and for the song "
        "itself. A green face is a strong yes, amber is neutral, and red is a no. Left alone, a clip plays for thirty "
        "seconds and moves on."),
    "v7_disc_more": (6,
        "A red lowers a genre without removing it. Slot three is the genre the model knows least.",
        "A red face lowers a genre without removing it, so one bad moment never closes a door for good. A green brings "
        "that genre's playlist forward. The third clip is always the genre the model knows least about, so every pass "
        "teaches it as much as possible."),
    "v7_disc_result": (6,
        "The faces become a taste profile: playlists for the genres she enjoyed, and a queue for every glyph.",
        "At the end the faces become a taste profile. Playlists are written for the genres she enjoyed, with her "
        "favourite first, and every glyph on her surface gets a queue of six to eight songs, even a genre she turned "
        "down, which gets a short retry queue of different artists."),
    "v7_disc_play": (6,
        "Her first discovery playlist plays, with its sleeve.",
        "Her first discovery playlist plays, with its sleeve behind the glyph, exactly as every later session will."),
    "v7_disc_done": (6,
        "Saved to the server, like every other session.",
        "The session is saved to the server like every other one, and the iPads in the home all see her new profile."),

    # ---- Group sessions ----------------------------------------------------------------------------------------------------
    "v7_grp_open": (7,
        "Group activities: the planner suggests who to bring together, and what to play.",
        "Group activities. The planner looks across the whole home and suggests who to bring together, and what to play "
        "for them."),
    "v7_grp_planner": (7,
        "Suggestions come from shared tastes: residents who respond to the same genre, those overdue a visit or a group first.",
        "The suggestions come from shared tastes: residents who respond to the same genre, scored by who most needs "
        "company, with those overdue a visit or a group first. Each suggestion says why, and a Shared favourites set "
        "collects residents who enjoy two or more of the home's top genres."),
    "v7_grp_pick": (7,
        "Tap a suggestion and its residents are selected. Staff keep the final say.",
        "Tapping a suggestion selects its residents. Staff keep the final say. Residents set to one to one are never "
        "invited, and small group residents are flagged rather than dropped."),
    "v7_grp_people": (7,
        "Each name carries its reasoning: last visit, last group, how they did in company.",
        "Each name carries its reasoning: when they were last seen, when they last joined a group, and how they did in "
        "company. Staff can switch anyone on or off before starting."),
    "v7_grp_session": (7,
        "New: the playlist is ranked for the whole room, song by song, resident by resident.",
        "New with the backend: the playlist is ranked for the whole room. Every song in the catalogue is scored for "
        "every resident in it, with the same model as their own surface: age, origin, the genres they responded to, "
        "and songs like the ones they love. The room's score is the mean, with a bonus when someone in the room loves "
        "the song, and each pick says who it is for."),
    "v7_grp_next": (7,
        "Songs are taken in turn from the room's genres, two per artist at most, so the set is shared.",
        "Songs are taken in turn from the room's genres, two per artist at most, so the set is shared rather than one "
        "person's favourites. Previews play once and the room moves on by itself."),
    "v7_grp_list": (7,
        "The full playlist, with the sleeve and the resident each song was chosen for.",
        "The full playlist, with each sleeve and the resident the song was chosen for, so the carer leading the room can "
        "say whose song it is as it plays."),
    "v7_grp_end": (7,
        "Ending the session asks for a quick check-in on the room.",
        "Ending the session asks for a quick check-in on the room, while it is still fresh."),
    "v7_grp_checkin": (7,
        "Morale, alertness, lucidity, engagement: four taps, saved with who took part and what played.",
        "Morale, alertness, lucidity and engagement: four taps. The record goes to the server with who took part and "
        "what played, and it feeds the Group programme card we will see next."),
    "v7_grp_saved": (7,
        "Back on the roster, the last group's scores are already there.",
        "Back on the roster, the last group's scores are already there, summarised for the next carer."),

    # ---- Home admin: group programme ---------------------------------------------------------------------------------------
    "v7_admin": (8,
        "Alex's dashboard: the same insights, now computed from synced data.",
        "Alex, the home lead, opens the Maple Lodge dashboard. The insights are the same as before, now computed on the "
        "iPad from the synced data, so they include sessions recorded on every tablet in the home."),
    "v7_programme": (8,
        "New: the Group programme card. Activities this fortnight, who joined, and who has been left out.",
        "New: the Group programme card. It shows how many group activities ran this fortnight, how many residents joined "
        "them, and how engaged and how cheerful the groups were. And it names the residents who have been overlooked, "
        "so the next session can include them."),

    # ---- A new organisation (testStoryPartI_Onboarding) ----------------------------------------------------------------------
    "v7_onb_open": (9,
        "New: a care organisation can set itself up, with no engineer and no seed script.",
        "And finally, the biggest change for a new customer. Until now a care organisation existed only because we "
        "seeded it. Now a registered manager can request a workspace from the sign-in screen, and set up everything on "
        "the iPad. These two links appear when the app is connected to a backend. Staff never create their own "
        "accounts; they are invited."),
    "v7_onb_request": (9,
        "The request: organisation, your name, work email, role, how many homes, CQC ID, notes.",
        "The request form asks for the organisation's name, the requester's own name and work email, an optional phone "
        "number, their role, how many homes they run, and an optional CQC provider ID. On the iPad it has room to sit "
        "in one column with generous margins. Required fields are named, optional ones say so, and an email domain "
        "another organisation has already verified is refused, by name."),
    "v7_onb_invalid": (9,
        "A typo the form catches: names cannot hold digits. The message sits under the field.",
        "A deliberate mistake: a digit in the name, and the consent not yet ticked. Sending the request does not just "
        "fail. The name field is outlined and says, under itself, in words and with an icon, what it can contain: "
        "letters, spaces, hyphens, apostrophes and full stops. A banner above the send button counts the two problems "
        "instead of repeating either. The server applies the very same rules, so a hand made request cannot get past what the app refuses."),
    "v7_onb_send": (9,
        "Fixed. The consent is stored as a versioned record, then the request goes to the server.",
        "The name is corrected and the consent line ticked. It is stored as a versioned record with the time and the "
        "address it came from, and the request goes to the server."),
    "v7_onb_verify": (9,
        "A six-digit code to the work email: ten minutes, five attempts.",
        "A six digit code goes to the work email to prove the address is real. It expires in ten minutes and allows "
        "five attempts. On this demo backend the code is shown on screen so the film needs no mailbox; in production "
        "it only ever arrives by email."),
    "v7_onb_approved": (9,
        "Approved: an ORG- activation code, single use, valid for seven days.",
        "Verified, and approved. A real deployment waits for a NoteStalgia operator to check the organisation by hand; "
        "the demo approves at once. Either way the requester receives an activation code that works once, expires in "
        "seven days, and is stored only as a hash."),
    "v7_onb_code": (9,
        "One screen for activation and invites: email, code, a name, and a PIN chosen here.",
        "One screen handles both activation codes and staff invites. Dana enters her name, chooses a six digit PIN, "
        "twice, which is hashed with a secret the iPad never sees, and acknowledges how resident data is handled."),
    "v7_onb_activate": (9,
        "One transaction: the organisation, the admin account, the consents and the first audit entry.",
        "Activation creates the organisation, her administrator account, the consent records and the first audit "
        "entry in one database transaction, so there is never a half made organisation, and signs her in."),
    "v7_onb_setup": (9,
        "Six sections, one short page at a time: nothing to scroll past, so no step is missed.",
        "She lands in the set-up, and it is deliberately a short page at a time. Six circles run along the top: "
        "organisation, homes, team, residents, iPads, and ready. Each is a few small pages, so nothing sits below the "
        "fold waiting to be missed. The small label says which page of how many, and the bar names what comes next. "
        "This first page is the organisation's name, trading name and registration."),
    "v7_onb_address": (9,
        "The head-office address: required, and kept in the United Kingdom.",
        "Next, where the organisation is based. The address is required, because it appears on exports and on the "
        "organisation record, and the page shows the data region, the United Kingdom, and the plan."),
    "v7_onb_required": (9,
        "Next with nothing typed: each missing field says so, under itself.",
        "Tapping Next with the fields empty. Each missing field is marked, in words and with an icon, right under "
        "itself, and the bar counts what needs attention. The page will not move on until the address is complete."),
    "v7_onb_postcode": (9,
        "Typed in lower case, with no space: the field shapes it into a UK postcode.",
        "The address is in. The postcode was typed in lower case with no space; the field capitalised it as it went, "
        "and when the page is left it is checked as a real UK postcode and stored with its space. Fields drop "
        "characters that can never be right, like letters in a bed count, and check everything else with a message."),
    "v7_onb_domains": (9,
        "Email domains: Dana's own is verified. More are proved by a code or a DNS record.",
        "The email domains page. Dana's own domain is already verified, so staff on it are sent to staff sign-in and "
        "family carers cannot register a Care at home account with it. More domains are proved by an emailed code or a "
        "DNS record, and free mail domains can never be claimed. On the iPad the field and its button sit side by side."),
    "v7_onb_defaults": (9,
        "Defaults every home inherits: PIN re-prompt, who may invite, how long records are kept.",
        "The defaults page: how long before a shared iPad asks for a PIN again, whether home leads may invite staff, "
        "whether supervisors may add residents, and how long session records are kept before they are deleted."),
    "v7_onb_home": (9,
        "Homes: none yet. Adding one is a journey of four small pages.",
        "Homes. There are none yet, so the page offers one primary action: add your first home. Adding a home is "
        "a journey of four small pages, and it always ends back here with the new home listed."),
    "v7_onb_homeDetails": (9,
        "Page 1 of 4: the home's name, an optional CQC location ID, and its beds.",
        "Page one of four: the home. A name, an optional CQC location ID, which belongs to the home rather than the "
        "organisation, and an optional number of beds, a whole number from one to two thousand."),
    "v7_onb_homeAddress": (9,
        "Page 2 of 4: where the home is. One tap reuses the head-office address.",
        "Page two: where the home is. The address is required, because the home's CQC location has one. This home is "
        "on the head-office site, so one tap on use the head-office address fills the three fields from the "
        "organisation record."),
    "v7_onb_wings": (9,
        "Page 3 of 4: wings group the roster. Tap a wing to remove it; add your own.",
        "Page three: the wings. Wings are how a home groups its roster, and every resident sits in exactly one. The "
        "usual three are offered; tap to remove one, or type a name to add another. Names must be different, and a "
        "home needs at least one."),
    "v7_onb_lead": (9,
        "Page 4 of 4: who leads the home. Dana herself, or someone invited by email.",
        "Page four: who leads it. Either Dana leads the home herself, or she invites someone by email. A home lead "
        "invites their own staff and sees the home's dashboard. Dana leads this one, and adds it."),
    "v7_onb_homeAdded": (9,
        "The home is in: wings, status, counts, address, CQC location, capacity.",
        "The home appears with its wings, its status, its counts and its address. Behind the scenes the server "
        "re-issues Dana's token so it carries the new home, and the iPad starts syncing it. Each home can also be "
        "exported, as residents or sessions in a spreadsheet, or everything as JSON."),
    "v7_onb_team": (9,
        "The team: invite one person or several. Staff never register themselves.",
        "The team. Staff never register themselves: an invite names the role and the homes, and the person accepts it. "
        "Waiting invites and the staff already in sit below."),
    "v7_onb_inviteWho": (9,
        "Invite page 1 of 2: who. A real work email is required; a name is optional.",
        "Inviting one person takes two pages. First, who: a work email, required, and a name, optional, because the "
        "person confirms their own when they accept."),
    "v7_onb_inviteInvalid": (9,
        "An email without its ending is caught before anything is sent.",
        "The email was typed without its ending. Sam at willowbank is not an address yet, so the field explains what it "
        "wants. No spaces are allowed, and the field strips them as they are typed."),
    "v7_onb_inviteAccess": (9,
        "Invite page 2 of 2: role, which homes, and an optional end date for agency cover.",
        "Page two: what they can do. A role, supervisor, home lead or organisation admin. Which homes, shown as chips. "
        "And an optional end date for agency cover, after which the account simply stops working."),
    "v7_onb_invited": (9,
        "An INV- code: hashed at rest, single use, seven days. A resend voids the old one.",
        "The invite is pending, with a code that is stored only as a hash, works once, and expires in seven days. "
        "Resending issues a new one and voids the old. The code is shown here only because this is the demo backend."),
    "v7_onb_bulk": (9,
        "Several at once: one person per line, with email, name, role and home.",
        "Inviting several at once. One person per line: email, name, role and home. Leave the home out and the person "
        "joins the first home. Up to fifty lines at a time, meant for pasting from a spreadsheet."),
    "v7_onb_bulkSend": (9,
        "Two lines, ready to send.",
        "Two lines are pasted: Amy as a supervisor and Ben as a home lead. Each line is checked on its own before "
        "anything is sent."),
    "v7_onb_bulkDone": (9,
        "Three invites waiting. Each can be resent or revoked.",
        "Back on the team page, three invites are waiting, each with its role, its home and its expiry. Each can be "
        "resent, which voids the old code, or revoked."),
    "v7_onb_residents": (9,
        "Residents from a spreadsheet, or one at a time through discovery.",
        "Residents. They can be imported from a spreadsheet with a name, room, wing, age or date of birth, nationality "
        "and favourite genre, or added one at a time through the discovery pass. Only the name and the age are "
        "required."),
    "v7_onb_preview": (9,
        "Every row is checked: unknown wings fall back, bad ages are skipped, duplicates flagged.",
        "Every row is checked on its own page before anything is written. An unknown wing falls back to the first "
        "one, an age outside the range or a name with digits in it is skipped, and a name already on the roster is "
        "flagged."),
    "v7_onb_imported": (9,
        "Three residents on the roster, pushed through the same sync as any other edit.",
        "Three residents are on the roster, marked discovery not yet run, and pushed through the same sync as every "
        "other edit, so every iPad in the home sees them."),
    "v7_onb_devices": (9,
        "Shared iPads: Guided Access, auto-lock, no personal accounts, managed deployment.",
        "The iPads. Guidance for the shared tablets on the floor: Guided Access during sessions, auto-lock and a "
        "passcode, no personal accounts, and managed deployment through Apple Business Manager. It is guidance, not "
        "enforcement."),
    "v7_onb_register": (9,
        "Register this iPad: which home it belongs to, and a label.",
        "Registering the iPad records which home it belongs to, so a tablet found in the wrong wing can be identified. "
        "It needs a label."),
    "v7_onb_labelRequired": (9,
        "A label is required, and the page says so under the field.",
        "Registering without a label is refused, with a message under the field. A label is the point of the "
        "registration, so it is required."),
    "v7_onb_registered": (9,
        "This iPad now belongs to Willowbank Lodge.",
        "Registered. The iPad now belongs to Willowbank Lodge, and it is listed with its model and when it was last "
        "seen. It can be removed from this page if it is retired or lost."),
    "v7_onb_ready": (9,
        "A live checklist and first-week nudges.",
        "The last section. A live checklist of what is in place, each line marked done or to do in words as well as "
        "colour, and a nudge about the invites still waiting and the residents who have not had a discovery pass."),
    "v7_onb_audit": (9,
        "The audit trail: who did what, and when. Append-only.",
        "And the audit trail: every set-up action, with who did it and when. It is append only, so nothing can be "
        "edited or deleted afterwards."),
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
        "Accepting creates Sam's account with the chosen PIN, records the consent, marks the home active, spends the "
        "code so it can never work again, and signs Sam in."),
    "v7_onb_samRoster": (9,
        "Sam's roster: the residents Dana imported, already synced.",
        "Sam's roster: the residents Dana imported a minute ago, already synced to this account. From here, everything "
        "you saw earlier applies."),
}

N.SCRIPT.update(SCRIPT)
