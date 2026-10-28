import Foundation

// MARK: - What is wrong with each form
//
// Each form's problems are gathered in the order the fields appear, so the first one is the first
// thing to fix and, in the wizard, the page to go back to. Field ids are the accessibility
// identifiers of the fields, which is also how the field finds its own message.

extension OnboardingStore {
    private func collect(_ build: (_ add: (String?, String, SetupPage?) -> Void) -> Void) -> [FieldProblem] {
        var problems: [FieldProblem] = []
        build { message, field, page in
            if let message { problems.append(FieldProblem(field: field, message: message, page: page)) }
        }
        return problems
    }

    // MARK: Request a workspace and use a code (before sign-in)

    func requestProblems() -> [FieldProblem] {
        collect { add in
            add(InputRules.businessName(orgNameDraft, label: "the organisation’s name", required: true), "onboarding.request.org", nil)
            add(InputRules.personName(requesterName, required: true, label: "Your name"), "onboarding.request.name", nil)
            add(InputRules.email(requestEmail), "onboarding.request.email", nil)
            add(InputRules.phone(requestPhone), "onboarding.request.phone", nil)
            add(InputRules.cqcId(requestCqc, kind: "provider"), "onboarding.request.cqc", nil)
            add(InputRules.freeText(requestNotes, label: "notes", max: 1000), "onboarding.request.notes", nil)
            if !requestConsent { add("Tick the box so we can contact you about the request.", "onboarding.request.consent", nil) }
        }
    }

    func codeProblems() -> [FieldProblem] {
        collect { add in
            add(InputRules.email(codeEmail, label: "the email address the code was sent to"), "onboarding.codeEmail", nil)
            // An invite with a name already on it can be accepted as written; otherwise ask.
            let nameKnown = codeKind != .invite || !(invitePreview?.displayName ?? "").isEmpty
            add(InputRules.personName(codeDisplayName, required: !nameKnown, label: "Your name"), "onboarding.codeName", nil)
        }
    }

    // MARK: Organisation

    /// `page` limits the check to one wizard page. Anything on the address page is required there;
    /// elsewhere (saving everything at once) an address may still be empty, but not malformed.
    func organisationProblems(onPage page: SetupPage? = nil) -> [FieldProblem] {
        collect { add in
            if page == nil || page == .orgDetails {
                add(InputRules.businessName(orgName, label: "the organisation’s name", required: true), "onboarding.org.name", .orgDetails)
                add(InputRules.businessName(tradingName, label: "the trading name"), "onboarding.org.trading", .orgDetails)
                add(InputRules.cqcId(cqcProviderId, kind: "provider"), "onboarding.org.cqc", .orgDetails)
            }
            if page == nil || page == .orgAddress {
                let required = page == .orgAddress
                add(InputRules.addressLine(addressLine1, label: "The first address line", required: required), "onboarding.org.address", .orgAddress)
                add(InputRules.town(addressTown, required: required), "onboarding.org.town", .orgAddress)
                add(InputRules.postcode(addressPostcode, required: required), "onboarding.org.postcode", .orgAddress)
            }
        }
    }

    // MARK: Homes

    func homeProblems() -> [FieldProblem] {
        collect { add in
            add(InputRules.businessName(homeName, label: "the home’s name", required: true, max: 80), "onboarding.home.name", .homeDetails)
            add(InputRules.cqcId(homeCqc, kind: "location"), "onboarding.home.cqc", .homeDetails)
            add(InputRules.beds(homeCapacity), "onboarding.home.capacity", .homeDetails)
            if homeWings.allSatisfy({ InputRules.tidy($0).isEmpty }) {
                add("A home needs at least one wing.", "onboarding.home.newWing", .homeWings)
            } else {
                add(InputRules.wings(homeWings), "onboarding.home.newWing", .homeWings)
            }
            if !homeLeadIsMe {
                add(InputRules.email(homeLeadEmail, label: "the home lead’s work email"), "onboarding.home.leadEmail", .homeLead)
                add(InputRules.personName(homeLeadName, label: "The home lead’s name"), "onboarding.home.leadName", .homeLead)
            }
        }
    }

    /// The wing typed in the "Add a wing" box: why it can't be added, or nil.
    func newWingProblem() -> String? {
        let name = InputRules.tidy(newWing)
        if name.isEmpty { return "Type a wing name first." }
        if let problem = InputRules.businessName(name, label: "a wing name", min: 1, max: 40) { return problem }
        if homeWings.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { return "“\(name)” is already on the list." }
        if homeWings.count >= 20 { return "That’s plenty of wings — 20 at most." }
        return nil
    }

    // MARK: Team

    func inviteProblems() -> [FieldProblem] {
        collect { add in
            add(InputRules.email(inviteEmail), "onboarding.invite.email", .inviteWho)
            add(InputRules.personName(inviteName), "onboarding.invite.name", .inviteWho)
            if inviteRole != .orgAdmin, inviteHomeIds.isEmpty { add("Choose at least one home for this invite.", "onboarding.invite.homes", .inviteAccess) }
        }
    }

    // MARK: iPads

    func deviceProblems() -> [FieldProblem] {
        collect { add in
            add(InputRules.businessName(deviceLabel, label: "a label for this iPad", required: true, max: 60), "onboarding.device.label", nil)
            if home(id: deviceHomeId) == nil { add("Choose the home this iPad belongs to.", "onboarding.device.home", nil) }
        }
    }
}
