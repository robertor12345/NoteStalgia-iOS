import XCTest

/// Scripted, narrated walkthrough — one chronological story in three continuous takes, each a
/// test. Every step calls `mark(_:)`, which appends `epoch|label` to a markers file on the host
/// (`DEMO_MARKERS_FILE`, default /tmp/notestalgia-demo-markers.log); `tools/demo/pipeline/build_v4.py`
/// cuts captions and voice-over at those marks. Marker names must match the narration script in
/// `tools/demo/pipeline/narration.py`.
///
/// Pacing is deliberately slow: each screen is held long enough for its narration line.
/// `TEST_RUNNER_DEMO_PACE=1.2` stretches every hold by 1.2×. These are not assertion-heavy tests.
final class DemoWalkthroughUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pace: Double = 1
    private var markersPath = "/tmp/notestalgia-demo-markers.log"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        pace = Double(env["DEMO_PACE"] ?? "") ?? 1
        markersPath = env["DEMO_MARKERS_FILE"] ?? markersPath
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
            XCTAssertTrue(face.waitForExistence(timeout: 20), "Clip \(index + 1) did not start")
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
        app.staticTexts["Who are you caring for?"].firstMatch.tap()
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
        let comfort = app.segmentedControls["profile.groupComfort"]
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
        app.staticTexts["Who are you caring for?"].firstMatch.tap()   // dismiss the number pad
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
        hold(3)
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
        hold(34)
        let openSurface = app.buttons["profile.openSurface"]
        var tries = 0
        while !openSurface.isHittable, tries < 6 {
            slowScroll(points: -1500)
            hold(1)
            tries += 1
        }
        hold(2)

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

    // MARK: - Helpers

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
        let line = "\(Date().timeIntervalSince1970)|\(label)\n"
        if let handle = FileHandle(forWritingAtPath: markersPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: markersPath, contents: line.data(using: .utf8))
        }
    }

    private func hold(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds * pace)
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

    private func selectSegment(_ identifier: String, _ title: String) {
        let segmented = app.segmentedControls[identifier]
        if segmented.waitForExistence(timeout: 3) {
            segmented.buttons[title].tap()
        } else {
            app.buttons[title].firstMatch.tap()
        }
    }
}
