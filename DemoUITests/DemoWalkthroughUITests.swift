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

    // MARK: - Helpers

    private func launch(autoSignIn: Bool, skipLaunch: Bool) {
        var arguments = ["-NoteStalgiaDemoAudioLog", "YES", "-NoteStalgiaDemoAutoPhoto", "YES"]
        if autoSignIn { arguments += ["-NoteStalgiaDemoSignIn", "max@sunrise-care.co.uk"] }
        if skipLaunch { arguments += ["-NoteStalgiaDemoSkipLaunch", "YES"] }
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
