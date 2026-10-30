"""Narration + captions for the phone walkthrough (build_v7_mobile.py): the onboarding and admin screens, recorded
on an iPhone. Same shape as narration.SCRIPT: marker → (flow index, on-screen caption, spoken line). The spoken
lines are deliberately detailed: what is on the screen, what each control does, what the server does behind it.

Flow indices (see build_v7_mobile.FLOWS):
  0 Request a workspace   1 Verify and activate   2 Organisation   3 Homes   4 Team and invites
  5 Residents             6 iPads and ready       7 A colleague joins   8 Home admin dashboard   9 Managing the team
"""
import narration as N

SCRIPT = {
    # ---- 0 · Request a workspace (testMobileA_Request) --------------------------------------------------------------
    "intro_mobile": (None, "",
        "NoteStalgia on the phone. This film shows every onboarding screen and every admin screen on an iPhone, which is "
        "the device they are designed for first. A registered manager can request a workspace, verify it, activate it and "
        "set up the organisation, its homes, its team, its residents and its iPads, all without an engineer. Then we see "
        "a colleague join with an invite, the home lead's dashboard, and how an organisation admin looks after the team. "
        "Everything pauses long enough to read, and every step is described as it happens."),
    "outro_mobile": (None, "",
        "That was every onboarding and admin screen on the phone. Each page is short enough to read without scrolling "
        "past a field, every required field says so under itself, text wraps rather than truncating, and the bar with "
        "the next step stays within reach of a thumb. Thanks for watching. We would value your thoughts on the five "
        "questions on screen."),
    "m_open": (0,
        "The sign-in screen, with two new doors: request a workspace, or use an invite or activation code.",
        "This is the sign-in screen on an iPhone. Below the email and PIN there are two new ways in. Request a workspace "
        "is for a registered manager whose organisation is not on NoteStalgia yet. I have an invite or activation code "
        "is for everyone else: a colleague with an invite, or a manager whose request has been approved. These two links "
        "only appear when the app is connected to a backend, and they are the only open doors. Staff cannot create "
        "their own accounts; they have to be invited."),
    "m_request": (0,
        "The request form: organisation, your name, work email, phone, role, number of homes, CQC ID, notes.",
        "The request form. It asks for the organisation's name, the requester's own name, a work email, and an optional "
        "phone number. Further down it asks for the requester's role, how many homes the organisation runs, an optional "
        "CQC provider ID, and anything else worth knowing. Required fields are named plainly. The optional ones say "
        "optional in their label, so nobody has to guess. Each field is checked as the person moves on."),
    "m_request_more": (0,
        "Role, number of homes, CQC provider ID and notes sit below the fold.",
        "Scrolling down. The role is one tap: manager, operations, IT or other. How many homes is one tap too: one home, "
        "two to five, or six or more, which tells us how to look after the organisation. The CQC provider ID is optional, "
        "but when it is given it must look like a real one, the digit one, a hyphen, then nine or ten digits."),
    "m_invalid": (0,
        "A typo the form catches: names cannot hold digits. The message sits under the field, with an icon, not just a colour.",
        "Now a deliberate mistake. The name was typed with a stray digit, and the consent box was left unticked. Sending "
        "the request does not just fail. The name field gets a red outline and a message under it in words, with an icon, "
        "so the meaning never depends on colour alone. Names can contain letters, spaces, hyphens, apostrophes and full "
        "stops, so O'Brien, Zoë and Łukasz are all fine, but digits are not. Because two things need attention, the "
        "banner above the send button counts them instead of repeating either one."),
    "m_send": (0,
        "Fixed, and the consent ticked: it is stored as a versioned record, then the request goes to the server.",
        "Dana's name is corrected, and the consent line is ticked. That line is stored as a versioned record with the "
        "time and the address it came from, so there is proof of what was agreed to. The request goes to the server, "
        "which checks it once more with the same rules the app used. It also refuses an email domain that another "
        "organisation has already verified, and names that organisation, so nobody can claim a colleague's domain."),

    # ---- 1 · Verify and activate -----------------------------------------------------------------------------------
    "m_verify": (1,
        "A six-digit code goes to the work email: ten minutes, five attempts.",
        "The server has sent a six digit code to the work email, to prove the address is real. It works for ten minutes "
        "and allows five attempts. On this demo backend the code is also shown under the field, so the film does not "
        "need a mailbox; on a real deployment it only ever arrives by email, and nothing in the app can reveal it."),
    "m_approved": (1,
        "Approved: an ORG- activation code, single use, valid for seven days.",
        "The code was right, and the request is approved. A real deployment holds each request until a NoteStalgia "
        "operator has checked the organisation by hand; the demo approves at once. Either way the requester is given an "
        "activation code that starts with ORG, works exactly once, and expires after seven days. It is stored on the "
        "server only as a hash, so even the database cannot read it back."),
    "m_code": (1,
        "One screen for activation and invites: email, code, a name, and a PIN chosen here.",
        "One screen handles both activation codes and staff invites. It asks for the email the code was sent to, the code "
        "itself, a name, and a six digit PIN, entered twice. The name is optional here because the request already has "
        "one. The PIN is hashed on the server with a secret that the phone never sees, and five wrong attempts lock the "
        "account for fifteen minutes. Below, a plain statement of how resident data is handled has to be acknowledged."),
    "m_activate": (1,
        "Activation is one transaction: the organisation, the admin account, the consents and the first audit entry.",
        "Activating does four things in one database transaction, so there is never a half-created organisation. It "
        "creates the organisation, creates Dana's administrator account, records her consents, and writes the first "
        "entry of the audit trail. Then it signs her in."),
    "m_setup_open": (1,
        "Signed in, and straight into set-up.",
        "She is signed in, and the app opens the set-up, because an organisation administrator with no homes has "
        "nothing else to do yet. Everything from here is one short page at a time."),

    # ---- 2 · Organisation (testMobileB_SetupOrganisationHomesTeam) -----------------------------------------------------
    "m_org_details": (2,
        "Six sections along the top; each section is a few short pages.",
        "This is the set-up. Six circles run along the top: organisation, homes, team, residents, iPads, and ready. The "
        "highlighted one is where Dana is, and a circle gets a tick when its section is done. Each section is a handful "
        "of short pages, so nothing sits below the fold waiting to be missed, which is the whole point of splitting it "
        "up. The small label above the title says which page of how many, and the bar at the bottom always says what "
        "comes next. This first page is the organisation's name, an optional trading name, and an optional CQC provider ID."),
    "m_org_address": (2,
        "The head-office address: line, town and postcode. Required, and kept in the United Kingdom.",
        "Page two is the head-office address: first line, town and postcode. It is required, because it appears on exports "
        "and on the organisation record. Everything NoteStalgia stores for this organisation lives in the United "
        "Kingdom, and the page says so, along with the plan, here a thirty day trial."),
    "m_org_required": (2,
        "Next with nothing typed: every missing field is marked under itself, and the bar counts three.",
        "Tapping Next with the fields empty. Each missing field is marked right under itself, in words: enter the first "
        "address line, enter the town, enter a postcode like S K one one A A. The bar counts three fields needing "
        "attention rather than repeating a sentence. And the page does not move on until the address is complete."),
    "m_org_postcode": (2,
        "Typed in lower case with no space; the field shapes it into a UK postcode.",
        "The address is filled in. The postcode was typed in lower case with no space, and the field turned it into "
        "capitals as it went, so it reads S K one one A A. When the page is left, it is checked as a real UK postcode "
        "and stored with the space in the right place. Letters can never appear in a bed count, and spaces never in an "
        "email, because fields drop characters that cannot be right. Everything else is checked with a message."),
    "m_domains": (2,
        "Dana's own domain is already verified. More domains are proved by an emailed code or a DNS record.",
        "Email domains. Dana's own domain was verified when she confirmed her work email, so staff on it are sent to "
        "staff sign-in, and family carers cannot register a Care at home account with it. More domains, say for a "
        "second company in the group, are proved one of two ways: a six digit code to postmaster or admin at that domain, "
        "or a DNS record. Free mail domains such as Gmail can never be claimed. Dana picks the DNS route."),
    "m_domain_invalid": (2,
        "A half-typed domain is explained, not just refused.",
        "She starts typing the domain and sends it too early. The field explains what it wants: a domain like "
        "sunrise-care dot co dot uk, just the part after the at sign. If someone pastes a whole web address, the "
        "https and the path are stripped for them, so a copied link still works."),
    "m_dns": (2,
        "The TXT record to publish, with copy buttons. The token is meant to be public.",
        "Now the full domain. The app shows the DNS record to publish: its name, which begins underscore notestalgia, "
        "its type, TXT, and a value. There are copy buttons for the name and the value, and a Check DNS button for "
        "when the record is live, which asks public DNS over HTTPS. The token is meant to be public; it only proves "
        "who controls the domain, and it stays on the domain as proof. DNS changes can take up to an hour."),
    "m_defaults": (2,
        "Defaults every home inherits: PIN re-prompt on shared iPads, who may invite, how long records are kept.",
        "The last organisation page holds the defaults every home starts from. How long a shared iPad can sit idle "
        "before the next person has to enter their PIN again. Whether home leads may invite their own staff. Whether "
        "supervisors may add residents. And how long session records are kept, one, two or three years, after which "
        "they are deleted while each resident's preferences are kept for as long as they are on the roster."),
    "m_defaults_saved": (2,
        "Moving on saves the organisation: 'Organisation saved.'",
        "Dana makes the PIN re-prompt five minutes and moves on. The organisation is saved as she leaves, so a wrong "
        "value is reported on the page that holds it rather than three pages later, and the confirmation appears "
        "just above the bar, where she is already looking."),

    # ---- 3 · Homes -------------------------------------------------------------------------------------------------
    "m_homes": (3,
        "Homes: none yet. 'Add your first home' is the one primary action.",
        "Homes. There are none yet, so the page says so and offers one primary action: add your first home. Adding a "
        "home is a short journey of its own, four pages, and it always ends back here with the new home listed."),
    "m_home_details": (3,
        "Page 1 of 4: the home's name, an optional CQC location ID, an optional number of beds.",
        "Page one of four: the home. A name, an optional CQC location ID, which is different from the provider ID because "
        "each home has its own, and an optional number of beds. The home name takes letters, numbers and ordinary "
        "punctuation, but no symbols."),
    "m_home_beds": (3,
        "The bed count keeps only digits: '4x0' became 40.",
        "She typed four, a letter x, and a zero into the beds field, and it kept only the digits, so it reads forty. Beds "
        "must be a whole number from one to two thousand, and the server enforces the same range."),
    "m_home_address": (3,
        "Page 2 of 4: where the home is. One tap reuses the head-office address.",
        "Page two: where the home is. A home has its own address, required, because the CQC location it belongs to has one. "
        "Where the home is on the head-office site, as it is here, one tap on use the head-office address fills "
        "the three fields from the organisation record. Otherwise they are typed, with the same checks as before."),
    "m_home_wings": (3,
        "Page 3 of 4: wings group the roster. Tap a wing to remove it; add your own.",
        "Page three: the wings. A wing is how a home groups its roster, and every resident sits in exactly one. The "
        "usual three are offered, residential, memory care and day programme. Tap a wing to remove it, or type a "
        "new name and add it. Names must be different from each other, and a wing needs a real name."),
    "m_home_wings_edit": (3,
        "Garden suite added; Day programme removed.",
        "A garden suite has been added, and day programme removed, because this home does not have one. Every home must "
        "keep at least one wing, and the page says so if the list is emptied."),
    "m_home_lead": (3,
        "Page 4 of 4: who leads it — Dana herself, or someone invited by email.",
        "Page four: who leads the home. Either Dana leads it herself, or she invites someone, which asks for their work "
        "email and, optionally, their name. A home lead invites their own staff and sees the home's dashboard. Dana "
        "leads this one. Now the home is added, and the journey brings her back to the list."),
    "m_home_added": (3,
        "The home's card: wings, status, counts, address, CQC location, capacity.",
        "Willowbank Lodge is listed, with its wings as chips, its status, which is setting up until it has a lead and "
        "a roster, the number of residents and staff with access, its address, CQC location and capacity. Behind the "
        "scenes the server has re-issued Dana's sign-in token so that it carries the new home, and the phone starts "
        "syncing it. Nothing had to be restarted."),
    "m_export": (3,
        "Per-home export: residents or sessions as CSV, everything as JSON, ready to share.",
        "Every home can be exported, which matters for an organisation that has to answer for its data. Residents as a "
        "spreadsheet, sessions as a spreadsheet, or everything as JSON. The file is built by the server for this home "
        "only, and the app offers it through the share sheet, to Files, to mail, wherever it needs to go. The export "
        "itself is recorded in the audit trail."),

    # ---- 4 · Team and invites --------------------------------------------------------------------------------------
    "m_team": (4,
        "Team: invite one person, or several at once. Staff never register themselves.",
        "The team. Staff never register themselves: someone with the right to invite sends an invite, and the person "
        "accepts it. There are two ways to start, one person or several at once, and below them, invites waiting to be "
        "accepted and the staff who are already in."),
    "m_invite_who": (4,
        "Invite page 1 of 2: who. A real work email is required; a name is optional.",
        "Inviting one person takes two pages. First, who: a work email, which is required, and a name, which is optional, "
        "because the person confirms their own name when they accept."),
    "m_invite_invalid": (4,
        "An email without its ending is caught before anything is sent.",
        "The email was typed without its ending. Sam at willowbank is not an address yet, so the field says so, in words, "
        "and suggests the shape: name at company dot co dot uk. No spaces are allowed, and the field strips them as "
        "they are typed."),
    "m_invite_access": (4,
        "Invite page 2 of 2: role, which homes, and an optional end date.",
        "Page two: what they can do. A role: supervisor, home lead, or organisation admin. Which homes, shown as chips, "
        "because an invite is always scoped to homes, and an organisation admin reaches all of them. And an optional "
        "end date."),
    "m_invite_cover": (4,
        "Temporary cover: access ends on a date, then the account stops working.",
        "Temporary cover is for agency staff. Switching it on adds a date picker, and after that date the account can no "
        "longer sign in, with no one having to remember to remove it. It is switched off again here, because Sam is "
        "permanent."),
    "m_invited": (4,
        "An INV- code: hashed at rest, single use, seven days; a resend voids the old one.",
        "The invite is sent, and the team page shows it as waiting. The code starts with INV, is stored only as a hash, "
        "works once, and expires after seven days. Resending issues a fresh code and voids the old one. The code is "
        "displayed here only because this is the demo backend; normally it arrives by email, and this tile is the "
        "fallback if the email does not."),
    "m_bulk": (4,
        "Several at once: one person per line — email, name, role, home.",
        "Inviting several at once. One person per line: the email, then the name, the role, and the home. Leave the home "
        "out and the person joins the organisation's first home. Up to fifty lines at a time. It is meant for pasting "
        "from a spreadsheet."),
    "m_bulk_send": (4,
        "Two good lines and one half-typed address.",
        "Three lines have been pasted. Amy as a supervisor, Ben as a home lead, and a third where the email is "
        "unfinished. Sending checks every line, individually."),
    "m_bulk_partial": (4,
        "Two sent; only the faulty line stays, with the reason next to it.",
        "Two invites went out, and the notice says two sent, one skipped. Only the line that needs fixing is left in the "
        "box, with the reason listed under it, so pressing send again can never send the first two a second time. "
        "Fixing the address and sending again finishes the job."),
    "m_team_pending": (4,
        "Waiting to be accepted: each invite with its role, home, expiry and a status chip.",
        "Back on the team page, every invite is listed under waiting to be accepted: who it is for, their role, the home, "
        "when it expires, and a status chip that says pending in words as well as colour. The codes are only shown to the "
        "administrator who sent them."),
    "m_team_resend": (4,
        "Resend: a new code, and the old one stops working.",
        "Resend. The server issues a new code and the old one no longer works, so a lost invite cannot be used by "
        "anyone who finds it later."),
    "m_team_revoke": (4,
        "Revoke: the invite is withdrawn.",
        "Revoke withdraws an invite entirely. Carol's invite is withdrawn before she has used it, and its code stops "
        "working at once. Each of these actions is a line in the audit trail."),

    # ---- 5 · Residents (testMobileC_SetupResidentsIpadsReady) ---------------------------------------------------------
    "m_resume": (5,
        "Come back later: the dashboard has an organisation set-up card.",
        "Set-up does not have to be finished in one sitting. This is the home dashboard, opened later, and it carries "
        "a card for the organisation set-up, which says what is still to do. Nothing in set-up blocks a care "
        "session, so the home can already be in use while the rest is finished."),
    "m_resume_card": (5,
        "Continue set-up resumes at the first page still to do.",
        "Continue set-up does not start again at page one. It opens on the first page that still needs something, "
        "which here is residents, because the organisation, the home and the team are done."),
    "m_residents": (5,
        "Residents: a spreadsheet, or one at a time through discovery.",
        "Residents. There are two ways in. A spreadsheet, which is the fast way for a home that already has its roster "
        "in a file. Or one at a time, through the discovery pass, which also learns each person's music. The spreadsheet "
        "route is shown here."),
    "m_template": (5,
        "The columns: name, room, wing, age, nationality, favourite genre, notes. Name and age are required.",
        "The template says which columns it expects: name, room, wing, age or date of birth, nationality, favourite "
        "genre and notes. Only the name and the age are required. There is a button to copy the template, and a "
        "button to choose a CSV file from Files. For the film, there is a sample spreadsheet."),
    "m_preview": (5,
        "The review page: every row is checked before anyone is added.",
        "The sample is read, and the review page shows each row on its own. Every row is checked before anything is "
        "written: an unknown wing falls back to the first one with a note, an age outside fifty-five to one hundred and "
        "five is skipped, a name with digits in it is rejected, and a resident already on the roster is flagged. The "
        "bar says how many will be imported, and there is a way to discard the file."),
    "m_imported": (5,
        "Three residents on the roster, marked 'discovery not yet run'.",
        "Imported. The three residents are on the roster, marked discovery not yet run, and the same sync that carries "
        "every other edit pushes them to the server, so every iPad in the home sees them. Their music profiles start "
        "from nationality and age until someone runs their discovery."),

    # ---- 6 · iPads and ready -------------------------------------------------------------------------------------------
    "m_ipads": (6,
        "Shared iPads: Guided Access, auto-lock, no personal accounts, managed deployment.",
        "The iPads. Guidance for the shared tablets on the floor: Guided Access, so a resident cannot leave the app; "
        "auto-lock and a passcode only staff know; no personal Apple accounts; the PIN re-prompt from the defaults; and "
        "managed deployment through Apple Business Manager. It is guidance, not enforcement, and the app works without "
        "any of it."),
    "m_register": (6,
        "Register this iPad: which home it belongs to, and a label.",
        "Registering this iPad says which home it belongs to, so that a tablet found in the wrong wing can be identified, "
        "and gives it a label that a person will recognise, like day room."),
    "m_label_required": (6,
        "The label is required: the message says so, under the field.",
        "Registering without a label is refused with a message under the field. A label is the whole point of the "
        "registration, so it is required, and between two and sixty characters, letters, numbers and ordinary "
        "punctuation."),
    "m_registered": (6,
        "Registered: it appears in the list with its model, home and last-seen time.",
        "Registered. This iPad now belongs to Willowbank Lodge, and it is listed with its model, its home and when it "
        "was last seen. If it is ever lost or retired, it can be removed from this page."),
    "m_ready": (6,
        "The checklist: organisation profile, homes, team, residents, iPads, email domains.",
        "The last section. A live checklist of what is in place: the organisation profile, homes, team, residents, "
        "iPads and email domains, each with a status chip that says done or to do in words. Below it are first-week "
        "nudges, such as an invite still waiting, or residents who have not yet had a discovery pass."),
    "m_audit": (6,
        "The audit trail: every set-up action, with who and when. Append-only.",
        "And the audit trail. Every set-up action is a line: who did it, what, and when. Organisation activated, home "
        "created, invite sent, iPad registered. The trail is append only, so nothing can be edited or deleted afterwards, "
        "which is what an inspection or a data request needs."),
    "m_finished": (6,
        "Finish lands on the new home's dashboard: empty until the first sessions.",
        "Finish set-up, and the new home's dashboard opens. It is empty, because no sessions have been run yet, and it "
        "will fill with trends, wing impact and the group programme as staff begin. The set-up card now reads set-up "
        "complete, with the date, and still opens the set-up again at any time."),

    # ---- 7 · A colleague joins (testMobileD_ColleagueJoins) --------------------------------------------------------------
    "m_join": (7,
        "Sam, invited earlier, joins with an invite code: 'I have an invite or activation code'.",
        "Now Sam, the supervisor who was invited. On the sign-in screen, Sam taps I have an invite or activation code, "
        "and enters the work email the invite was sent to, and the code. A wrong email reads exactly like a wrong code, "
        "so nothing about who was invited ever leaks."),
    "m_join_preview": (7,
        "The invite shows what it unlocks before a PIN is chosen: the organisation, the role, the home.",
        "Before anything is created, the invite is previewed: Willowbank Care, supervisor, Willowbank Lodge. Sam can see "
        "what the code unlocks. The name comes from the invite, so it does not need typing."),
    "m_join_pin": (7,
        "Sam chooses a PIN of their own, and acknowledges how resident data is handled.",
        "Sam chooses a six digit PIN, twice. It is hashed on the server, and nobody, including the administrator, can "
        "ever read it. An administrator can only reset it. Then the same data handling statement."),
    "m_join_accept": (7,
        "Accepting creates the account, records the consent and signs in.",
        "Accepting creates Sam's account with the chosen PIN, records the consent, marks the home active, marks the "
        "invite as used so the code can never work again, and signs Sam in."),
    "m_join_roster": (7,
        "Sam's roster: the residents Dana imported, already synced.",
        "Sam's roster. The residents that Dana imported a few minutes ago are already here, synced to this account. A "
        "supervisor only ever sees the homes in their invite."),

    # ---- 8 · Home admin dashboard (testMobileE_HomeAdminDashboard) ---------------------------------------------------------
    "m_admin_signin": (8,
        "Alex, a home lead, signs in with the same email and PIN.",
        "Now the admin screens, with a home lead who has real data behind them. Alex signs in as everyone does, with a "
        "work email and a six digit PIN, which the server checks."),
    "m_admin_picker": (8,
        "Two homes: choose which one to review.",
        "Alex looks after two homes, so the app asks which one to review today, and shows how many residents and wings "
        "each has. A home lead with one home goes straight in. Someone who runs the organisation would also see "
        "Organisation set-up here."),
    "m_admin_dash": (8,
        "The home dashboard: the last 14 days at a glance, designed for the phone first.",
        "Maple Lodge's dashboard, designed for the phone first: one column, large touch targets, text that wraps "
        "instead of truncating. The title says what the numbers cover, the last fourteen days, and who is looking. "
        "First, the home trends: four small charts, sessions each day, residents reached, how at ease people were, "
        "and carer observed wellbeing. Swipe sideways through them."),
    "m_admin_trend": (8,
        "Tap a chart to expand it; tap again to collapse.",
        "Tapping a chart expands it for a closer look, with its axis and the latest value. Tap again, and it folds "
        "away."),
    "m_admin_tiles": (8,
        "Four numbers: sessions, residents reached, average at ease, observed wellbeing.",
        "Under the trends, four numbers. How many sessions ran in fourteen days. How many residents were reached out of "
        "how many are active. The average at ease score during sessions, as a percentage. And the carers' observed "
        "wellbeing, as a composite out of ten. Each tile says what it measures underneath."),
    "m_admin_wings": (8,
        "Impact by wing: where calm sessions are landing, with a bar, residents, at-ease and wellbeing for each.",
        "Impact by wing shows where calm sessions are landing across the home. Each wing has a bar for how many sessions "
        "it had, and beneath it three chips: how many residents were reached, how at ease they were, and their "
        "wellbeing. On a phone the chips wrap onto the next line rather than being cut off."),
    "m_admin_group": (8,
        "Group programme: activities this fortnight, who joined, and who has been left out.",
        "The group programme. Group activities over the same fourteen days: how many ran, how many residents took "
        "part, and how engaged and how cheerful the groups were. And a flag, in words and an icon, for residents who "
        "would welcome a group but have had none, with their names, so the next group can include them."),
    "m_admin_improving": (8,
        "Positive session impact: residents trending up against their own recent sessions.",
        "Positive session impact lists residents who are trending up compared with their own recent sessions. Each row "
        "has the name, the room and wing, an improving chip, and the comparison in plain numbers. It is always a person "
        "against their own baseline, never against each other."),
    "m_admin_recent": (8,
        "Recent sessions: every one, with its at-ease score and how the resident presented.",
        "And every recent session, newest first: the resident, the date, the wing, how they presented, the at-ease "
        "score, and whether it was above or below their usual. This is the evidence of impact for the whole home, "
        "in one scrolling column."),

    # ---- 9 · Managing the team (testMobileF_ManageTheTeam) --------------------------------------------------------------------
    "m_manage_dash": (9,
        "Dana signs in again: the organisation admin's dashboard, with the set-up card.",
        "Back to Dana, the organisation administrator, signing in with the PIN she chose at activation. Her dashboard "
        "is the new home's, with the organisation set-up card, which is how she gets back to everything she set up."),
    "m_manage_open": (9,
        "Set-up stays one tap away; the circles jump straight to a section.",
        "Organisation set-up is still one tap away. Because everything is done, it opens on the checklist. The six "
        "circles along the top are buttons, so she can jump straight to any section, and leaving a page with unsent "
        "work asks first, rather than losing it."),
    "m_manage_team": (9,
        "The team page: pending invites and the staff who have joined.",
        "The team page again. Sam has joined, so the waiting list is shorter, and a card for the staff shows how many "
        "are active. Show reveals them."),
    "m_manage_staff": (9,
        "Staff: each person with their role, home and status, and the actions an admin can take.",
        "The staff list. Each person has their name, email, role, homes and a status chip. For anyone other than "
        "herself, Dana has four actions: suspend, restore, reset the PIN, and remove. She cannot do any of these to "
        "her own account, so she can never lock herself out."),
    "m_manage_suspended": (9,
        "Suspended: the account can no longer sign in, and the status says so.",
        "Suspending Sam. The status chip changes to suspended, in words and colour, and from this moment the server "
        "refuses Sam's sign-in and any refresh of an existing session. It is the right tool for an unexplained "
        "absence or a lost phone, and it can be undone."),
    "m_manage_restored": (9,
        "Restore: access is back.",
        "Restore, and Sam can sign in again. Both changes are lines in the audit trail, with Dana's name and the time."),
    "m_manage_reset": (9,
        "Reset PIN: a one-time code the person enters under Forgot PIN, valid ten minutes.",
        "Reset PIN does not set a new PIN, because no one but the person should know it. It creates a one time code, "
        "valid for ten minutes, that Sam enters on the sign-in screen under forgot PIN, and then chooses a new PIN. On a "
        "real deployment it is emailed to Sam. On this demo backend it is shown here, so the film needs no mailbox."),
}

N.SCRIPT.update(SCRIPT)
