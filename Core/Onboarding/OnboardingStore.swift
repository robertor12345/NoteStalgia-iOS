import Combine
import Foundation

/// Drafts and loaded state for organisation onboarding: the workspace request, the code screen and
/// the org admin's six-step set-up. Observed directly by the onboarding screens and deliberately
/// **not** forwarded by the coordinator (same arrangement as `HouseholdFlowStore`), so typing never
/// re-renders the whole flow.
final class OnboardingStore: ObservableObject {
    // MARK: Request a workspace

    enum RequestStep: Equatable { case form, verify, done }

    @Published var requestStep: RequestStep = .form
    @Published var orgNameDraft = ""
    @Published var requesterName = ""
    @Published var requestEmail = ""
    @Published var requestPhone = ""
    @Published var requesterRole: OrgRequesterRole = .registeredManager
    @Published var homesBand: OrgHomesBand = .one
    @Published var requestCqc = ""
    @Published var requestNotes = ""
    @Published var requestConsent = false
    @Published var verifyCode = ""
    @Published var verifyDevCode: String?
    @Published var requestMessage: String?
    /// Set when the backend approved the request at once and exposed the activation code (demo).
    @Published var activationCodeFromServer: String?

    // MARK: "I have an invite or activation code"

    enum CodeKind: Equatable { case activation, invite }

    @Published var codeEmail = ""
    @Published var code = ""
    @Published var codeDisplayName = ""
    @Published var codePIN = ""
    @Published var codeConfirmPIN = ""
    @Published var acceptedTerms = false
    @Published var invitePreview: InvitePreview?

    /// Codes read `ORG-XXXX-XXXX` (activation) or `INV-XXXX-XXXX` (invite); case and punctuation are ignored.
    var normalisedCode: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    var codeKind: CodeKind? {
        let text = normalisedCode
        if text.hasPrefix("ORG") { return .activation }
        if text.hasPrefix("INV") { return .invite }
        return nil
    }

    var codeIsComplete: Bool {
        codeKind != nil && normalisedCode.count == 11
    }

    // MARK: Shared

    @Published var isBusy = false
    @Published var error: String?
    @Published var notice: String?
    /// Messages under individual fields, keyed by the field's accessibility identifier.
    @Published var fieldErrors: [String: String] = [:]

    /// One thing wrong with one field. `page` says where that field lives in the set-up wizard.
    struct FieldProblem: Equatable {
        var field: String
        var message: String
        var page: SetupPage? = nil
    }

    /// Shows what is wrong: a message under each field and the first one in the banner. When the
    /// first problem is on another page of the wizard, goes there so the field is on screen.
    func report(_ problems: [FieldProblem]) {
        guard let first = problems.first else {
            fieldErrors = [:]
            return
        }
        if let target = first.page, target != page { page = target }   // clears fieldErrors; set below
        fieldErrors = Dictionary(problems.map { ($0.field, $0.message) }, uniquingKeysWith: { current, _ in current })
        // One problem: say it. Several: the fields say their own, so the banner only counts them.
        error = problems.count > 1 ? "\(problems.count) fields need attention — see the highlighted ones." : first.message
        notice = nil
    }

    // MARK: Set-up wizard

    // MARK: Wizard structure — sections, pages, detours
    //
    // Six sections make up the stepper at the top. Each owns a few short pages of one task apiece, so
    // nothing needs a long scroll. "Add a home", "Invite someone" and "Check the spreadsheet" are
    // detours: a few pages that start from a section's overview page and come back to it.

    enum SetupSection: Int, CaseIterable, Identifiable {
        case organisation, homes, team, residents, devices, ready

        var id: Int { rawValue }
        var number: Int { rawValue + 1 }

        var title: String {
            switch self {
            case .organisation: return "Your organisation"
            case .homes: return "Your homes"
            case .team: return "Your team"
            case .residents: return "Residents"
            case .devices: return "The iPads"
            case .ready: return "Ready"
            }
        }

        var shortTitle: String {
            switch self {
            case .organisation: return "Organisation"
            case .homes: return "Homes"
            case .team: return "Team"
            case .residents: return "Residents"
            case .devices: return "iPads"
            case .ready: return "Ready"
            }
        }

        var systemImage: String {
            switch self {
            case .organisation: return "building.columns"
            case .homes: return "building.2"
            case .team: return "person.2"
            case .residents: return "person.crop.rectangle.stack"
            case .devices: return "ipad.landscape"
            case .ready: return "checkmark.seal"
            }
        }

        var mainPages: [SetupPage] { SetupPage.main.filter { $0.section == self } }
        var firstPage: SetupPage { mainPages[0] }
    }

    enum SetupDetour: Equatable {
        case addHome, inviteOne, inviteMany, reviewImport

        var pages: [SetupPage] {
            switch self {
            case .addHome: return [.homeDetails, .homeWings, .homeLead]
            case .inviteOne: return [.inviteWho, .inviteAccess]
            case .inviteMany: return [.inviteBulk]
            case .reviewImport: return [.residentsReview]
            }
        }

        /// The overview page the detour starts from and returns to.
        var owner: SetupPage {
            switch self {
            case .addHome: return .homesOverview
            case .inviteOne, .inviteMany: return .teamOverview
            case .reviewImport: return .residentsImport
            }
        }

        var title: String {
            switch self {
            case .addHome: return "Add a home"
            case .inviteOne: return "Invite one person"
            case .inviteMany: return "Invite several people"
            case .reviewImport: return "Check the spreadsheet"
            }
        }
    }

    enum SetupPage: String, CaseIterable, Identifiable {
        case orgDetails, orgAddress, orgDomains, orgDefaults
        case homesOverview, homeDetails, homeWings, homeLead
        case teamOverview, inviteWho, inviteAccess, inviteBulk
        case residentsImport, residentsReview
        case ipadGuidance, ipadRegister
        case readyChecklist, readyAudit

        var id: String { rawValue }

        /// The straight-through route. Detour pages are reached from their overview and are not in it.
        static let main: [SetupPage] = [
            .orgDetails, .orgAddress, .orgDomains, .orgDefaults,
            .homesOverview, .teamOverview, .residentsImport,
            .ipadGuidance, .ipadRegister,
            .readyChecklist, .readyAudit,
        ]

        var section: SetupSection {
            switch self {
            case .orgDetails, .orgAddress, .orgDomains, .orgDefaults: return .organisation
            case .homesOverview, .homeDetails, .homeWings, .homeLead: return .homes
            case .teamOverview, .inviteWho, .inviteAccess, .inviteBulk: return .team
            case .residentsImport, .residentsReview: return .residents
            case .ipadGuidance, .ipadRegister: return .devices
            case .readyChecklist, .readyAudit: return .ready
            }
        }

        var detour: SetupDetour? {
            switch self {
            case .homeDetails, .homeWings, .homeLead: return .addHome
            case .inviteWho, .inviteAccess: return .inviteOne
            case .inviteBulk: return .inviteMany
            case .residentsReview: return .reviewImport
            default: return nil
            }
        }

        var title: String {
            switch self {
            case .orgDetails: return "Name your organisation"
            case .orgAddress: return "Where you’re based"
            case .orgDomains: return "Your email domains"
            case .orgDefaults: return "Defaults for every home"
            case .homesOverview: return "Your homes"
            case .homeDetails: return "Add a home"
            case .homeWings: return "Name its wings"
            case .homeLead: return "Who leads it?"
            case .teamOverview: return "Your team"
            case .inviteWho: return "Who are you inviting?"
            case .inviteAccess: return "What can they do?"
            case .inviteBulk: return "Invite several people"
            case .residentsImport: return "Bring residents in"
            case .residentsReview: return "Check the spreadsheet"
            case .ipadGuidance: return "Set up the shared iPads"
            case .ipadRegister: return "Register this iPad"
            case .readyChecklist: return "What’s in place"
            case .readyAudit: return "The audit trail"
            }
        }

        /// Names the page on the bar's buttons: “‹ Address” and “Next: Domains”.
        var shortTitle: String {
            switch self {
            case .orgDetails: return "Details"
            case .orgAddress: return "Address"
            case .orgDomains: return "Domains"
            case .orgDefaults: return "Defaults"
            case .homesOverview: return "Homes"
            case .homeDetails: return "Home"
            case .homeWings: return "Wings"
            case .homeLead: return "Lead"
            case .teamOverview: return "Team"
            case .inviteWho: return "Who"
            case .inviteAccess: return "Access"
            case .inviteBulk: return "Several"
            case .residentsImport: return "Residents"
            case .residentsReview: return "Review"
            case .ipadGuidance: return "iPads"
            case .ipadRegister: return "This iPad"
            case .readyChecklist: return "Checklist"
            case .readyAudit: return "Audit"
            }
        }

        var caption: String {
            switch self {
            case .orgDetails: return "The name and registration shown on exports and in staff invites."
            case .orgAddress: return "Your head-office address. Everything is stored in the United Kingdom."
            case .orgDomains: return "Staff on a verified domain are sent to staff sign-in, not Care at home."
            case .orgDefaults: return "Saved with the organisation; every home starts from these."
            case .homesOverview: return "Each home has wings that group its roster."
            case .homeDetails: return "Its name, registration number and size."
            case .homeWings: return "Wings group the roster; every resident sits in one of them."
            case .homeLead: return "A home lead invites their own staff and sees the home’s dashboard."
            case .teamOverview: return "Invite supervisors and home leads. Everyone chooses their own PIN."
            case .inviteWho: return "They’ll get an invite code by email, valid for 7 days."
            case .inviteAccess: return "Their role, which homes, and an end date for temporary cover."
            case .inviteBulk: return "One person per line: email, name, role, home."
            case .residentsImport: return "From a spreadsheet, or one at a time through discovery."
            case .residentsReview: return "Every row is checked before anyone is added to the roster."
            case .ipadGuidance: return "Guidance, not enforcement — the app works without any of it."
            case .ipadRegister: return "Say which home it belongs to, so a tablet found in the wrong wing can be identified."
            case .readyChecklist: return "Finish the lines marked “to do” when you can — nothing blocks a session."
            case .readyAudit: return "Every set-up action, with who and when. Append-only."
            }
        }

        /// Pages whose unsent work is shared: moving between them keeps it, leaving them asks.
        var draftScope: String? {
            switch self {
            case .orgDetails, .orgAddress, .orgDomains, .orgDefaults: return "organisation"
            case .homeDetails, .homeWings, .homeLead: return "home"
            case .inviteWho, .inviteAccess: return "invite"
            case .inviteBulk: return "bulk"
            case .residentsReview: return "import"
            case .ipadRegister: return "device"
            default: return nil
            }
        }
    }

    @Published var page: SetupPage = .orgDetails {
        didSet { if oldValue != page, !fieldErrors.isEmpty { fieldErrors = [:] } }
    }

    var section: SetupSection { page.section }
    var detour: SetupDetour? { page.detour }

    /// The page before this one: inside a detour its previous page (the first one steps back out to the
    /// overview it started from); on the main route the previous main page.
    func previousPage(of page: SetupPage) -> SetupPage? {
        if let detour = page.detour {
            guard let index = detour.pages.firstIndex(of: page) else { return detour.owner }
            return index == 0 ? detour.owner : detour.pages[index - 1]
        }
        guard let index = SetupPage.main.firstIndex(of: page), index > 0 else { return nil }
        return SetupPage.main[index - 1]
    }

    /// The page after this one; `nil` at the end of a detour (its last page commits) and of the route.
    func nextPage(of page: SetupPage) -> SetupPage? {
        if let detour = page.detour {
            guard let index = detour.pages.firstIndex(of: page), index + 1 < detour.pages.count else { return nil }
            return detour.pages[index + 1]
        }
        guard let index = SetupPage.main.firstIndex(of: page), index + 1 < SetupPage.main.count else { return nil }
        return SetupPage.main[index + 1]
    }

    /// “1 of 4” for the page within its section, or within its detour.
    var pagePosition: (index: Int, count: Int) {
        if let detour {
            return ((detour.pages.firstIndex(of: page) ?? 0) + 1, detour.pages.count)
        }
        let pages = section.mainPages
        return ((pages.firstIndex(of: page) ?? 0) + 1, pages.count)
    }

    /// Small caption above the page title.
    var pageEyebrow: String {
        let position = pagePosition
        // One page on its own ("Your team", "Check the spreadsheet") has nothing to count, and a
        // detour's title would only repeat the page title, so name the section instead.
        if position.count == 1 { return section.shortTitle }
        let label = detour?.title ?? section.shortTitle
        return "\(label) · \(position.index) of \(position.count)"
    }

    // MARK: Leaving a step with unsaved work

    /// Something typed or picked on a step that has not been sent yet.
    enum SetupDraft: Equatable {
        case organisation
        case home(name: String)
        case invite
        case importPreview(count: Int)
        case device
    }

    /// Where the admin is trying to go when a draft is in the way.
    enum SetupDestination: Equatable {
        case page(SetupPage)
        case exit
        case finish
    }

    struct PendingLeave: Equatable {
        var draft: SetupDraft
        var destination: SetupDestination

        var title: String {
            switch draft {
            case .organisation: return "Save your changes to the organisation?"
            case .home(let name): return "Add “\(name)” first?"
            case .invite: return "Send the invite first?"
            case .importPreview(let count): return "Import \(count) resident\(count == 1 ? "" : "s") first?"
            case .device: return "Register this iPad first?"
            }
        }

        var message: String {
            switch draft {
            case .organisation: return "You changed the profile, domains or settings and haven’t saved them yet."
            case .home: return "You started adding a home that isn’t on the list yet."
            case .invite: return "You filled in an invite that hasn’t been sent."
            case .importPreview: return "The spreadsheet is checked but nobody has been added to the roster yet."
            case .device: return "You gave this iPad a label but haven’t registered it."
            }
        }

        var saveLabel: String {
            let tail: String
            switch destination {
            case .exit: tail = "leave"
            case .finish: tail = "finish"
            case .page: tail = "continue"
            }
            switch draft {
            case .organisation: return "Save and \(tail)"
            case .home: return "Add home and \(tail)"
            case .invite: return "Send and \(tail)"
            case .importPreview: return "Import and \(tail)"
            case .device: return "Register and \(tail)"
            }
        }
    }

    @Published var pendingLeave: PendingLeave?
    @Published var organisation: OrganisationPayload?
    @Published var homes: [OrgHome] = []
    @Published var invites: [OrgInvite] = []
    @Published var accounts: [OrgAccount] = []
    @Published var devices: [OrgDevice] = []
    @Published var audit: [OrgAuditEntry] = []
    /// Demo deployments return invite codes in the response; kept per email so staff can be told.
    @Published var issuedCodes: [String: String] = [:]
    private var draftsSeeded = false

    // Organisation drafts
    @Published var orgName = "" { didSet { clearErrorOnEdit() } }
    @Published var tradingName = "" { didSet { clearErrorOnEdit() } }
    @Published var cqcProviderId = "" { didSet { clearErrorOnEdit() } }
    @Published var addressLine1 = "" { didSet { clearErrorOnEdit() } }
    @Published var addressTown = "" { didSet { clearErrorOnEdit() } }
    @Published var addressPostcode = "" { didSet { clearErrorOnEdit() } }
    @Published var settings: OrgSettings = .default { didSet { clearErrorOnEdit() } }
    @Published var newDomain = "" { didSet { clearErrorOnEdit() } }
    @Published var domainMethod: DomainClaimMethod = .email
    @Published var domainCode = "" { didSet { clearErrorOnEdit() } }
    @Published var domainDevCode: String?
    @Published var pendingDomain: String?
    @Published var pendingDomainRecord: DNSRecord?
    /// A finished export waiting to be shared (ShareLink); cleared with "Done".
    @Published var exportFile: OrgExportFile?
    @Published var exportingHomeId: String?

    // Home drafts
    @Published var homeName = "" { didSet { clearErrorOnEdit() } }
    @Published var homeCqc = "" { didSet { clearErrorOnEdit() } }
    @Published var homeCapacity = "" { didSet { clearErrorOnEdit() } }
    @Published var homeWings: [String] = ["Residential", "Memory care", "Day programme"]
    @Published var newWing = "" { didSet { clearErrorOnEdit() } }
    @Published var homeLeadIsMe = true
    @Published var homeLeadEmail = "" { didSet { clearErrorOnEdit() } }
    @Published var homeLeadName = "" { didSet { clearErrorOnEdit() } }

    // Invite drafts
    @Published var inviteEmail = "" { didSet { clearErrorOnEdit() } }
    @Published var inviteName = "" { didSet { clearErrorOnEdit() } }
    @Published var inviteRole: SupervisorRole = .supervisor
    @Published var inviteHomeIds: Set<String> = []
    @Published var inviteHasEndDate = false
    @Published var inviteEndsAt = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @Published var bulkText = "" { didSet { clearErrorOnEdit() } }
    @Published var bulkErrors: [BulkInviteError] = []
    @Published var showsStaff = false

    // Residents (CSV import)
    @Published var importHomeId: String?
    @Published var importPreview: ResidentCSVImport.Preview?
    @Published var importResult: String?

    // Devices
    @Published var deviceLabel = "" { didSet { clearErrorOnEdit() } }
    @Published var deviceHomeId: String?

    /// A message about a field is stale once the admin changes anything on the step.
    private func clearErrorOnEdit() {
        if error != nil { error = nil }
    }

    // MARK: Resets

    func resetRequest(prefillEmail: String = "") {
        requestStep = .form
        orgNameDraft = ""
        requesterName = ""
        requestEmail = prefillEmail
        requestPhone = ""
        requesterRole = .registeredManager
        homesBand = .one
        requestCqc = ""
        requestNotes = ""
        requestConsent = false
        verifyCode = ""
        verifyDevCode = nil
        requestMessage = nil
        activationCodeFromServer = nil
        error = nil
        notice = nil
    }

    func resetCode(prefillEmail: String = "", prefillCode: String = "") {
        codeEmail = prefillEmail
        code = prefillCode
        codeDisplayName = ""
        codePIN = ""
        codeConfirmPIN = ""
        acceptedTerms = false
        invitePreview = nil
        error = nil
        notice = nil
    }

    func beginSetup() {
        page = .orgDetails
        error = nil
        notice = nil
        importPreview = nil
        importResult = nil
    }

    func resetHomeDraft() {
        homeName = ""
        homeCqc = ""
        homeCapacity = ""
        homeWings = ["Residential", "Memory care", "Day programme"]
        newWing = ""
        homeLeadIsMe = true
        homeLeadEmail = ""
        homeLeadName = ""
    }

    func resetInviteDraft() {
        inviteEmail = ""
        inviteName = ""
        inviteRole = .supervisor
        inviteHasEndDate = false
    }

    func resetAll() {
        resetRequest()
        resetCode()
        beginSetup()
        organisation = nil
        homes = []
        invites = []
        accounts = []
        devices = []
        audit = []
        issuedCodes = [:]
        draftsSeeded = false
        resetHomeDraft()
        resetInviteDraft()
        inviteHomeIds = []
        pendingDomain = nil
        pendingDomainRecord = nil
        exportFile = nil
        exportingHomeId = nil
        bulkText = ""
        bulkErrors = []
        importHomeId = nil
        deviceLabel = ""
        deviceHomeId = nil
    }

    /// Loaded organisation → profile drafts (only the first time, so typing is never overwritten).
    /// `reseedDrafts`: after a save, show what the server stored (normalised postcode, tidied names),
    /// so the profile doesn't look edited when nothing has changed.
    func apply(_ payload: OrganisationPayload, reseedDrafts: Bool = false) {
        organisation = payload
        guard reseedDrafts || !draftsSeeded else { return }
        draftsSeeded = true
        let org = payload.organisation
        orgName = org.name
        tradingName = org.tradingName ?? ""
        cqcProviderId = org.cqcProviderId ?? ""
        addressLine1 = org.address?.line1 ?? ""
        addressTown = org.address?.town ?? ""
        addressPostcode = org.address?.postcode ?? ""
        settings = org.settings
    }

    /// Keeps per-home selections pointing at homes that still exist.
    func reconcileHomeSelections() {
        let ids = Set(homes.filter { $0.status != "archived" }.map(\.id))
        inviteHomeIds = inviteHomeIds.intersection(ids)
        if inviteHomeIds.isEmpty, let first = homes.first(where: { $0.status != "archived" }) {
            inviteHomeIds = [first.id]
        }
        if importHomeId == nil || !ids.contains(importHomeId ?? "") { importHomeId = homes.first(where: { $0.status != "archived" })?.id }
        if deviceHomeId == nil || !ids.contains(deviceHomeId ?? "") { deviceHomeId = homes.first(where: { $0.status != "archived" })?.id }
    }

    // MARK: Drafts and progress

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// True when the profile, address or settings on screen differ from what the server has.
    var organisationIsDirty: Bool {
        guard let org = organisation?.organisation else { return false }
        return InputRules.tidy(orgName) != org.name
            || InputRules.tidy(tradingName) != (org.tradingName ?? "")
            || trimmed(cqcProviderId) != (org.cqcProviderId ?? "")
            || trimmed(addressLine1) != (org.address?.line1 ?? "")
            || trimmed(addressTown) != (org.address?.town ?? "")
            || (InputRules.normalisePostcode(addressPostcode) ?? trimmed(addressPostcode)) != (org.address?.postcode ?? "")
            || settings != org.settings
    }

    var inviteDraftHasContent: Bool {
        !trimmed(inviteEmail).isEmpty || !trimmed(bulkText).isEmpty
    }

    /// The unsent work on `page`, if any.
    func draftInProgress(on page: SetupPage) -> SetupDraft? {
        switch page {
        case .orgDetails, .orgAddress, .orgDomains, .orgDefaults:
            return organisationIsDirty ? .organisation : nil
        case .homeDetails, .homeWings, .homeLead:
            let name = trimmed(homeName)
            return name.isEmpty ? nil : .home(name: name)
        case .inviteWho, .inviteAccess:
            return trimmed(inviteEmail).isEmpty ? nil : .invite
        case .inviteBulk:
            return trimmed(bulkText).isEmpty ? nil : .invite
        case .residentsReview:
            if let preview = importPreview, !preview.validRows.isEmpty { return .importPreview(count: preview.validRows.count) }
            return nil
        case .ipadRegister:
            return trimmed(deviceLabel).isEmpty ? nil : .device
        default:
            return nil
        }
    }

    /// Back to what the server has (the "Discard" of an organisation draft).
    func revertOrganisationDrafts() {
        guard let org = organisation?.organisation else { return }
        orgName = org.name
        tradingName = org.tradingName ?? ""
        cqcProviderId = org.cqcProviderId ?? ""
        addressLine1 = org.address?.line1 ?? ""
        addressTown = org.address?.town ?? ""
        addressPostcode = org.address?.postcode ?? ""
        settings = org.settings
    }

    func clearInviteDraft() {
        inviteEmail = ""
        inviteName = ""
        bulkText = ""
        bulkErrors = []
    }

    /// Whether the admin has done their part of a section (drives the stepper's ticks and where
    /// "Continue set-up" resumes). Nothing blocks a session, so this is guidance, not a gate.
    func isSectionDone(_ section: SetupSection) -> Bool {
        guard let checklist = organisation?.checklist else { return false }
        switch section {
        case .organisation: return storedAddressIsComplete
        case .homes: return checklist.homes > 0
        case .team: return checklist.staffActive > 1 || checklist.invitesPending > 0
        case .residents: return checklist.residents > 0
        case .devices: return checklist.devices > 0
        case .ready: return checklist.complete
        }
    }

    /// The saved profile has what an export needs: a first line, a town and a valid postcode.
    var storedAddressIsComplete: Bool {
        guard let address = organisation?.organisation.address else { return false }
        return !InputRules.tidy(address.line1 ?? "").isEmpty
            && !InputRules.tidy(address.town ?? "").isEmpty
            && InputRules.normalisePostcode(address.postcode ?? "") != nil
    }

    /// The first of organisation → iPads still to do; the checklist when everything is in place. A
    /// profile that only lacks its address resumes on the address page rather than the name.
    var firstIncompletePage: SetupPage {
        if !isSectionDone(.organisation) { return .orgAddress }
        for section in [SetupSection.homes, .team, .residents, .devices] where !isSectionDone(section) {
            return section.firstPage
        }
        return .readyChecklist
    }

    func home(id: String?) -> OrgHome? {
        guard let id else { return nil }
        return homes.first { $0.id == id }
    }

    var liveHomes: [OrgHome] { homes.filter { $0.status != "archived" } }
    var pendingInvites: [OrgInvite] { invites.filter { $0.status == "pending" } }
    var settledInvites: [OrgInvite] { invites.filter { $0.status != "pending" } }
}
