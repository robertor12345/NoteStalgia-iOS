import XCTest

/// Scripted, narrated walkthrough — one chronological story in three continuous takes, each a
/// test. Every step calls `mark(_:)`, which appends `epoch|label` to a markers file on the host
/// (`DEMO_MARKERS_FILE`, default /tmp/notestalgia-demo-markers.log); `tools/demo/pipeline/build_v4.py`
/// cuts captions and voice-over at those marks. Marker names must match the narration script in
/// `tools/demo/pipeline/narration.py`.
///
/// Pacing is deliberately slow: each screen is held long enough for its narration line.
/// `TEST_RUNNER_DEMO_PACE=1.2` stretches every hold by 1.2×. With `TEST_RUNNER_DEMO_NARRATION_FILE`
/// pointing at the JSON that `pipeline/narration.py --durations` writes, the pacing follows the voice:
/// every long hold waits for the line spoken at the last marker to finish (plus a beat), and a marker
/// never starts before the previous line is done, so picture and voice cannot drift apart however
/// detailed the narration gets. These are not assertion-heavy tests.
final class DemoWalkthroughUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pace: Double = 1
    private var markersPath = "/tmp/notestalgia-demo-markers.log"
    /// marker label → seconds of narration (empty = classic fixed holds)
    private var narrationSeconds: [String: Double] = [:]
    private var narrationEndsAt = Date.distantPast
    private let voiceDelay = 0.45    // the pipeline starts a line this long after its marker
    private let voiceGap = 0.5       // and keeps this much silence between two lines
    /// `TEST_RUNNER_DEMO_AUDIT_DIR=<dir>`: every `mark` also saves a screenshot and the controls on screen
    /// (the screen sweep, `docs/UX_SWEEP_2026-10-30.md`). Unset for recordings.
    private var auditDir: String?
    private var auditScroll = false
    private var auditCount = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        pace = Double(env["DEMO_PACE"] ?? "") ?? 1
        markersPath = env["DEMO_MARKERS_FILE"] ?? markersPath
        auditDir = (env["DEMO_AUDIT_DIR"]?.isEmpty == false) ? env["DEMO_AUDIT_DIR"] : nil
        auditScroll = env["DEMO_AUDIT_SCROLL"] == "1"
        auditCount = 0
        if let path = env["DEMO_NARRATION_FILE"], let data = FileManager.default.contents(atPath: path),
           let table = try? JSONSerialization.jsonObject(with: data) as? [String: Double] {
            narrationSeconds = table
        }
        narrationEndsAt = .distantPast
        app = XCUIApplication()
    }

    // MARK: - Part A · Sign-in → roster → profile → calm surface → observation → summary

    func testStoryPartA_SignInToSummary() throws {
        launch(autoSignIn: false, skipLaunch: false)
        mark("open")
        let email = app.textFields["signin.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "Sign-in did not appear")
        hold(5)

        mark("signin")
        typeSignIn(email: "max@sunrise-care.co.uk")
        mark("welcome")

        let startDiscovery = app.buttons["roster.startDiscovery"]
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 30), "Roster did not appear")
        mark("roster")
        hold(14)

        mark("roster_scroll")
        slowScroll(points: 520)
        hold(5)
        slowScroll(points: 420)
        hold(4)
        slowScroll(points: -940)
        hold(2)

        mark("wing")
        waitTap(app.buttons["roster.wing.Memory care"])
        hold(7)
        waitTap(app.buttons["roster.wing.All wings"])
        hold(2.5)

        mark("compact")
        selectSegment("roster.displayMode", "Compact")
        hold(7)
        selectSegment("roster.displayMode", "Cards")
        hold(2.5)

        mark("profile")
        openResident(named: "Irene K.")
        hold(12)
        mark("profile_scroll1")
        slowScroll(points: 560)
        hold(12.5)
        mark("profile_scroll2")
        slowScroll(points: 620)
        hold(10)
        mark("profile_scroll3")
        slowScroll(points: 640)
        hold(13)
        mark("profile_top")
        slowScroll(points: -1900)
        hold(2)

        mark("handoff")
        waitTap(app.buttons["profile.openSurface"])
        let glyphs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'surface.glyph.'"))
        XCTAssertTrue(glyphs.firstMatch.waitForExistence(timeout: 20), "Calm surface did not appear")
        mark("surface")
        hold(14)

        mark("play")
        glyphs.element(boundBy: 0).tap()
        hold(12)
        mark("sun")
        waitTap(app.buttons["surface.like"])
        hold(9)
        if glyphs.count > 1 {
            mark("switch")
            glyphs.element(boundBy: 1).tap()
            hold(10)
            mark("cloud")
            waitTap(app.buttons["surface.skip"])
            hold(8)
        }

        mark("staffkey")
        hold(5)
        let staffKey = app.buttons["surface.staffKey"]
        XCTAssertTrue(staffKey.waitForExistence(timeout: 10))
        staffKey.press(forDuration: 1.4)
        XCTAssertTrue(app.buttons["rating.8"].waitForExistence(timeout: 15), "Observation form did not appear")
        mark("captured")
        hold(12.5)

        mark("tags")
        tapIfPresent(app.buttons["observation.chip.Settled at baseline"])
        hold(1.5)
        tapIfPresent(app.buttons["observation.chip.Lights dimmed"])
        hold(6)

        mark("ratings")
        scrollTo(app.buttons["rating.8"])
        hold(1)
        for value in [8, 7, 8, 9] {
            app.buttons["rating.\(value)"].tap()
            hold(2.4)
        }
        hold(1)
        mark("note")
        let note = app.descendants(matching: .any)["observation.note"]
        if scrollTo(note, assert: false) {
            note.tap()
            hold(0.8)
            note.typeText("Hummed along to the soul track and smiled.")
            hold(3)
        }
        mark("save")
        scrollTo(app.buttons["observation.save"]).tap()

        let done = app.buttons["summary.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Session summary did not appear")
        mark("insight")
        hold(13)
        mark("insight_scroll1")
        slowScroll(points: 560)
        hold(10)
        mark("insight_scroll2")
        slowScroll(points: 620)
        hold(10)
        mark("copy")
        selectSegment("summary.shareKind", "Family")
        hold(4)
        scrollTo(app.buttons["summary.copy"]).tap()
        hold(4)
        mark("done")
        scrollTo(done).tap()
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 15))
        hold(6)
        mark("end")
    }

    // MARK: - Part B · New-resident discovery → save → group mode → check-in

    func testStoryPartB_DiscoveryAndGroup() throws {
        launch(autoSignIn: true, skipLaunch: true)
        let startDiscovery = app.buttons["roster.startDiscovery"]
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 30), "Roster did not appear")
        mark("newres")
        hold(8)
        startDiscovery.tap()

        let age = app.textFields["discovery.age"]
        XCTAssertTrue(age.waitForExistence(timeout: 15), "Discovery age screen did not appear")
        mark("agenat")
        hold(5)
        age.tap()
        hold(0.8)
        age.typeText("82")
        hold(5)
        waitTap(app.buttons["discovery.begin"])

        let reactions = ["pleasant", "neutral", "pleasant", "unpleasant", "pleasant", "pleasant", "neutral"]
        for (index, reaction) in reactions.enumerated() {
            let face = app.buttons["discovery.face.\(reaction)"]
            let started = face.waitForExistence(timeout: 20)
            if !started {
                snap("b_clip_fail")
                try? app.debugDescription.write(toFile: "/tmp/ns-b-hierarchy.txt", atomically: true, encoding: .utf8)
            }
            XCTAssertTrue(started, "Clip \(index + 1) did not start")
            switch index {
            case 0: mark("clips"); hold(10)
            case 1: mark("clipstap"); hold(7)
            case 3: mark("clipsall"); hold(6)
            default: hold(5)
            }
            face.tap()
            hold(1.8)
        }

        let glyphs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'surface.glyph.'"))
        XCTAssertTrue(glyphs.firstMatch.waitForExistence(timeout: 30), "First calm surface did not appear")
        mark("result")
        hold(8)
        glyphs.element(boundBy: 0).tap()
        hold(9)

        mark("staffkey2")
        let staffKey = app.buttons["surface.staffKey"]
        XCTAssertTrue(staffKey.waitForExistence(timeout: 10))
        staffKey.press(forDuration: 1.4)

        let name = app.textFields["newResident.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Save-resident form did not appear")
        mark("saveres")
        hold(5)
        name.tap()
        hold(0.8)
        name.typeText("Edith P.")
        hold(4)
        dismissKeyboard()
        scrollTo(app.buttons["newResident.save"]).tap()
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 20), "Roster did not return after save")
        mark("saved")
        hold(4)
        slowScroll(points: 520)
        hold(6)
        slowScroll(points: -520)
        hold(2)

        mark("group")
        waitTap(app.buttons["roster.groupMode"])
        let plannerStart = app.buttons["planner.start"]
        if !plannerStart.waitForExistence(timeout: 6) {
            app.buttons["roster.groupMode"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(plannerStart.waitForExistence(timeout: 20), "Group planner did not appear")
        mark("planner")
        hold(10)
        slowScroll(points: 520)
        hold(6)
        scrollTo(plannerStart).tap()
        let play = app.buttons["group.playPause"]
        XCTAssertTrue(play.waitForExistence(timeout: 20), "Group mode did not appear")
        hold(13)
        mark("groupctl")
        waitTap(app.buttons["group.next"])
        hold(7)
        let tracks = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group.track.'"))
        if tracks.count > 2 {
            tracks.element(boundBy: 2).tap()
            hold(7)
        }
        mark("groupend")
        waitTap(app.buttons["group.end"])
        XCTAssertTrue(app.buttons["rating.7"].waitForExistence(timeout: 15), "Group check-in did not appear")
        mark("groupfb")
        hold(7)
        for value in [7, 8, 8, 7] {
            app.buttons["rating.\(value)"].tap()
            hold(2.0)
        }
        hold(1)
        scrollTo(app.buttons["group.save"]).tap()
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 15))
        mark("groupsaved")
        hold(7)
        mark("end")
    }

    // MARK: - Part C · Home admin insights

    func testStoryPartC_Admin() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let email = app.textFields["signin.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "Sign-in did not appear")
        mark("adminsign")
        hold(2)
        typeSignIn(email: "alex@sunrise-care.co.uk")

        let home = app.buttons["homePicker.Maple Lodge"]
        XCTAssertTrue(home.waitForExistence(timeout: 25), "Home picker did not appear")
        mark("picker")
        hold(8)
        home.tap()
        mark("adminwelcome")
        XCTAssertTrue(app.buttons["chrome.back"].waitForExistence(timeout: 25), "Dashboard did not appear")
        mark("dash")
        hold(12)
        mark("expand")
        let trends = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'admin.trend.'"))
        if trends.count > 0 {
            trends.element(boundBy: 0).tap()
            hold(8)
        }
        mark("impact")
        slowScroll(points: 560)
        hold(9)
        slowScroll(points: 620)
        hold(9)
        mark("end")
        hold(2)
    }

    // MARK: - Part D · Care at home: create account → register → home → session → insights → Claire's household

    func testStoryPartD_Household() throws {
        launch(autoSignIn: false, skipLaunch: true, resetHouseholds: true)
        let create = app.buttons["signin.createHousehold"]
        XCTAssertTrue(create.waitForExistence(timeout: 30), "Sign-in did not appear")
        mark("home_open")
        hold(7)
        create.tap()
        let yourName = app.textFields["household.name"]
        if !yourName.waitForExistence(timeout: 6) {
            create.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(yourName.waitForExistence(timeout: 15), "Sign-up did not appear")
        mark("home_signup")
        hold(3)
        yourName.tap()
        hold(0.6)
        yourName.typeText("Priya")
        hold(0.8)
        let email = app.textFields["household.email"]
        email.tap()
        hold(0.6)
        // Against a backend every run needs a fresh email (the server remembers the last one).
        let storyEmail = ProcessInfo.processInfo.environment["API_BASE_URL"].map { _ in "priya\(Int(Date().timeIntervalSince1970) % 100_000)@example.com" } ?? "priya@example.com"
        email.typeText(storyEmail)
        hold(1)
        selectSegment("household.relationship", "Private carer")
        hold(1.5)
        let pin = app.textFields["household.pin"]
        pin.tap()
        hold(0.6)
        for digit in "123456" { pin.typeText(String(digit)); hold(0.3) }
        hold(0.8)
        let confirm = app.textFields["household.confirmPin"]
        confirm.tap()
        hold(0.6)
        for digit in "123456" { confirm.typeText(String(digit)); hold(0.3) }
        let residentName = app.textFields["household.residentName"]
        if !residentName.waitForExistence(timeout: 4) {
            scrollTo(app.buttons["household.create"]).tap()
        }
        XCTAssertTrue(residentName.waitForExistence(timeout: 15), "Resident setup did not appear")

        mark("home_register")
        hold(4)
        residentName.tap()
        hold(0.6)
        residentName.typeText("Arun S.")
        hold(0.8)
        let age = app.textFields["household.residentAge"]
        age.tap()
        hold(0.6)
        age.typeText("84")
        hold(1)
        tapPageTitleToDismissKeyboard("Who are you caring for?")
        hold(3)
        mark("home_choice")
        hold(6)
        scrollTo(app.buttons["household.skipDiscovery"]).tap()

        let openSurface = app.buttons["household.openSurface"]
        XCTAssertTrue(openSurface.waitForExistence(timeout: 20), "Household home did not appear")
        mark("home_home")
        hold(14)

        openSurface.tap()
        let glyphs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'surface.glyph.'"))
        XCTAssertTrue(glyphs.firstMatch.waitForExistence(timeout: 20), "Calm surface did not appear")
        mark("home_surface")
        hold(7)
        glyphs.element(boundBy: 0).tap()
        hold(10)
        waitTap(app.buttons["surface.like"])
        hold(5)
        let staffKey = app.buttons["surface.staffKey"]
        XCTAssertTrue(staffKey.waitForExistence(timeout: 10))
        staffKey.press(forDuration: 1.4)
        XCTAssertTrue(app.buttons["rating.8"].waitForExistence(timeout: 15), "Observation form did not appear")
        mark("home_observe")
        hold(6)
        scrollTo(app.buttons["rating.8"])
        for value in [8, 7, 8, 7] {
            app.buttons["rating.\(value)"].tap()
            hold(2.0)
        }
        hold(1)
        scrollTo(app.buttons["observation.save"]).tap()

        let done = app.buttons["summary.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Session summary did not appear")
        mark("home_summary")
        hold(6)
        selectSegment("summary.shareKind", "Family")
        hold(3)
        slowScroll(points: 560)
        hold(5)
        scrollTo(done).tap()
        XCTAssertTrue(openSurface.waitForExistence(timeout: 15), "Summary did not return home")
        mark("home_insights1")
        hold(3)
        waitTap(app.buttons["household.insights"])
        XCTAssertTrue(app.staticTexts["Arun’s insights"].waitForExistence(timeout: 15), "First insights did not appear")
        hold(9)
        waitTap(app.buttons["chrome.back"])
        XCTAssertTrue(openSurface.waitForExistence(timeout: 15))
        hold(1.5)
        waitTap(app.buttons["chrome.logout"])

        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 15))
        mark("home_demo")
        hold(2)
        typeSignIn(email: "claire@example.com")
        XCTAssertTrue(openSurface.waitForExistence(timeout: 30), "Demo household home did not appear")
        XCTAssertTrue(app.staticTexts["Harold T."].waitForExistence(timeout: 5))
        hold(7)
        waitTap(app.buttons["household.insights"])
        XCTAssertTrue(app.staticTexts["Harold’s insights"].waitForExistence(timeout: 15), "Demo insights did not appear")
        mark("home_insights2")
        hold(13)
        slowScroll(points: 560)
        hold(6)
        mark("home_next")
        slowScroll(points: 620)
        hold(9)
        mark("end")
        hold(2)
    }

    // MARK: - Group activities · planner → chosen activity → session → check-in

    func testGroupPlannerWalkthrough() throws {
        launch(autoSignIn: true, skipLaunch: true)
        let groupMode = app.buttons["roster.groupMode"]
        XCTAssertTrue(groupMode.waitForExistence(timeout: 30), "Roster did not appear")
        scrollTo(groupMode).tap()
        let start = app.buttons["planner.start"]
        if !start.waitForExistence(timeout: 6) {
            groupMode.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Planner did not appear")
        mark("planner_open")
        hold(2)
        let activities = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'planner.activity.'"))
        XCTAssertTrue(activities.firstMatch.waitForExistence(timeout: 5), "No suggested activity")
        activities.element(boundBy: min(1, activities.count - 1)).tap()
        hold(1.5)
        let residents = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'planner.resident.'"))
        XCTAssertTrue(residents.firstMatch.waitForExistence(timeout: 5), "No residents listed")
        scrollTo(residents.element(boundBy: 0)).tap()      // toggle the top resident
        hold(1)
        scrollTo(start).tap()
        XCTAssertTrue(app.buttons["group.playPause"].waitForExistence(timeout: 20), "Group session did not start")
        XCTAssertTrue(app.staticTexts.matching(identifier: "group.activityLine").firstMatch.waitForExistence(timeout: 5), "Activity line missing")
        hold(3)
        waitTap(app.buttons["group.end"])
        XCTAssertTrue(app.buttons["rating.7"].waitForExistence(timeout: 15), "Group check-in did not appear")
        for value in [7, 8, 8, 7] {
            app.buttons["rating.\(value)"].tap()
            hold(1.2)
        }
        hold(1)
        scrollTo(app.buttons["group.save"]).tap()
        XCTAssertTrue(groupMode.waitForExistence(timeout: 15), "Did not return to the roster")

        // Profile: participation line + comfort picker.
        openResident(named: "Irene K.")
        let comfort = app.buttons["Small groups"].firstMatch   // the picker is a row of buttons now (44 pt segments)
        XCTAssertTrue(scrollTo(comfort, assert: false), "Group comfort picker missing on the profile")
        selectSegment("profile.groupComfort", "Small groups")
        hold(0.8)
        XCTAssertTrue(app.staticTexts.matching(identifier: "profile.groupActivities").firstMatch.exists, "Participation line missing")
        waitTap(app.buttons["chrome.back"])
        XCTAssertTrue(groupMode.waitForExistence(timeout: 15))

        // Home admin: group programme card.
        waitTap(app.buttons["chrome.logout"])
        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 15))
        typeSignIn(email: "alex@sunrise-care.co.uk")
        waitTap(app.buttons["homePicker.Maple Lodge"], timeout: 25)
        XCTAssertTrue(app.buttons["chrome.back"].waitForExistence(timeout: 25), "Dashboard did not appear")
        let programme = app.staticTexts["admin.groupProgramme"]
        XCTAssertTrue(scrollTo(programme, assert: false), "Group programme card missing")
        mark("end")
    }

    // MARK: - Activity log · roster → Log an activity → who came and how → saved → programme card

    func testActivityLogWalkthrough() throws {
        launch(autoSignIn: true, skipLaunch: true)
        let log = app.buttons["roster.logActivity"]
        XCTAssertTrue(log.waitForExistence(timeout: 30), "Roster did not appear")

        // Sounds and haptics card (bottom of the roster): off, then on again — turning one on plays what it controls.
        let sounds = app.descendants(matching: .any)["settings.sounds"]
        XCTAssertTrue(scrollTo(sounds, assert: false), "Sounds and haptics card missing from the roster")
        mark("settings_card")
        sounds.tap()
        hold(0.8)
        sounds.tap()
        hold(0.8)

        scrollTo(log).tap()
        let save = app.buttons["activity.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20), "Activity log did not appear")
        mark("activity_open")
        hold(2)

        // Saving an empty form names what is missing instead of doing nothing.
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity.kind.error"].waitForExistence(timeout: 5), "No message for the missing activity")
        hold(1)

        scrollTo(app.buttons["activity.kind.gamesAndQuizzes"]).tap()
        hold(0.8)
        scrollTo(app.buttons["activity.duration.60"]).tap()
        hold(0.8)

        let residents = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.resident.'"))
        XCTAssertTrue(residents.firstMatch.waitForExistence(timeout: 5), "No residents listed")
        scrollTo(residents.element(boundBy: 0)).tap()
        hold(0.6)
        scrollTo(residents.element(boundBy: 1)).tap()
        hold(0.6)
        scrollTo(residents.element(boundBy: 2)).tap()
        hold(1)

        // Three people came and none has a line yet: Save says who is missing.
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity.responses.error"].waitForExistence(timeout: 5), "No message for the missing lines")
        mark("activity_missing")
        hold(1.5)

        // One chip per attendee per option: tap each attendee's own row of options in turn.
        let enjoyed = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.response.' AND identifier ENDSWITH '.enjoyed'"))
        let engaged = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.response.' AND identifier ENDSWITH '.engaged'"))
        let lookedOn = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.response.' AND identifier ENDSWITH '.lookedOn'"))
        scrollTo(enjoyed.element(boundBy: 0)).tap()
        hold(0.5)
        scrollTo(engaged.element(boundBy: 1)).tap()
        hold(0.5)
        scrollTo(lookedOn.element(boundBy: 2)).tap()
        hold(1)
        mark("activity_noted")

        scrollTo(save).tap()
        XCTAssertTrue(app.buttons["roster.groupMode"].waitForExistence(timeout: 15), "Did not return to the roster")
        XCTAssertTrue(scrollTo(app.descendants(matching: .any)["roster.lastLoggedActivity"], assert: false), "Roster does not show the logged activity")
        mark("activity_saved")
        hold(1.5)

        // Correct it: the form comes back filled in, and saving replaces the original.
        scrollTo(app.buttons["roster.logActivity"]).tap()
        let recent = app.buttons["activity.recent"]
        XCTAssertTrue(recent.waitForExistence(timeout: 15), "Logged recently card missing")
        recent.tap()
        let correct = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.recent.correct.'")).firstMatch
        XCTAssertTrue(correct.waitForExistence(timeout: 5), "No Correct button")
        correct.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity.correcting"].waitForExistence(timeout: 5), "Correcting notice missing")
        mark("activity_correcting")
        hold(1.5)
        scrollTo(app.buttons["activity.save"]).tap()
        XCTAssertTrue(app.buttons["roster.groupMode"].waitForExistence(timeout: 15), "Did not return to the roster after correcting")

        // Repeat it: same activity and people, nothing yet said about how anyone was; backing out saves nothing.
        scrollTo(app.buttons["roster.logActivity"]).tap()
        XCTAssertTrue(recent.waitForExistence(timeout: 15), "Logged recently card missing")
        recent.tap()
        let again = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.recent.repeat.'")).firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 5), "No Repeat button")
        again.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity.repeating"].waitForExistence(timeout: 5), "Repeat notice missing")
        XCTAssertTrue(app.staticTexts["3 to note"].waitForExistence(timeout: 5) || app.staticTexts["3 to note"].exists, "A repeat should come back with everyone still to note")
        mark("activity_repeating")
        hold(1.5)
        waitTap(app.buttons["chrome.back"])
        XCTAssertTrue(scrollTo(app.buttons["roster.logActivity"], assert: false), "Did not return to the roster after repeating")

        // Remove it: it comes off the roster line (the earlier demo activity is the last one again).
        scrollTo(app.buttons["roster.logActivity"]).tap()
        XCTAssertTrue(recent.waitForExistence(timeout: 15), "Logged recently card missing")
        recent.tap()
        let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.recent.remove.'")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "No Remove button")
        remove.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove “'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Remove was not confirmed")
        mark("activity_remove")
        hold(1.2)
        confirm.tap()
        hold(0.8)
        waitTap(app.buttons["chrome.back"])
        XCTAssertTrue(app.buttons["roster.groupMode"].waitForExistence(timeout: 15), "Did not return to the roster after removing")
        let last = app.descendants(matching: .any)["roster.lastLoggedActivity"]
        XCTAssertTrue(scrollTo(last, assert: false), "Roster lost its last-logged line")
        XCTAssertTrue(last.label.contains("Exercise"), "The removed activity still shows: \(last.label)")
        mark("activity_removed")
        hold(1)

        // Home admin: the programme card counts it.
        waitTap(app.buttons["chrome.logout"])
        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 15))
        typeSignIn(email: "alex@sunrise-care.co.uk")
        waitTap(app.buttons["homePicker.Maple Lodge"], timeout: 25)
        XCTAssertTrue(app.buttons["chrome.back"].waitForExistence(timeout: 25), "Dashboard did not appear")
        XCTAssertTrue(scrollTo(app.staticTexts["admin.groupProgramme"], assert: false), "Group programme card missing")
        XCTAssertTrue(app.descendants(matching: .any)["Outside the app"].exists || app.staticTexts["Outside the app"].exists, "Outside the app tile missing")
        mark("end")
    }

    // MARK: - Care at home · log an activity for the one person → their insights

    func testHouseholdActivityLogWalkthrough() throws {
        launchAs("claire@example.com", pin: "123456")
        let log = app.buttons["household.logActivity"]
        XCTAssertTrue(log.waitForExistence(timeout: 30), "Care at home did not show the Log an activity card")
        mark("hh_home")
        hold(1.5)
        scrollTo(log).tap()
        let save = app.buttons["activity.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20), "Activity log did not appear")
        // One person: no list to pick from, only how they were.
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.resident.'")).firstMatch.exists, "A Care at home form should not list residents")
        mark("hh_open")
        hold(1.5)

        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity.kind.error"].waitForExistence(timeout: 5), "No message for the missing activity")
        scrollTo(app.buttons["activity.kind.outing"]).tap()
        hold(0.6)
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activity.responses.error"].waitForExistence(timeout: 5), "No message for how they were")
        mark("hh_missing")
        hold(1.2)

        let enjoyed = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.response.' AND identifier ENDSWITH '.enjoyed'")).firstMatch
        scrollTo(enjoyed).tap()
        hold(1)
        mark("hh_noted")
        scrollTo(save).tap()
        XCTAssertTrue(app.buttons["household.openSurface"].waitForExistence(timeout: 20), "Did not return to the household home")

        waitTap(app.buttons["household.insights"])
        XCTAssertTrue(app.staticTexts["Harold’s insights"].waitForExistence(timeout: 15), "Insights did not appear")
        let card = app.descendants(matching: .any)["household.activities"]
        XCTAssertTrue(scrollTo(card, assert: false), "Outside the app card missing from the insights")
        XCTAssertTrue(app.staticTexts["Outing"].waitForExistence(timeout: 5) || app.staticTexts["Outing"].exists, "The logged outing is not listed")
        mark("hh_insights")
        hold(2)
        mark("end")
    }

    // MARK: - Care at home · sign-up → register resident → home → session → insights → relaunch → demo household

    func testHouseholdWalkthrough() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let create = app.buttons["signin.createHousehold"]
        XCTAssertTrue(create.waitForExistence(timeout: 30), "Sign-in did not appear")
        mark("household_open")
        hold(2)
        create.tap()

        let yourName = app.textFields["household.name"]
        if !yourName.waitForExistence(timeout: 6) {
            // A first tap right after a cold launch has been seen to land without effect; try once more.
            create.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(yourName.waitForExistence(timeout: 15), "Sign-up did not appear")
        mark("household_signup")
        hold(2)
        yourName.tap()
        yourName.typeText("Priya")
        let email = app.textFields["household.email"]
        let uniqueEmail = "priya\(Int(Date().timeIntervalSince1970) % 100_000)@example.com"
        email.tap()
        email.typeText(uniqueEmail)
        hold(0.5)
        selectSegment("household.relationship", "Private carer")
        hold(0.5)
        let pin = app.textFields["household.pin"]
        pin.tap()
        for digit in "123456" { pin.typeText(String(digit)); hold(0.2) }
        let confirm = app.textFields["household.confirmPin"]
        confirm.tap()
        for digit in "123456" { confirm.typeText(String(digit)); hold(0.2) }
        hold(1)
        let residentName = app.textFields["household.residentName"]
        if !residentName.waitForExistence(timeout: 4) {
            scrollTo(app.buttons["household.create"]).tap()
        }
        XCTAssertTrue(residentName.waitForExistence(timeout: 15), "Resident setup did not appear")

        mark("household_resident")
        hold(2)
        residentName.tap()
        residentName.typeText("Arun S.")
        let age = app.textFields["household.residentAge"]
        age.tap()
        age.typeText("84")
        hold(0.5)
        tapPageTitleToDismissKeyboard("Who are you caring for?")   // dismiss the number pad
        hold(0.6)
        scrollTo(app.buttons["household.skipDiscovery"]).tap()

        let openSurface = app.buttons["household.openSurface"]
        XCTAssertTrue(openSurface.waitForExistence(timeout: 20), "Household home did not appear")
        XCTAssertTrue(app.staticTexts["Arun S."].waitForExistence(timeout: 5), "Resident name missing on home")
        mark("household_home")
        hold(3)

        waitTap(app.buttons["household.insights"])
        let insightsBack = app.buttons["household.insightsBack"]
        XCTAssertTrue(insightsBack.waitForExistence(timeout: 15), "Empty insights did not appear")
        hold(2)
        scrollTo(insightsBack).tap()
        XCTAssertTrue(openSurface.waitForExistence(timeout: 15))

        waitTap(app.buttons["household.profile"])
        XCTAssertTrue(app.buttons["profile.openSurface"].waitForExistence(timeout: 15), "Profile did not open")
        hold(2)
        waitTap(app.buttons["chrome.back"])
        XCTAssertTrue(openSurface.waitForExistence(timeout: 15), "Profile back did not return home")

        // One session: calm surface → play → staff hold → ratings → save → summary → done → home.
        openSurface.tap()
        let glyphs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'surface.glyph.'"))
        XCTAssertTrue(glyphs.firstMatch.waitForExistence(timeout: 20), "Calm surface did not appear")
        mark("household_surface")
        hold(2)
        glyphs.element(boundBy: 0).tap()
        hold(6)
        let staffKey = app.buttons["surface.staffKey"]
        XCTAssertTrue(staffKey.waitForExistence(timeout: 10))
        staffKey.press(forDuration: 1.4)
        XCTAssertTrue(app.buttons["rating.8"].waitForExistence(timeout: 15), "Observation form did not appear")
        for value in [8, 7, 8, 7] {
            app.buttons["rating.\(value)"].tap()
            hold(1.2)
        }
        hold(1)
        scrollTo(app.buttons["observation.save"]).tap()
        let done = app.buttons["summary.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Session summary did not appear")
        hold(2)
        scrollTo(done).tap()
        XCTAssertTrue(openSurface.waitForExistence(timeout: 15), "Summary did not return to the household home")

        waitTap(app.buttons["household.insights"])
        XCTAssertTrue(app.staticTexts["Arun’s insights"].waitForExistence(timeout: 15), "Insights with data did not appear")
        mark("household_insights")
        hold(3)
        waitTap(app.buttons["chrome.back"])
        XCTAssertTrue(openSurface.waitForExistence(timeout: 15))

        // Persistence: relaunch and sign in with the new account — the resident must still be there.
        app.terminate()
        launch(autoSignIn: false, skipLaunch: true)
        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 30))
        typeSignIn(email: uniqueEmail)
        XCTAssertTrue(openSurface.waitForExistence(timeout: 30), "Household home did not return after relaunch")
        XCTAssertTrue(app.staticTexts["Arun S."].waitForExistence(timeout: 5), "Stored resident missing after relaunch")
        hold(2)
        waitTap(app.buttons["chrome.logout"])

        // Demo household (Claire → Harold T.) with a fortnight of history.
        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 15))
        typeSignIn(email: "claire@example.com")
        XCTAssertTrue(openSurface.waitForExistence(timeout: 30), "Demo household home did not appear")
        XCTAssertTrue(app.staticTexts["Harold T."].waitForExistence(timeout: 5))
        mark("household_demo")
        hold(2)
        waitTap(app.buttons["household.insights"])
        XCTAssertTrue(app.staticTexts["Harold’s insights"].waitForExistence(timeout: 15), "Demo insights did not appear")
        hold(3)
        slowScroll(points: 600)
        hold(2)
        mark("end")
    }

    // MARK: - v7 · What's new since v6 (three takes; every tap is followed by a hold of ≥ 3 s)
    //
    // Run against the deployed Worker: TEST_RUNNER_API_BASE_URL=https://notestalgia-api.fitraclesub.workers.dev
    // and reset the demo data first (tools/demo/reset-backend.sh) so Irene has no pick and no taste yet.

    /// Part E · live backend sign-in → synced roster + profile → Group activities card → Find a song they
    /// love (search, preview, add) → real-time re-ranking → calm surface with the sleeve → session saved.
    func testStoryPartE_LiveBackend() throws {
        launch(autoSignIn: false, skipLaunch: false)
        mark("v7_open")
        let email = app.textFields["signin.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "Sign-in did not appear")
        hold(11)

        mark("v7_signin")
        hold(14)    // a dwell: the line is spoken before anything is typed
        typeSignIn(email: "max@sunrise-care.co.uk")
        mark("v7_welcome")
        let startDiscovery = app.buttons["roster.startDiscovery"]
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 60), "Roster did not appear")
        mark("v7_roster")
        hold(14)

        mark("v7_profile")
        openResident(named: "Irene K.")
        hold(11)

        mark("v7_group")
        let participation = app.staticTexts.matching(identifier: "profile.groupActivities").firstMatch
        scrollTo(participation)
        hold(12)
        mark("v7_comfort")
        selectSegment("profile.groupComfort", "Small groups")
        hold(12)

        mark("v7_songs")
        let addSong = scrollTo(app.buttons["profile.addSong"])
        hold(12)
        addSong.tap()
        let query = app.textFields["search.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 10), "Search sheet did not appear")
        mark("v7_search")
        hold(3)
        if !app.keyboards.firstMatch.exists { query.tap(); hold(0.6) }
        query.typeText("vera lynn")
        let addButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search.add.'"))
        XCTAssertTrue(addButtons.firstMatch.waitForExistence(timeout: 25), "No search results")
        hold(11)

        mark("v7_preview")
        let play = app.buttons["Play preview of We'll Meet Again"]
        if play.waitForExistence(timeout: 5) { play.tap() }
        hold(11)

        mark("v7_add")
        addButtons.firstMatch.tap()
        hold(14)
        waitTap(app.buttons["search.done"])
        mark("v7_added")
        hold(22)
        mark("v7_added2")
        let openSurface = app.buttons["profile.openSurface"]
        var tries = 0
        while !openSurface.isHittable, tries < 6 {
            slowScroll(points: -1500)
            hold(1)
            tries += 1
        }
        hold(12)

        mark("v7_surface")
        waitTap(openSurface)
        let pop = app.buttons["surface.glyph.pop"]
        XCTAssertTrue(pop.waitForExistence(timeout: 25), "Pop glyph did not appear")
        hold(9)

        mark("v7_pop")
        pop.tap()
        hold(16)
        mark("v7_next")
        swipeToNextTrack()
        hold(15)
        mark("v7_sun")
        waitTap(app.buttons["surface.like"])
        hold(10)

        mark("v7_staffkey")
        hold(3)
        let staffKey = app.buttons["surface.staffKey"]
        XCTAssertTrue(staffKey.waitForExistence(timeout: 10))
        staffKey.press(forDuration: 1.4)
        XCTAssertTrue(app.buttons["rating.8"].waitForExistence(timeout: 15), "Observation form did not appear")
        hold(6)
        scrollTo(app.buttons["observation.skip"]).tap()
        let done = app.buttons["summary.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Session summary did not appear")
        mark("v7_summary")
        hold(13)
        scrollTo(done).tap()
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 15))
        hold(4)
        mark("end")
    }

    /// Part F · online discovery for Irene: seven real songs with their sleeves in the orb, faces as
    /// evidence, the resulting playlists on her calm surface, session saved.
    func testStoryPartF_OnlineDiscovery() throws {
        launch(autoSignIn: true, skipLaunch: true)
        let startDiscovery = app.buttons["roster.startDiscovery"]
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 60), "Roster did not appear")
        hold(3)
        openResident(named: "Irene K.")
        hold(3)
        mark("v7_disc_start")
        let begin = scrollTo(app.buttons["profile.startDiscovery"])
        hold(13)
        begin.tap()

        let reactions = ["pleasant", "pleasant", "neutral", "unpleasant", "pleasant", "neutral", "pleasant"]
        for (index, reaction) in reactions.enumerated() {
            let face = app.buttons["discovery.face.\(reaction)"]
            XCTAssertTrue(face.waitForExistence(timeout: 30), "Clip \(index + 1) did not start")
            switch index {
            case 0: mark("v7_disc_orb"); hold(15)
            case 1: mark("v7_disc_tap"); hold(10)
            case 3: mark("v7_disc_more"); hold(13)
            default: hold(7)
            }
            face.tap()
            hold(3)
        }

        let glyphs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'surface.glyph.'"))
        XCTAssertTrue(glyphs.firstMatch.waitForExistence(timeout: 40), "Calm surface did not appear")
        mark("v7_disc_result")
        hold(15)
        mark("v7_disc_play")
        glyphs.element(boundBy: 0).tap()
        hold(13)
        let staffKey = app.buttons["surface.staffKey"]
        XCTAssertTrue(staffKey.waitForExistence(timeout: 10))
        staffKey.press(forDuration: 1.4)
        XCTAssertTrue(app.buttons["rating.8"].waitForExistence(timeout: 15), "Observation form did not appear")
        hold(4)
        scrollTo(app.buttons["observation.skip"]).tap()
        let done = app.buttons["summary.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Session summary did not appear")
        mark("v7_disc_done")
        hold(8)
        scrollTo(done).tap()
        XCTAssertTrue(startDiscovery.waitForExistence(timeout: 15))
        hold(3)
        mark("end")
    }

    /// Part H · group session: the planner's suggestions from shared tastes → pick an activity → start →
    /// a playlist ranked for the whole room (sleeves, who each song is for) → next → end → check-in.
    func testStoryPartH_GroupSession() throws {
        launch(autoSignIn: true, skipLaunch: true)
        let groupMode = app.buttons["roster.groupMode"]
        XCTAssertTrue(groupMode.waitForExistence(timeout: 60), "Roster did not appear")
        hold(3)
        mark("v7_grp_open")
        hold(7)
        scrollTo(groupMode).tap()
        let start = app.buttons["planner.start"]
        if !start.waitForExistence(timeout: 6) {
            groupMode.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Planner did not appear")
        mark("v7_grp_planner")
        hold(18)
        let activities = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'planner.activity.'"))
        XCTAssertTrue(activities.firstMatch.waitForExistence(timeout: 5), "No suggested activity")
        mark("v7_grp_pick")
        activities.element(boundBy: 0).tap()
        hold(13)
        mark("v7_grp_people")
        slowScroll(points: 520)
        hold(11)
        scrollTo(start).tap()
        XCTAssertTrue(app.buttons["group.playPause"].waitForExistence(timeout: 20), "Group session did not start")
        mark("v7_grp_session")
        hold(22)
        mark("v7_grp_next")
        waitTap(app.buttons["group.next"])
        hold(13)
        mark("v7_grp_list")
        slowScroll(points: 520)
        hold(9)
        slowScroll(points: -520)
        hold(3)
        mark("v7_grp_end")
        hold(5)
        waitTap(app.buttons["group.end"])
        XCTAssertTrue(app.buttons["rating.7"].waitForExistence(timeout: 15), "Group check-in did not appear")
        mark("v7_grp_checkin")
        hold(8)
        for value in [8, 7, 8, 8] {
            app.buttons["rating.\(value)"].tap()
            hold(2.2)
        }
        hold(1)
        scrollTo(app.buttons["group.save"]).tap()
        XCTAssertTrue(groupMode.waitForExistence(timeout: 15), "Did not return to the roster")
        mark("v7_grp_saved")
        hold(7)
        mark("end")
    }

    /// Part G · the home lead's dashboard from synced data, and the new Group programme card.
    func testStoryPartG_GroupProgramme() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let email = app.textFields["signin.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "Sign-in did not appear")
        hold(3)
        typeSignIn(email: "alex@sunrise-care.co.uk")
        let home = app.buttons["homePicker.Maple Lodge"]
        XCTAssertTrue(home.waitForExistence(timeout: 45), "Home picker did not appear")
        hold(4)
        home.tap()
        XCTAssertTrue(app.buttons["chrome.back"].waitForExistence(timeout: 45), "Dashboard did not appear")
        mark("v7_admin")
        hold(12)
        mark("v7_programme")
        scrollTo(app.staticTexts["admin.groupProgramme"])
        hold(1)
        slowScroll(points: 460)      // bring the whole card into view, not just its title
        hold(16)
        mark("end")
        hold(2)
    }

    /// Part I · a new organisation: request a workspace (with a deliberate typo the form catches) →
    /// verification code → activation → the paged set-up, page by page (organisation, a home over four
    /// pages, a team over two, the sample residents, this iPad, ready) → the new home's dashboard and
    /// roster; then the invited supervisor joins with the INV- code. Run tools/demo/reset-backend.sh
    /// first: it removes the demo organisation so the same name and emails work every take. Needs a
    /// backend that exposes codes (EXPOSE_CODES / AUTO_APPROVE on the demo Worker).
    func testStoryPartI_Onboarding() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let request = app.buttons["signin.requestWorkspace"]
        XCTAssertTrue(request.waitForExistence(timeout: 30), "Sign-in (with the workspace link) did not appear")
        mark("v7_onb_open")
        hold(9)
        let org = app.textFields["onboarding.request.org"]
        tapRevealing(request, org)
        mark("v7_onb_request")
        hold(9)
        type(into: org, "Willowbank Care")
        let requesterName = app.textFields["onboarding.request.name"]
        type(into: requesterName, "Dana Reed2")    // a typo, on purpose: names cannot hold digits
        type(into: app.textFields["onboarding.request.email"], "dana@willowbank-care.co.uk")
        hold(1)
        selectSegment("onboarding.request.homes", "2–5 homes")
        hold(1)
        type(into: app.textFields["onboarding.request.cqc"], "1-123456789")
        hold(2)
        scrollTo(app.buttons["onboarding.request.submit"]).tap()
        let nameError = app.descendants(matching: .any).matching(identifier: "onboarding.request.name.error").firstMatch
        XCTAssertTrue(nameError.waitForExistence(timeout: 10), "The name error did not appear")
        mark("v7_onb_invalid")
        hold(10)
        replaceText(in: requesterName, with: "Dana Reed")
        tapAny("onboarding.request.consent")
        mark("v7_onb_send")
        hold(6)
        scrollTo(app.buttons["onboarding.request.submit"]).tap()
        let verifyField = app.textFields["onboarding.code"]
        if !verifyField.waitForExistence(timeout: 25) { snap("verify") }
        XCTAssertTrue(verifyField.exists, "Verification step did not appear")
        mark("v7_onb_verify")
        hold(9)
        // The demo Worker returns the code in the response and the hint under the field shows it.
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Demo code: '")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "Demo code hint missing — is EXPOSE_CODES on?")
        let verifyCode = String(hint.label.dropFirst("Demo code: ".count)).trimmingCharacters(in: .whitespaces)
        verifyField.tap()
        hold(0.8)
        for digit in verifyCode {
            verifyField.typeText(String(digit))
            hold(0.4)
        }
        let activate = app.buttons["onboarding.activate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 25), "Approval did not arrive — is AUTO_APPROVE on?")
        mark("v7_onb_approved")
        hold(11)
        let name = app.textFields["onboarding.codeName"]
        tapRevealing(activate, name)
        mark("v7_onb_code")
        hold(9)
        type(into: name, "Dana Reed")
        typePin("onboarding.codePin", "135790")
        typePin("onboarding.codeConfirmPin", "135790")
        hold(1)
        tapAny("onboarding.terms")
        hold(2)
        mark("v7_onb_activate")
        hold(6)
        scrollTo(app.buttons["onboarding.redeem"]).tap()

        // The wizard is one short page at a time. The primary button is the same element on every page of a section.
        let next = app.buttons["onboarding.next"]
        // Each page's header ("ORGANISATION · 4 OF 4 Defaults for every home …") is one combined element.
        func pageHeader(containing title: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        }
        if !next.waitForExistence(timeout: 60) { snap("setup") }
        XCTAssertTrue(next.exists, "Set-up did not open")
        mark("v7_onb_setup")
        hold(14)
        tapNext()

        // Organisation · address: required, and each field says what it will accept.
        let street = app.textFields["onboarding.org.address"]
        XCTAssertTrue(street.waitForExistence(timeout: 15), "Address page did not appear")
        mark("v7_onb_address")
        hold(9)
        tapNext()
        let required = app.descendants(matching: .any).matching(identifier: "onboarding.org.address.error").firstMatch
        XCTAssertTrue(required.waitForExistence(timeout: 10), "Required-field message did not appear")
        mark("v7_onb_required")
        hold(10)
        type(into: street, "14 Willow Lane")
        type(into: app.textFields["onboarding.org.town"], "Stockport")
        // Lower case and no space: the field shapes it into a postcode as it is typed.
        type(into: app.textFields["onboarding.org.postcode"], "sk11aa")
        mark("v7_onb_postcode")
        hold(10)
        tapNext()

        // Organisation · domains (Dana's own domain is already verified) and defaults.
        XCTAssertTrue(app.buttons["onboarding.domain.send"].waitForExistence(timeout: 15), "Domains page did not appear")
        mark("v7_onb_domains")
        hold(12)
        tapNext()
        XCTAssertTrue(pageHeader(containing: "Defaults for every home").waitForExistence(timeout: 15), "Defaults page did not appear")
        mark("v7_onb_defaults")
        hold(12)
        tapNext()

        // Homes: an empty list, then the four small pages of "add a home".
        let addHomeStart = app.buttons["onboarding.addHome.start"]
        XCTAssertTrue(addHomeStart.waitForExistence(timeout: 15), "Homes step did not appear")
        mark("v7_onb_home")
        hold(10)
        addHomeStart.tap()
        let homeName = app.textFields["onboarding.home.name"]
        XCTAssertTrue(homeName.waitForExistence(timeout: 15), "Home details page did not appear")
        mark("v7_onb_homeDetails")
        hold(9)
        type(into: homeName, "Willowbank Lodge")
        type(into: app.textFields["onboarding.home.capacity"], "40")
        hold(2)
        tapNext()
        let useOffice = app.buttons["onboarding.home.useOfficeAddress"]
        XCTAssertTrue(useOffice.waitForExistence(timeout: 15), "Home address page did not appear")
        mark("v7_onb_homeAddress")
        hold(10)
        closeKeyboardOnPhone(); useOffice.tap()
        hold(3)
        tapNext()
        XCTAssertTrue(pageHeader(containing: "Name its wings").waitForExistence(timeout: 15), "Wings page did not appear")
        mark("v7_onb_wings")
        hold(11)
        tapNext()
        let addHome = app.buttons["onboarding.addHome"]
        XCTAssertTrue(addHome.waitForExistence(timeout: 15), "Lead page did not appear")
        mark("v7_onb_lead")
        hold(10)
        tapBar("onboarding.addHome")
        XCTAssertTrue(app.staticTexts["Willowbank Lodge"].waitForExistence(timeout: 25), "Home did not appear")
        mark("v7_onb_homeAdded")
        hold(12)
        tapNext()

        // Team: invite one person over two pages (the first catches a mistyped address), then several.
        let inviteStart = app.buttons["onboarding.invite.start"]
        XCTAssertTrue(inviteStart.waitForExistence(timeout: 15), "Team step did not appear")
        mark("v7_onb_team")
        hold(10)
        inviteStart.tap()
        let inviteEmail = app.textFields["onboarding.invite.email"]
        XCTAssertTrue(inviteEmail.waitForExistence(timeout: 15), "Invite page did not appear")
        mark("v7_onb_inviteWho")
        hold(8)
        type(into: inviteEmail, "sam@willowbank")    // no ".co.uk": not an address yet
        type(into: app.textFields["onboarding.invite.name"], "Sam Jones")
        hold(1)
        tapNext()
        let emailError = app.descendants(matching: .any).matching(identifier: "onboarding.invite.email.error").firstMatch
        XCTAssertTrue(emailError.waitForExistence(timeout: 10), "Email error did not appear")
        mark("v7_onb_inviteInvalid")
        hold(9)
        replaceText(in: inviteEmail, with: "sam@willowbank-care.co.uk")
        tapNext()
        let send = app.buttons["onboarding.invite.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 15), "Access page did not appear")
        mark("v7_onb_inviteAccess")
        hold(12)
        tapBar("onboarding.invite.send")
        let codeTile = app.staticTexts["onboarding.invite.code"]
        XCTAssertTrue(codeTile.waitForExistence(timeout: 25), "Invite code did not appear")
        mark("v7_onb_invited")
        scrollTo(codeTile)
        hold(13)
        // "Code I N V - A B C D - E F G H" → "INV-ABCD-EFGH"
        let inviteCode = codeTile.label.replacingOccurrences(of: "Code ", with: "").replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(inviteCode.hasPrefix("INV-"), "Unexpected invite code label \(codeTile.label)")
        let several = app.buttons["onboarding.invite.startMany"]
        scrollTo(several).tap()
        let bulk = app.textFields["onboarding.invite.bulk"]
        XCTAssertTrue(bulk.waitForExistence(timeout: 15), "Bulk invite page did not appear")
        mark("v7_onb_bulk")
        hold(10)
        bulk.tap()
        hold(0.6)
        bulk.typeText("amy@willowbank-care.co.uk, Amy Shah, supervisor\nben@willowbank-care.co.uk, Ben Okafor, home lead")
        hold(2)
        let sendAll = app.buttons["onboarding.invite.sendAll"]
        XCTAssertTrue(sendAll.waitForExistence(timeout: 10), "Send all button missing")
        mark("v7_onb_bulkSend")
        hold(9)
        tapBar("onboarding.invite.sendAll")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Waiting to be accepted'")).firstMatch.waitForExistence(timeout: 25), "Team overview did not return")
        mark("v7_onb_bulkDone")
        hold(10)
        tapNext()

        // Residents: the sample spreadsheet, checked row by row, then imported.
        let sample = app.buttons["onboarding.import.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 15), "Residents step did not appear")
        mark("v7_onb_residents")
        hold(11)
        scrollTo(sample).tap()
        let apply = app.buttons["onboarding.import.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10), "Import preview did not appear")
        mark("v7_onb_preview")
        hold(13)
        closeKeyboardOnPhone(); apply.tap()
        let imported = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'added to Willowbank Lodge'")).firstMatch
        XCTAssertTrue(imported.waitForExistence(timeout: 10), "Import result missing")
        mark("v7_onb_imported")
        hold(10)
        tapNext()

        // iPads: guidance, then register this one (a label is required).
        XCTAssertTrue(pageHeader(containing: "Set up the shared iPads").waitForExistence(timeout: 15), "iPads step did not appear")
        mark("v7_onb_devices")
        hold(12)
        tapNext()
        let label = app.textFields["onboarding.device.label"]
        XCTAssertTrue(label.waitForExistence(timeout: 15), "Register page did not appear")
        mark("v7_onb_register")
        hold(8)
        let register = app.buttons["onboarding.device.register"]
        closeKeyboardOnPhone(); register.tap()
        let labelError = app.descendants(matching: .any).matching(identifier: "onboarding.device.label.error").firstMatch
        XCTAssertTrue(labelError.waitForExistence(timeout: 10), "Label-required message did not appear")
        mark("v7_onb_labelRequired")
        hold(7)
        type(into: label, "Willowbank Lodge day room")
        closeKeyboardOnPhone(); register.tap()
        XCTAssertTrue(app.buttons["Remove this iPad"].waitForExistence(timeout: 20), "iPad registration missing")
        mark("v7_onb_registered")
        hold(9)
        tapNext()

        // Ready: the checklist, then the audit trail and Finish.
        XCTAssertTrue(pageHeader(containing: "in place").waitForExistence(timeout: 15), "Checklist page did not appear")
        mark("v7_onb_ready")
        hold(13)
        tapNext()
        let done = app.buttons["onboarding.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Audit page did not appear")
        mark("v7_onb_audit")
        hold(11)
        closeKeyboardOnPhone(); done.tap()
        let openRoster = app.buttons["admin.openRoster"]
        XCTAssertTrue(openRoster.waitForExistence(timeout: 60), "Dashboard did not appear")
        mark("v7_onb_dashboard")
        hold(11)
        scrollTo(openRoster).tap()
        XCTAssertTrue(app.buttons["roster.resident.Margaret Hale"].waitForExistence(timeout: 30), "Imported residents missing from the roster")
        mark("v7_onb_roster")
        hold(12)

        // Sam joins with the invite code.
        mark("v7_onb_join")
        hold(3)
        waitTap(app.buttons["chrome.logout"])
        let haveCode = app.buttons["signin.haveCode"]
        XCTAssertTrue(haveCode.waitForExistence(timeout: 20), "Sign-in did not come back")
        hold(6)
        let codeEmail = app.textFields["onboarding.codeEmail"]
        tapRevealing(haveCode, codeEmail)
        hold(3)
        type(into: codeEmail, "sam@willowbank-care.co.uk")
        type(into: app.textFields["onboarding.codeField"], inviteCode)
        XCTAssertTrue(app.staticTexts["Willowbank Care"].waitForExistence(timeout: 15), "Invite preview did not appear")
        mark("v7_onb_preview2")
        hold(10)
        type(into: app.textFields["onboarding.codeName"], "Sam Jones")
        typePin("onboarding.codePin", "246810")
        typePin("onboarding.codeConfirmPin", "246810")
        tapAny("onboarding.terms")
        hold(2)
        mark("v7_onb_accept")
        hold(8)
        scrollTo(app.buttons["onboarding.redeem"]).tap()
        XCTAssertTrue(app.buttons["roster.startDiscovery"].waitForExistence(timeout: 60), "Sam's roster did not appear")
        mark("v7_onb_samRoster")
        hold(12)
        mark("end")
        hold(2)
    }

    /// Smoke check for the tail of Part I without the 10-minute lead-in: an existing org admin signs in,
    /// opens the roster, logs out and opens "I have an invite or activation code". Needs the Willowbank
    /// organisation to exist (run Part I first; the reset removes it).
    func testOnboardingJoinSmoke() throws {
        app.launchArguments = ["-NoteStalgiaDemoAudioLog", "YES", "-NoteStalgiaDemoSkipLaunch", "YES",
                               "-NoteStalgiaDemoSignIn", "dana@willowbank-care.co.uk", "-NoteStalgiaDemoSignInPIN", "135790"]
        if let base = ProcessInfo.processInfo.environment["API_BASE_URL"], !base.isEmpty {
            app.launchArguments += ["-NoteStalgiaAPIBaseURL", base]
        }
        app.launch()
        let openRoster = app.buttons["admin.openRoster"]
        XCTAssertTrue(openRoster.waitForExistence(timeout: 60), "Dashboard did not appear")
        hold(3)
        scrollTo(openRoster).tap()
        XCTAssertTrue(app.buttons["roster.startDiscovery"].waitForExistence(timeout: 30), "Roster did not appear")
        hold(6)
        waitTap(app.buttons["chrome.logout"])
        let haveCode = app.buttons["signin.haveCode"]
        XCTAssertTrue(haveCode.waitForExistence(timeout: 20), "Sign-in did not come back")
        hold(5)
        let codeEmail = app.textFields["onboarding.codeEmail"]
        tapRevealing(haveCode, codeEmail)
        hold(2)
    }

    // MARK: - Mobile takes · the onboarding and admin screens on the phone (tools/demo/pipeline/build_v7_mobile.py)
    //
    // Run on the iPhone simulator, in this order, against the live Worker, after tools/demo/reset-backend.sh:
    //   testMobileA_Request → testMobileB_SetupOrganisationHomesTeam → testMobileC_SetupResidentsIpadsReady →
    //   testMobileD_ColleagueJoins → testMobileE_HomeAdminDashboard → testMobileF_ManageTheTeam
    // Each take starts from what the one before left on the server; B writes Sam's invite code to
    // /tmp/notestalgia-mobile-invite.txt for D. The admin and set-up screens are phone-first, so these are
    // the primary recordings of them (the iPad takes in Part I show the same pages on the wide layout).

    private let mobileInviteFile = "/tmp/notestalgia-mobile-invite.txt"

    /// The pinned bar's primary button; on a phone the keyboard hides the bar, so put the keyboard away first.
    private func tapNext(file: StaticString = #filePath, line: UInt = #line) {
        closeKeyboardOnPhone()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15), "Next button missing", file: file, line: line)
        next.tap()
    }

    private func tapBar(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        closeKeyboardOnPhone()
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Missing \(identifier)", file: file, line: line)
        button.tap()
    }

    private func pageHeader(containing title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    /// A card header is one combined element ("Waiting to be accepted, 3 pending · …"), so match its start.
    private func headerText(startingWith title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// Brings an element into view with the slow drag the recordings use (`slowScroll`), a few points at a time.
    /// `scrollTo` swipes fast from the middle of the screen, which some long pages ignore.
    @discardableResult
    private func scrollSlowlyTo(_ element: XCUIElement, step: CGFloat = 260, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "Missing \(element)", file: file, line: line)
        var attempts = 0
        while !element.isHittable, attempts < 8 {
            slowScroll(points: step)
            attempts += 1
        }
        return element
    }

    /// Debug aid: a PNG of the screen at /tmp/ns-snap-<name>.png (host path), for finding out why a step failed.
    private func snap(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/ns-snap-\(name).png"))
    }

    private func fieldError(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "\(identifier).error").firstMatch
    }

    private func launchAs(_ email: String, pin: String) {
        var arguments = ["-NoteStalgiaDemoAudioLog", "YES", "-NoteStalgiaDemoSkipLaunch", "YES",
                         "-NoteStalgiaDemoSignIn", email, "-NoteStalgiaDemoSignInPIN", pin]
        if let base = ProcessInfo.processInfo.environment["API_BASE_URL"], !base.isEmpty {
            arguments += ["-NoteStalgiaAPIBaseURL", base]
        }
        app.launchArguments = arguments
        try? FileManager.default.removeItem(atPath: markersPath)
        app.launch()
    }

    /// Take A · from the sign-in screen to the first page of set-up: the request (with a typo the form
    /// catches), the six-digit code, approval, and activation with a chosen PIN.
    func testMobileA_Request() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let request = app.buttons["signin.requestWorkspace"]
        XCTAssertTrue(request.waitForExistence(timeout: 30), "Sign-in (with the workspace link) did not appear")
        mark("m_open")
        hold(10)
        let org = app.textFields["onboarding.request.org"]
        scrollTo(request).tap()
        if !org.waitForExistence(timeout: 6) { request.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        XCTAssertTrue(org.waitForExistence(timeout: 15), "Request form did not appear")
        mark("m_request")
        hold(10)
        type(into: org, "Willowbank Care")
        let requesterName = app.textFields["onboarding.request.name"]
        type(into: requesterName, "Dana Reed2")    // a typo, on purpose
        type(into: app.textFields["onboarding.request.email"], "dana@willowbank-care.co.uk")
        mark("m_request_more")
        hold(4)
        slowScroll(points: 520)
        hold(6)
        selectSegment("onboarding.request.homes", "2–5 homes")
        hold(1)
        type(into: app.textFields["onboarding.request.cqc"], "1-123456789")
        hold(2)
        scrollTo(app.buttons["onboarding.request.submit"]).tap()
        XCTAssertTrue(fieldError("onboarding.request.name").waitForExistence(timeout: 10), "The name error did not appear")
        mark("m_invalid")
        hold(11)
        replaceText(in: requesterName, with: "Dana Reed")
        tapAny("onboarding.request.consent")
        mark("m_send")
        hold(7)
        scrollTo(app.buttons["onboarding.request.submit"]).tap()

        let verifyField = app.textFields["onboarding.code"]
        XCTAssertTrue(verifyField.waitForExistence(timeout: 25), "Verification step did not appear")
        mark("m_verify")
        hold(10)
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Demo code: '")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "Demo code hint missing — is EXPOSE_CODES on?")
        let verifyCode = String(hint.label.dropFirst("Demo code: ".count)).trimmingCharacters(in: .whitespaces)
        verifyField.tap()
        hold(0.8)
        for digit in verifyCode {
            verifyField.typeText(String(digit))
            hold(0.4)
        }
        let activate = app.buttons["onboarding.activate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 25), "Approval did not arrive — is AUTO_APPROVE on?")
        mark("m_approved")
        hold(11)
        let name = app.textFields["onboarding.codeName"]
        scrollTo(activate).tap()
        if !name.waitForExistence(timeout: 6) { activate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Activation screen did not appear")
        mark("m_code")
        hold(10)
        type(into: name, "Dana Reed")
        typePin("onboarding.codePin", "135790")
        typePin("onboarding.codeConfirmPin", "135790")
        hold(1)
        tapAny("onboarding.terms")
        mark("m_activate")
        hold(9)
        scrollTo(app.buttons["onboarding.redeem"]).tap()
        XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 60), "Set-up did not open")
        mark("m_setup_open")
        hold(12)
        mark("end")
        hold(2)
    }

    /// Take B · organisation (details, address, domains, defaults) → homes (add one over four pages, export)
    /// → team (invite one, invite several, manage the pending list). Signed in as Dana, who has no home yet.
    func testMobileB_SetupOrganisationHomesTeam() throws {
        launchAs("dana@willowbank-care.co.uk", pin: "135790")
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 60), "Set-up did not open")
        mark("m_org_details")
        hold(14)
        tapNext()

        // Address: required, and shaped as it is typed.
        let street = app.textFields["onboarding.org.address"]
        XCTAssertTrue(street.waitForExistence(timeout: 15), "Address page did not appear")
        mark("m_org_address")
        hold(9)
        tapNext()
        XCTAssertTrue(fieldError("onboarding.org.address").waitForExistence(timeout: 10), "Required-field message did not appear")
        mark("m_org_required")
        hold(10)
        type(into: street, "14 Willow Lane")
        type(into: app.textFields["onboarding.org.town"], "Stockport")
        typeSlowly(into: app.textFields["onboarding.org.postcode"], "sk11aa")
        mark("m_org_postcode")
        hold(10)
        tapNext()

        // Domains: a mistyped domain, then the DNS route (the TXT record to publish).
        let domainField = app.textFields["onboarding.domain.new"]
        XCTAssertTrue(domainField.waitForExistence(timeout: 15), "Domains page did not appear")
        mark("m_domains")
        hold(12)
        selectSegment("onboarding.domain.method", "DNS record")
        hold(2)
        type(into: domainField, "willowbank")
        tapBar("onboarding.domain.send")
        XCTAssertTrue(fieldError("onboarding.domain.new").waitForExistence(timeout: 10), "Domain error did not appear")
        mark("m_domain_invalid")
        hold(9)
        replaceText(in: domainField, with: "willowbank-homes.co.uk")
        tapBar("onboarding.domain.send")
        XCTAssertTrue(app.buttons["onboarding.domain.checkDns"].waitForExistence(timeout: 20), "DNS record did not appear")
        mark("m_dns")
        scrollTo(app.buttons["onboarding.domain.checkDns"])
        hold(14)
        tapNext()

        // Defaults.
        XCTAssertTrue(pageHeader(containing: "Defaults for every home").waitForExistence(timeout: 15), "Defaults page did not appear")
        mark("m_defaults")
        hold(11)
        app.buttons["5 min"].firstMatch.tap()
        hold(2)
        tapNext()
        mark("m_defaults_saved")
        hold(8)

        // Homes.
        let addHomeStart = app.buttons["onboarding.addHome.start"]
        XCTAssertTrue(addHomeStart.waitForExistence(timeout: 20), "Homes step did not appear")
        mark("m_homes")
        hold(10)
        addHomeStart.tap()
        let homeName = app.textFields["onboarding.home.name"]
        XCTAssertTrue(homeName.waitForExistence(timeout: 15), "Home details page did not appear")
        mark("m_home_details")
        hold(9)
        type(into: homeName, "Willowbank Lodge")
        typeSlowly(into: app.textFields["onboarding.home.capacity"], "4x0", interval: 1.4, closeKeyboardFirst: true)   // the field keeps only digits
        mark("m_home_beds")
        hold(8)
        tapNext()
        let useOffice = app.buttons["onboarding.home.useOfficeAddress"]
        XCTAssertTrue(useOffice.waitForExistence(timeout: 15), "Home address page did not appear")
        mark("m_home_address")
        hold(10)
        useOffice.tap()
        hold(3)
        tapNext()
        XCTAssertTrue(pageHeader(containing: "Name its wings").waitForExistence(timeout: 15), "Wings page did not appear")
        mark("m_home_wings")
        hold(11)
        type(into: app.textFields["onboarding.home.newWing"], "Garden suite")
        tapBar("onboarding.home.addWing")
        hold(3)
        let dayProgramme = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Day programme'")).firstMatch
        if dayProgramme.waitForExistence(timeout: 5) { dayProgramme.tap() }
        mark("m_home_wings_edit")
        hold(8)
        tapNext()
        let addHome = app.buttons["onboarding.addHome"]
        XCTAssertTrue(addHome.waitForExistence(timeout: 15), "Lead page did not appear")
        mark("m_home_lead")
        hold(10)
        selectSegment("onboarding.home.lead", "Invite someone")
        hold(5)
        selectSegment("onboarding.home.lead", "That’s me")
        hold(2)
        addHome.tap()
        XCTAssertTrue(app.staticTexts["Willowbank Lodge"].waitForExistence(timeout: 25), "Home did not appear")
        mark("m_home_added")
        hold(12)
        slowScroll(points: 380)
        hold(3)
        let exportResidents = app.buttons["onboarding.export.residents.Willowbank Lodge"]
        if exportResidents.waitForExistence(timeout: 5) {
            scrollTo(exportResidents).tap()
            XCTAssertTrue(app.buttons["onboarding.export.share"].waitForExistence(timeout: 25), "Export did not finish")
            mark("m_export")
            hold(10)
            app.buttons["Done"].firstMatch.tap()
            hold(1)
        }
        slowScroll(points: -380)
        tapNext()

        // Team: one invite over two pages (the first catches a mistyped address), then several at once.
        let inviteStart = app.buttons["onboarding.invite.start"]
        XCTAssertTrue(inviteStart.waitForExistence(timeout: 15), "Team step did not appear")
        mark("m_team")
        hold(10)
        inviteStart.tap()
        let inviteEmail = app.textFields["onboarding.invite.email"]
        XCTAssertTrue(inviteEmail.waitForExistence(timeout: 15), "Invite page did not appear")
        mark("m_invite_who")
        hold(8)
        type(into: inviteEmail, "sam@willowbank")
        type(into: app.textFields["onboarding.invite.name"], "Sam Jones")
        tapNext()
        XCTAssertTrue(fieldError("onboarding.invite.email").waitForExistence(timeout: 10), "Email error did not appear")
        mark("m_invite_invalid")
        hold(9)
        replaceText(in: inviteEmail, with: "sam@willowbank-care.co.uk")
        tapNext()
        let send = app.buttons["onboarding.invite.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 15), "Access page did not appear")
        mark("m_invite_access")
        hold(12)
        tapAny("onboarding.invite.temporary")
        mark("m_invite_cover")
        hold(9)
        tapAny("onboarding.invite.temporary")
        hold(2)
        send.tap()
        let codeTile = app.staticTexts["onboarding.invite.code"]
        XCTAssertTrue(codeTile.waitForExistence(timeout: 25), "Invite code did not appear")
        let inviteCode = codeTile.label.replacingOccurrences(of: "Code ", with: "").replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(inviteCode.hasPrefix("INV-"), "Unexpected invite code label \(codeTile.label)")
        try? inviteCode.write(toFile: mobileInviteFile, atomically: true, encoding: .utf8)
        mark("m_invited")
        scrollTo(codeTile)
        hold(13)

        let several = app.buttons["onboarding.invite.startMany"]
        scrollTo(several).tap()
        let bulk = app.textFields["onboarding.invite.bulk"]
        XCTAssertTrue(bulk.waitForExistence(timeout: 15), "Bulk invite page did not appear")
        mark("m_bulk")
        hold(10)
        bulk.tap()
        hold(0.6)
        bulk.typeText("amy@willowbank-care.co.uk, Amy Shah, supervisor\nben@willowbank-care.co.uk, Ben Okafor, home lead\ncarol@willowbank")
        hold(2)
        mark("m_bulk_send")
        hold(8)
        tapBar("onboarding.invite.sendAll")
        let bulkError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'carol@willowbank'")).firstMatch
        XCTAssertTrue(bulkError.waitForExistence(timeout: 25), "The partial-send error did not appear")
        mark("m_bulk_partial")
        hold(12)
        replaceText(in: bulk, with: "carol@willowbank-care.co.uk, Carol Mills, supervisor")
        tapBar("onboarding.invite.sendAll")
        if !headerText(startingWith: "Waiting to be accepted").waitForExistence(timeout: 25) { snap("bulk2") }
        XCTAssertTrue(headerText(startingWith: "Waiting to be accepted").exists, "Team overview did not return")
        mark("m_team_pending")
        hold(10)
        slowScroll(points: 420)
        hold(2)
        let resend = app.buttons["onboarding.invite.resend.carol@willowbank-care.co.uk"]
        if resend.waitForExistence(timeout: 5) {
            scrollSlowlyTo(resend).tap()
            mark("m_team_resend")
            hold(9)
        }
        let revoke = app.buttons["onboarding.invite.revoke.carol@willowbank-care.co.uk"]
        if revoke.waitForExistence(timeout: 5) {
            scrollSlowlyTo(revoke).tap()
            mark("m_team_revoke")
            hold(9)
        }
        mark("end")
        hold(2)
    }

    /// Take C · back in from the dashboard's set-up card (it resumes at the first page still to do) →
    /// residents (template, sample spreadsheet, review, import) → iPads (guidance, register with a label)
    /// → ready (checklist, audit trail) → Finish → the new home's dashboard.
    func testMobileC_SetupResidentsIpadsReady() throws {
        launchAs("dana@willowbank-care.co.uk", pin: "135790")
        let openRoster = app.buttons["admin.openRoster"]
        XCTAssertTrue(openRoster.waitForExistence(timeout: 60), "Dashboard did not appear")
        mark("m_resume")
        hold(10)
        let card = app.buttons["admin.orgSetup"]
        scrollTo(card)
        mark("m_resume_card")
        hold(10)
        card.tap()

        let sample = app.buttons["onboarding.import.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 30), "Residents page did not appear")
        mark("m_residents")
        hold(11)
        let template = app.buttons["onboarding.import.template"]
        scrollTo(template).tap()
        mark("m_template")
        hold(9)
        scrollTo(sample).tap()
        let apply = app.buttons["onboarding.import.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10), "Import preview did not appear")
        mark("m_preview")
        hold(13)
        apply.tap()
        let imported = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'added to Willowbank Lodge'")).firstMatch
        XCTAssertTrue(imported.waitForExistence(timeout: 10), "Import result missing")
        mark("m_imported")
        hold(10)
        tapNext()

        XCTAssertTrue(pageHeader(containing: "Set up the shared iPads").waitForExistence(timeout: 15), "iPads step did not appear")
        mark("m_ipads")
        hold(12)
        tapNext()
        let label = app.textFields["onboarding.device.label"]
        XCTAssertTrue(label.waitForExistence(timeout: 15), "Register page did not appear")
        mark("m_register")
        hold(8)
        let register = app.buttons["onboarding.device.register"]
        scrollTo(register).tap()
        XCTAssertTrue(fieldError("onboarding.device.label").waitForExistence(timeout: 10), "Label-required message did not appear")
        mark("m_label_required")
        hold(8)
        type(into: label, "Willowbank Lodge day room")
        closeKeyboardOnPhone()
        scrollTo(register).tap()
        XCTAssertTrue(app.buttons["Remove this iPad"].waitForExistence(timeout: 20), "iPad registration missing")
        mark("m_registered")
        hold(10)
        tapNext()

        XCTAssertTrue(pageHeader(containing: "in place").waitForExistence(timeout: 15), "Checklist page did not appear")
        mark("m_ready")
        hold(13)
        slowScroll(points: 380)
        hold(4)
        slowScroll(points: -380)
        tapNext()
        let done = app.buttons["onboarding.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Audit page did not appear")
        mark("m_audit")
        hold(12)
        done.tap()
        XCTAssertTrue(openRoster.waitForExistence(timeout: 60), "Dashboard did not appear after finishing")
        mark("m_finished")
        hold(11)
        slowScroll(points: 420)
        hold(5)
        mark("end")
        hold(2)
    }

    /// Take D · Sam, invited in take B, joins from the sign-in screen with the INV- code.
    func testMobileD_ColleagueJoins() throws {
        let inviteCode = ((try? String(contentsOfFile: mobileInviteFile, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(inviteCode.hasPrefix("INV-"), "Run take B first: no invite code in \(mobileInviteFile)")
        launch(autoSignIn: false, skipLaunch: true)
        let haveCode = app.buttons["signin.haveCode"]
        XCTAssertTrue(haveCode.waitForExistence(timeout: 30), "Sign-in did not appear")
        mark("m_join")
        hold(10)
        let codeEmail = app.textFields["onboarding.codeEmail"]
        scrollTo(haveCode).tap()
        if !codeEmail.waitForExistence(timeout: 6) { haveCode.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        XCTAssertTrue(codeEmail.waitForExistence(timeout: 15), "Code screen did not appear")
        hold(3)
        type(into: codeEmail, "sam@willowbank-care.co.uk")
        type(into: app.textFields["onboarding.codeField"], inviteCode)
        XCTAssertTrue(app.staticTexts["Willowbank Care"].waitForExistence(timeout: 15), "Invite preview did not appear")
        mark("m_join_preview")
        hold(12)
        slowScroll(points: 460)
        mark("m_join_pin")
        hold(7)
        typePin("onboarding.codePin", "246810")
        typePin("onboarding.codeConfirmPin", "246810")
        tapAny("onboarding.terms")
        hold(2)
        mark("m_join_accept")
        hold(8)
        scrollTo(app.buttons["onboarding.redeem"]).tap()
        XCTAssertTrue(app.buttons["roster.startDiscovery"].waitForExistence(timeout: 60), "Sam's roster did not appear")
        mark("m_join_roster")
        hold(13)
        mark("end")
        hold(2)
    }

    /// Take E · the home lead's dashboard on the phone, section by section (seeded Maple Lodge data).
    func testMobileE_HomeAdminDashboard() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let email = app.textFields["signin.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "Sign-in did not appear")
        mark("m_admin_signin")
        hold(8)
        typeSignIn(email: "alex@sunrise-care.co.uk")
        let home = app.buttons["homePicker.Maple Lodge"]
        XCTAssertTrue(home.waitForExistence(timeout: 45), "Home picker did not appear")
        mark("m_admin_picker")
        hold(11)
        home.tap()
        XCTAssertTrue(app.buttons["chrome.back"].waitForExistence(timeout: 45), "Dashboard did not appear")
        mark("m_admin_dash")
        hold(12)
        let trends = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'admin.trend.'"))
        if trends.count > 0 {
            trends.element(boundBy: 0).tap()
            mark("m_admin_trend")
            hold(10)
            trends.element(boundBy: 0).tap()
            hold(2)
        }
        slowScroll(points: 560)
        mark("m_admin_tiles")
        hold(11)
        slowScroll(points: 520)
        mark("m_admin_wings")
        hold(12)
        scrollTo(app.staticTexts["admin.groupProgramme"])
        slowScroll(points: 300)
        mark("m_admin_group")
        hold(13)
        slowScroll(points: 700)
        mark("m_admin_improving")
        hold(11)
        slowScroll(points: 900)
        mark("m_admin_recent")
        hold(11)
        mark("end")
        hold(2)
    }

    /// Take F · the organisation admin manages the team: pending invites, then the staff list with its
    /// account actions (Suspend, Restore, Reset PIN). Dana, after Sam has joined.
    func testMobileF_ManageTheTeam() throws {
        launch(autoSignIn: false, skipLaunch: true)
        let email = app.textFields["signin.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "Sign-in did not appear")
        hold(2)
        // Dana's own PIN, typed on camera.
        email.tap()
        hold(0.8)
        email.typeText("dana@willowbank-care.co.uk")
        hold(1.5)
        let pin = app.textFields["signin.pin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "PIN field missing")
        pin.tap()
        hold(0.8)
        for digit in ["1", "3", "5", "7", "9", "0"] {
            pin.typeText(digit)
            hold(0.4)
        }
        let card = app.buttons["admin.orgSetup"]
        XCTAssertTrue(app.buttons["admin.openRoster"].waitForExistence(timeout: 60), "Dashboard did not appear")
        mark("m_manage_dash")
        hold(10)
        scrollTo(card)
        hold(2)
        card.tap()
        let section = app.buttons["onboarding.section.3"]
        XCTAssertTrue(section.waitForExistence(timeout: 30), "Set-up did not open")
        mark("m_manage_open")
        hold(11)
        section.tap()
        XCTAssertTrue(app.buttons["onboarding.staff.toggle"].waitForExistence(timeout: 20), "Team page did not appear")
        mark("m_manage_team")
        hold(11)
        // The Staff card starts under the pinned bar (XCUITest still calls it hittable), so scroll first.
        slowScroll(points: 560)
        hold(1)
        let toggle = app.buttons["onboarding.staff.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Staff toggle missing")
        toggle.tap()
        let suspend = app.buttons["Suspend"].firstMatch
        if !suspend.waitForExistence(timeout: 15) { snap("staff") }
        XCTAssertTrue(suspend.exists, "Staff list did not open")
        slowScroll(points: 360)
        mark("m_manage_staff")
        hold(13)
        suspend.tap()
        let restore = app.buttons["Restore"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 15), "Account was not suspended")
        mark("m_manage_suspended")
        hold(11)
        restore.tap()
        XCTAssertTrue(app.buttons["Suspend"].firstMatch.waitForExistence(timeout: 15), "Account was not restored")
        mark("m_manage_restored")
        hold(8)
        let reset = app.buttons["Reset PIN"].firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 10), "Reset PIN missing")
        reset.tap()
        mark("m_manage_reset")
        hold(12)
        mark("end")
        hold(2)
    }

    // MARK: - Helpers

    /// Scrolls to a field, focuses it and types; pauses so the recording shows the text arriving.
    private func type(into field: XCUIElement, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Missing \(field)", file: file, line: line)
        _ = scrollTo(field, assert: false)
        field.tap()
        hold(0.6)
        field.typeText(text)
        hold(0.8)
    }

    /// One character at a time, so a field that drops or reshapes a character is seen doing it (and is given
    /// the moment it needs between key presses, as under a real finger).
    private func typeSlowly(into field: XCUIElement, _ text: String, interval: Double = 0.6, closeKeyboardFirst: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Missing \(field)", file: file, line: line)
        _ = scrollTo(field, assert: false)
        // A number pad field does not take focus from a field whose (letter) keyboard is still up when the tap
        // comes from XCUITest, so put the keyboard away first, as a person would with "Done".
        if closeKeyboardFirst { closeKeyboardOnPhone() }
        field.tap()
        hold(0.6)
        for character in text {
            field.typeText(String(character))
            hold(interval)
        }
        hold(0.6)
    }

    /// Clears a field and types again, so a mistake the form just flagged can be corrected on camera.
    private func replaceText(in field: XCUIElement, with text: String) {
        _ = scrollTo(field, assert: false)
        field.tap()
        hold(0.6)
        func isEmpty() -> Bool {
            let value = (field.value as? String) ?? ""
            return value.isEmpty || value == field.placeholderValue
        }
        // Select everything and delete; if that did nothing (a field that ignores Cmd-A), walk to the end of the
        // text and delete backwards, which also copes with a caret left at the start of a multi-line field.
        if !isEmpty() {
            field.typeKey("a", modifierFlags: .command)
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        for _ in 0 ..< 3 where !isEmpty() {
            let length = max(((field.value as? String) ?? "").count, 1)
            field.typeText(String(repeating: XCUIKeyboardKey.rightArrow.rawValue, count: length))
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: length))
        }
        field.typeText(text)
        hold(0.8)
    }

    /// Six digits one by one into a `SixDigitPinInput` (its sixth digit moves focus on).
    private func typePin(_ identifier: String, _ digits: String, file: StaticString = #filePath, line: UInt = #line) {
        let pin = app.textFields[identifier]
        XCTAssertTrue(pin.waitForExistence(timeout: 10), "Missing \(identifier)", file: file, line: line)
        // The first PIN hands focus to the confirmation by itself after its sixth digit. Tapping the field again
        // re-presents the iPad's number-pad popover, and XCUITest then types '2' six times, so only tap when needed.
        let hasFocus = (pin.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
        if !hasFocus {
            _ = scrollTo(pin, assert: false)
            pin.tap()
        }
        hold(0.6)
        for digit in digits {
            pin.typeText(String(digit))
            hold(0.35)
        }
        hold(0.6)
    }

    /// Taps a button and waits for the screen it opens; a tap that lands during a phase fade is swallowed by
    /// the flow's hit-testing gate, so one retry at the button's centre covers it.
    private func tapRevealing(_ button: XCUIElement, _ reveals: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        closeKeyboardOnPhone()
        XCTAssertTrue(button.waitForExistence(timeout: 20), "Missing \(button)", file: file, line: line)
        button.tap()
        if !reveals.waitForExistence(timeout: 6) {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(reveals.waitForExistence(timeout: timeout), "\(reveals) did not appear after tapping \(button)", file: file, line: line)
    }

    /// Taps an element by identifier whatever XCUITest classifies it as (toggle rows are buttons with a toggle trait).
    private func tapAny(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        closeKeyboardOnPhone()
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(identifier)", file: file, line: line)
        _ = scrollTo(element, assert: false)
        element.tap()
    }

    private func launch(autoSignIn: Bool, skipLaunch: Bool, resetHouseholds: Bool = false) {
        var arguments = ["-NoteStalgiaDemoAudioLog", "YES", "-NoteStalgiaDemoAutoPhoto", "YES"]
        if autoSignIn { arguments += ["-NoteStalgiaDemoSignIn", "max@sunrise-care.co.uk"] }
        if skipLaunch { arguments += ["-NoteStalgiaDemoSkipLaunch", "YES"] }
        if resetHouseholds { arguments += ["-NoteStalgiaDemoResetHouseholds", "YES"] }
        // TEST_RUNNER_API_BASE_URL=http://localhost:8787 runs the walkthrough against a local Worker.
        if let base = ProcessInfo.processInfo.environment["API_BASE_URL"], !base.isEmpty {
            arguments += ["-NoteStalgiaAPIBaseURL", base]
        }
        app.launchArguments = arguments
        try? FileManager.default.removeItem(atPath: markersPath)
        app.launch()
    }

    /// Timestamped step marker for the assembly script (host clock, same as the app's demo log).
    private func mark(_ label: String) {
        if !narrationSeconds.isEmpty {
            // Never start a step while the last one is still being described.
            let wait = narrationEndsAt.timeIntervalSinceNow + voiceGap
            if wait > 0 {
                autopaceLog("\(label): waited \(String(format: "%.1f", wait)) s for the previous line")
                Thread.sleep(forTimeInterval: wait)
            }
        }
        let line = "\(Date().timeIntervalSince1970)|\(label)\n"
        if let handle = FileHandle(forWritingAtPath: markersPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: markersPath, contents: line.data(using: .utf8))
        }
        if let secs = narrationSeconds[label] {
            narrationEndsAt = Date().addingTimeInterval(voiceDelay + secs)
        }
        auditCapture(label)
    }

    /// Pauses. A hold of four seconds or more is a "dwell": when a line is still being spoken it lasts
    /// until that line ends plus a beat, whatever number was written here.
    private func hold(_ seconds: Double) {
        if !narrationSeconds.isEmpty, seconds >= 4 {
            let remaining = narrationEndsAt.timeIntervalSinceNow
            if remaining > 0 {
                Thread.sleep(forTimeInterval: remaining + 1.0 * max(pace, 1))
                return
            }
        }
        Thread.sleep(forTimeInterval: seconds * pace)
    }

    private func autopaceLog(_ text: String) {
        let path = (markersPath as NSString).deletingPathExtension + ".autopace.log"
        let line = text + "\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile(); handle.write(line.data(using: .utf8)!); handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
        }
    }

    /// Puts the on-screen keyboard away before a button is tapped. On a phone it hides the pinned bar and the
    /// keyboard's "Done" brings it back; on an iPad the docked keyboard covers the lower half of the form, so its
    /// "Hide keyboard" key is used. A no-op when no keyboard is up.
    /// Taps the page title to put the keyboard away. When the page has scrolled the title out of reach (the keyboard
    /// pushes it up under the top bar), a neutral spot near the top does the same.
    private func tapPageTitleToDismissKeyboard(_ title: String) {
        let page = app.staticTexts[title].firstMatch
        if page.exists, page.isHittable {
            page.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10)).tap()
        }
    }

    private func closeKeyboardOnPhone() {
        let done = app.buttons["onboarding.keyboardDone"]
        if done.exists, done.isHittable {
            done.tap()
            hold(0.8)
            return
        }
        let hide = app.keyboards.buttons["Hide keyboard"].firstMatch
        if hide.exists, hide.isHittable {
            hide.tap()
            hold(0.8)
            return
        }
        // The iPad's number pad is a popover, not a docked keyboard: it has no hide key, and the next tap would
        // only dismiss it, so tap a neutral spot (the page title) to put it away first.
        if app.keyboards.count > 0 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10)).tap()
            hold(0.8)
        }
    }

    /// Types the email and the six PIN digits one by one; the PIN submits itself on the sixth.
    private func typeSignIn(email address: String) {
        let email = app.textFields["signin.email"]
        email.tap()
        hold(0.8)
        email.typeText(address)
        hold(1.5)
        let pin = app.textFields["signin.pin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "PIN field missing")
        pin.tap()
        hold(0.8)
        for digit in ["1", "2", "3", "4", "5", "6"] {
            pin.typeText(digit)
            hold(0.4)
        }
    }

    /// Next song on the calm surface. `app.swipeLeft()` starts at the screen centre, which is the
    /// playing glyph — a button above the surface's swipe gesture — so drag across empty space
    /// below the hub instead (the comfort dock sits lower still).
    private func swipeToNextTrack() {
        let frame = app.windows.firstMatch.frame
        let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.width * 0.80, dy: frame.height * 0.70))
        let to = from.withOffset(CGVector(dx: -frame.width * 0.55, dy: 0))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .fast, thenHoldForDuration: 0.05)
    }

    private func dismissKeyboard() {
        let returnKey = app.keyboards.buttons["Return"].firstMatch
        if returnKey.exists { returnKey.tap(); hold(0.8) }
    }

    /// Slow, visible scroll (positive = read further down the page).
    private func slowScroll(points: CGFloat) {
        let frame = app.windows.firstMatch.frame
        let startY = points > 0 ? frame.height * 0.80 : frame.height * 0.28
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: startY))
        let end = start.withOffset(CGVector(dx: 0, dy: -points))
        start.press(forDuration: 0.08, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.25)
    }

    @discardableResult
    private func waitTap(_ element: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        closeKeyboardOnPhone()
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(element)", file: file, line: line)
        element.tap()
        return element
    }

    private func tapIfPresent(_ element: XCUIElement) {
        if scrollTo(element, assert: false) { element.tap() }
    }

    /// Taps a roster card and makes sure the profile actually opened — a tap that lands while the
    /// list is still settling is retried once at the card's centre.
    private func openResident(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let card = scrollTo(app.buttons["roster.resident.\(name)"], file: file, line: line)
        let openSurface = app.buttons["profile.openSurface"]
        card.tap()
        if !openSurface.waitForExistence(timeout: 6) {
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(openSurface.waitForExistence(timeout: 10), "Profile for \(name) did not open", file: file, line: line)
    }

    /// Swipes until the element can be hit (XCUITest never scrolls for you). Returns whether it is hittable.
    @discardableResult
    private func scrollTo(_ element: XCUIElement, assert: Bool, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        if !element.waitForExistence(timeout: assert ? 15 : 3) {
            if assert { XCTFail("Missing \(element)", file: file, line: line) }
            return false
        }
        var attempts = 0
        while !element.isHittable, attempts < 6 {
            app.swipeUp()
            hold(0.6)
            attempts += 1
        }
        return element.isHittable
    }

    @discardableResult
    private func scrollTo(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        _ = scrollTo(element, assert: true, file: file, line: line)
        return element
    }

    /// Taps one segment of a picker. The pickers are rows of 44 pt buttons inside a group that carries the identifier;
    /// a system segmented control is still found if one is ever used.
    private func selectSegment(_ identifier: String, _ title: String) {
        let group = app.otherElements[identifier]
        if group.waitForExistence(timeout: 2), group.buttons[title].exists {
            group.buttons[title].tap()
            return
        }
        let segmented = app.segmentedControls[identifier]
        if segmented.exists {
            segmented.buttons[title].tap()
        } else {
            app.buttons[title].firstMatch.tap()
        }
    }

    // MARK: - Screen audit (opt-in)

    /// Saves `<n>-<label>.jpg` and `<n>-<label>.controls.json` for the current screen: every control with its
    /// label, identifier and frame, so touch targets, missing labels and duplicate labels can be checked per screen.
    /// With `DEMO_AUDIT_SCROLL=1` it also scrolls the page down in steps and saves each stop (`…-s1.jpg`) until the
    /// text and controls stop moving, then scrolls back up.
    private func auditCapture(_ label: String) {
        guard let dir = auditDir else { return }
        Thread.sleep(forTimeInterval: 1.0)
        auditCount += 1
        let test = name.split(separator: " ").last.map { String($0).replacingOccurrences(of: "]", with: "") } ?? "test"
        let base = "\(dir)/\(test)-\(String(format: "%03d", auditCount))-\(label)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var page = auditRows()
        auditSave(base, rows: page.rows)
        // Never swipe a sheet (the song search): the swipe drags it and the next step loses it. Nor with the keyboard up.
        guard auditScroll, app.scrollViews.firstMatch.exists, !app.keyboards.firstMatch.exists,
              !app.buttons["Done"].exists, !app.textFields["search.query"].exists else { return }
        var swipes = 0
        for step in 1...8 {
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.9)
            // Wait until the page has stopped moving (two inventories in a row agree), so the screenshot and the control
            // frames describe the same picture.
            var next = auditRows()
            for _ in 0..<4 {
                Thread.sleep(forTimeInterval: 0.3)
                let again = auditRows()
                if again.signature == next.signature { next = again; break }
                next = again
            }
            if next.signature == page.signature { break }   // nothing moved: the end of the page
            page = next
            swipes += 1
            auditSave("\(base)-s\(step)", rows: next.rows)
        }
        if swipes > 0 {
            for _ in 0 ... swipes { app.swipeDown(velocity: .fast) }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Controls (type, label, identifier, frame) and a signature of where text and controls sit.
    private func auditRows() -> (rows: [[String: Any]], signature: String) {
        var rows: [[String: Any]] = []
        var sig: [String] = []
        let kinds: [XCUIElement.ElementType] = [.button, .link, .switch, .slider, .textField, .secureTextField, .segmentedControl, .stepper, .menuItem, .searchField]
        func walk(_ node: XCUIElementSnapshot) {
            let f = node.frame
            if kinds.contains(node.elementType) || (node.elementType == .staticText && !node.label.isEmpty) {
                rows.append([
                    "type": node.elementType.rawValue, "label": node.label, "id": node.identifier,
                    "x": f.origin.x, "y": f.origin.y, "w": f.size.width, "h": f.size.height,
                    "enabled": node.isEnabled,
                ])
            }
            if node.elementType == .staticText || kinds.contains(node.elementType) {
                sig.append("\(Int(f.origin.y / 2))|\(node.label.prefix(12))")
            }
            for child in node.children { walk(child) }
        }
        if let tree = try? app.snapshot() { walk(tree) }
        return (rows, sig.joined(separator: ";"))
    }

    private func auditSave(_ base: String, rows: [[String: Any]]) {
        if let jpeg = XCUIScreen.main.screenshot().image.jpegData(compressionQuality: 0.88) {
            FileManager.default.createFile(atPath: base + ".jpg", contents: jpeg)
        }
        if let data = try? JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]) {
            FileManager.default.createFile(atPath: base + ".controls.json", contents: data)
        }
    }
}
