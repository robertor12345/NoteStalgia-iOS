import Foundation

/// Opt-in hooks for recording demos and driving the app from a script. Every one is a launch
/// argument (`-Key value`, read through `UserDefaults`), so nothing here changes the shipped UX;
/// each is a single cached read.
///
/// ```
/// -NoteStalgiaDemoSignIn max@sunrise-care.co.uk   sign in as a mock account when the title fades
/// -NoteStalgiaDemoSkipLaunch YES                  title screen lasts only as long as warm-up
/// -NoteStalgiaDemoJump surface:Irene              after the welcome gate, jump straight to a scene
/// -NoteStalgiaDemoFreezeGlyphDrift YES            resident glyphs hold still so scripted taps land
/// -NoteStalgiaDemoAutoPhoto YES                   save-resident form pre-filled with a bundled portrait
/// -NoteStalgiaDemoAudioLog YES                    (see `DemoAudioLog`) log music/chime/phase events
/// ```
///
/// Jump targets: `roster`, `profile:<name prefix>`, `surface:<name prefix>`, `discovery`, `group`.
/// The scripted walkthroughs in `DemoUITests/` and the recording helpers in `tools/demo/` are built
/// on these plus the `accessibilityIdentifier`s listed in `tools/demo/README.md`.
enum DemoLaunchOptions {
    static let signInEmail: String? = {
        let value = UserDefaults.standard.string(forKey: "NoteStalgiaDemoSignIn")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }()

    static let skipLaunch = UserDefaults.standard.bool(forKey: "NoteStalgiaDemoSkipLaunch")

    static let freezeGlyphDrift = UserDefaults.standard.bool(forKey: "NoteStalgiaDemoFreezeGlyphDrift")

    /// `-NoteStalgiaDemoAutoPhoto YES` — the save-resident form arrives with a bundled portrait already
    /// in place, so a scripted discovery can press Save (the photo picker is system UI a script can't drive).
    static let autoPhoto = UserDefaults.standard.bool(forKey: "NoteStalgiaDemoAutoPhoto")

    static let jump: Jump? = UserDefaults.standard.string(forKey: "NoteStalgiaDemoJump").flatMap(Jump.init(argument:))

    enum Jump: Equatable {
        case roster
        case profile(namePrefix: String)
        case surface(namePrefix: String)
        case discovery
        case group

        init?(argument: String) {
            let parts = argument.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            switch parts.first?.lowercased() {
            case "roster": self = .roster
            case "discovery": self = .discovery
            case "group": self = .group
            case "profile" where parts.count == 2: self = .profile(namePrefix: parts[1])
            case "surface" where parts.count == 2: self = .surface(namePrefix: parts[1])
            default: return nil
            }
        }
    }
}

// MARK: - Coordinator hooks

extension SessionPOCState {
    /// Signs in as the `-NoteStalgiaDemoSignIn` account (PIN looked up from the mock credential
    /// store). Returns `true` when a sign-in happened. The normal welcome gate still runs afterwards.
    @discardableResult
    func applyDemoSignInIfRequested() -> Bool {
        guard let email = DemoLaunchOptions.signInEmail, !isSignedIn else { return false }
        guard let account = CareTenancyMockData.supervisors.first(where: {
            $0.email.caseInsensitiveCompare(email) == .orderedSame
        }) else {
            assertionFailure("Demo sign-in: no mock supervisor with email \(email)")
            return false
        }
        supervisorEmail = account.email
        supervisorPIN = SupervisorCredentialStore.accountWithEffectivePIN(account).pin
        return completeSupervisorSignIn() == nil
    }

    /// Jumps to a demo scene. Call once the roster is seeded (the welcome gate does this).
    /// Returns `false` when the target resident could not be found, so the caller can fall back
    /// to the roster.
    @discardableResult
    func performDemoJump(_ jump: DemoLaunchOptions.Jump) -> Bool {
        switch jump {
        case .roster:
            transitionToPhase(.carePatientList)
            return true
        case .discovery:
            beginNewResidentDiscovery()
            return true
        case .group:
            beginGroupSession()
            return true
        case let .profile(prefix):
            guard let patient = demoResident(matching: prefix) else { return false }
            recordResidentRosterView(patient.id)
            selectedCarePatientId = patient.id
            transitionToPhase(.carePatientDetail)
            return true
        case let .surface(prefix):
            guard let patient = demoResident(matching: prefix) else { return false }
            recordResidentRosterView(patient.id)
            selectedCarePatientId = patient.id
            phase = .carePatientDetail
            openResidentProfile()
            return true
        }
    }

    private func demoResident(matching prefix: String) -> CarePatientProfile? {
        let needle = prefix.lowercased()
        return residentsInCurrentHome().first { $0.displayName.lowercased().hasPrefix(needle) }
    }
}
