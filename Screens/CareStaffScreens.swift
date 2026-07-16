import SwiftUI
import UIKit
import PhotosUI

// MARK: - Patient roster

struct CarePatientListView: View {
    @ObservedObject var state: SessionPOCState
    @FocusState private var searchFocused: Bool

    private var presentation: CareRosterPresentation {
        state.rosterPresentation()
    }

    private var currentHome: CareHome? {
        state.currentHome()
    }

    private var canSwitchHome: Bool {
        (state.currentSupervisorAccount()?.homeIds.count ?? 0) > 1
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to home",
                onBack: {
                    state.selectedCarePatientId = nil
                    state.navigateStaffToHome()
                },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    rosterHeader

                    searchField

                    if !presentation.isSearching, let home = currentHome {
                        wingFilterRow(home: home)
                            .centeredScrollFullBleed()
                        displayModePicker
                    }

                    careHomeSentimentCard

                    PrimaryButton(title: "Start discovery for new resident") {
                        state.beginNewResidentDiscovery()
                    }
                    .padding(.horizontal, 24)

                    SecondaryButton(title: "Group mode") {
                        state.beginGroupSession()
                    }
                    .padding(.horizontal, 24)

                    groupModeHint

                    if let groupLine = state.latestGroupSessionSummaryLine() {
                        FadeInLine(text: groupLine, font: BrandTheme.orbHintFont(), muted: true, delay: 0.12)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    rosterSections

                    if !presentation.isSearching, !presentation.isBrowsingAll {
                        SecondaryButton(title: "Browse all \(presentation.totalActiveResidents) residents") {
                            state.rosterBrowsingAllResidents = true
                        }
                        .padding(.horizontal, 24)
                    }

                    if presentation.isBrowsingAll {
                        SecondaryButton(title: "Back to today’s roster") {
                            state.rosterBrowsingAllResidents = false
                        }
                        .padding(.horizontal, 24)
                    }

                    if canSwitchHome {
                        SecondaryButton(title: "Switch care home") {
                            state.switchHome()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            StreamAudioCache.prefetchWarmCatalog()
            if !state.isSignedIn {
                state.phase = .home
            } else if state.currentHomeId == nil {
                state.phase = .careHomePicker
            }
        }
    }

    private var rosterHeader: some View {
        VStack(spacing: 8) {
            FadeInTitle(text: presentation.homeName, delay: 0)
            FadeInLine(
                text: "\(presentation.totalActiveResidents) residents · curated for today",
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandTheme.textSecondary)
            TextField("Search name, room, or wing", text: $state.rosterSearchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
            if !state.rosterSearchQuery.isEmpty {
                Button {
                    state.rosterSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BrandTheme.creamMid.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }

    private func wingFilterRow(home: CareHome) -> some View {
        HorizontalScrollEdgeFade(coordinateSpace: "rosterWingFilter") {
            HStack(spacing: 10) {
                wingChip(title: "All wings", wingId: nil)
                ForEach(home.wings) { wing in
                    wingChip(title: wing.name, wingId: wing.id)
                }
            }
        }
    }

    private func wingChip(title: String, wingId: String?) -> some View {
        let selected = state.rosterSelectedWingId == wingId || (wingId == nil && state.rosterSelectedWingId == nil)
        return Button {
            if wingId == nil {
                state.rosterSelectedWingId = nil
            } else if state.rosterSelectedWingId == wingId {
                state.rosterSelectedWingId = nil
            } else {
                state.rosterSelectedWingId = wingId
            }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? BrandTheme.textPrimary : BrandTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? BrandTheme.gold.opacity(0.22) : BrandTheme.cream.opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(BrandTheme.gold.opacity(selected ? 0.5 : 0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var displayModePicker: some View {
        Picker("Display", selection: $state.rosterDisplayMode) {
            ForEach(CareRosterDisplayMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // `LazyVStack` defers building each row until it's about to scroll into view (this still
    // lives inside `CenteredScrollScreen`'s `ScrollView`, so laziness applies even though the
    // outer content stack is eager). Matters most in "browse all residents" mode, which can
    // list every active resident in the home instead of the day's curated ~20.
    @ViewBuilder
    private var rosterSections: some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            ForEach(presentation.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                        if let subtitle = section.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 8)

                    ForEach(section.patientIds, id: \.self) { patientId in
                        if let patient = state.carePatient(id: patientId) {
                            rosterRow(for: patient)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rosterRow(for patient: CarePatientProfile) -> some View {
        let subtitle = rosterSubtitle(for: patient)
        let isPinned = state.rosterPinnedResidentIds.contains(patient.id)

        if state.rosterDisplayMode == .compact {
            HStack(spacing: 12) {
                Button {
                    openPatient(patient)
                } label: {
                    HStack(spacing: 12) {
                        CarePatientPortraitView(
                            assetName: patient.stockPortraitAssetName,
                            customImage: state.portraitImage(for: patient.id),
                            remoteURL: patient.remotePortraitURL,
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(patient.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(BrandTheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.gold.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandTheme.cream.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ChimingPlainButtonStyle())

                Button {
                    state.toggleRosterPin(patient.id)
                } label: {
                    Image(systemName: isPinned ? "star.fill" : "star")
                        .foregroundStyle(isPinned ? BrandTheme.gold : BrandTheme.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin \(patient.displayName)" : "Pin \(patient.displayName)")
            }
            .padding(.horizontal, 4)
        } else {
            ZStack(alignment: .topTrailing) {
                OrbPortraitNavButton(
                    portraitAssetName: patient.stockPortraitAssetName,
                    customPortraitImage: state.portraitImage(for: patient.id),
                    remotePortraitURL: patient.remotePortraitURL,
                    title: patient.displayName,
                    subtitle: subtitle
                ) {
                    openPatient(patient)
                }

                Button {
                    state.toggleRosterPin(patient.id)
                } label: {
                    Image(systemName: isPinned ? "star.fill" : "star")
                        .font(.body)
                        .foregroundStyle(isPinned ? BrandTheme.gold : BrandTheme.textSecondary)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin \(patient.displayName)" : "Pin \(patient.displayName)")
            }
            .padding(.horizontal, 4)
        }
    }

    private func openPatient(_ patient: CarePatientProfile) {
        state.recordResidentRosterView(patient.id)
        state.selectedCarePatientId = patient.id
        state.transitionToPhase(.carePatientDetail)
    }

    private func rosterSubtitle(for patient: CarePatientProfile) -> String {
        var parts = [patient.careContextLabel]
        if let sentiment = state.sentimentSummary(for: patient.id).formattedAveragesLine() {
            parts.append(sentiment)
        }
        if let last = state.recordsForPatient(patient.id).first {
            parts.append(lastSessionSummary(last))
        }
        return parts.joined(separator: " · ")
    }

    private func lastSessionSummary(_ last: CareSessionRecord) -> String {
        var parts = ["Last visit", last.moodSummary, "\(last.calmPercent)% at ease"]
        if let s = last.settledness {
            parts.append("settled \(s)%")
        }
        return parts.joined(separator: " · ")
    }

    private var careHomeSentimentCard: some View {
        let overview = state.careHomeSentimentOverview()
        return Group {
            if overview.hasData {
                BrandCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Care home — supervisor observations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                        Text("Rolling averages across recent sessions with sentiment ratings.")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let line = overview.formattedAveragesLine() {
                            Text(line)
                                .font(.body.weight(.medium))
                                .foregroundStyle(BrandTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("\(overview.sessionCount) rated session\(overview.sessionCount == 1 ? "" : "s") on file")
                            .font(.caption2)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var groupModeHint: some View {
        FadeInLine(
            text: "Traditional playlist controls for a shared room — tracks are compiled from resident listening data on this home’s roster.",
            font: BrandTheme.orbHintFont(),
            muted: true,
            delay: 0.08
        )
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
    }
}

// MARK: - New resident discovery — age input (feeds snippet algorithm)

struct CareDiscoveryAgeInputView: View {
    @ObservedObject var state: SessionPOCState
    @FocusState private var ageFocused: Bool
    @State private var errorMessage: String?

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to roster",
                onBack: { state.abandonNewResidentAgeInput() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 24) {
                    FadeInTitle(text: "About this resident", delay: 0)
                    FadeInLine(
                        text: "Age and nationality help us order the listening pass — era first, with a soft cultural music bias.",
                        delay: 0.08
                    )

                    BrandCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Age")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                TextField("e.g. 82", text: $state.newResidentAgeDraft)
                                    .keyboardType(.numberPad)
                                    .focused($ageFocused)
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(BrandTheme.creamMid.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                                    )
                                Text("Peak listening years (roughly teens through twenties) order calm clips by era.")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            ResidentNationalityMenuField(
                                title: "Nationality",
                                selection: $state.newResidentNationalityDraft,
                                caption: "Gently weights familiar genres and moods — never overrides their live reactions."
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    PrimaryButton(title: "Begin listening discovery") {
                        errorMessage = state.continueNewResidentDiscoveryFromAgeInput()
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            if !state.isSignedIn { state.phase = .home }
        }
    }
}

// MARK: - New resident profile capture (after first session)

struct CareNewResidentProfileView: View {
    @ObservedObject var state: SessionPOCState
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var errorMessage: String?

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to roster",
                onBack: { state.cancelNewResidentProfileSave() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Save this resident", delay: 0)
                    FadeInLine(
                        text: "So the next supervisor can recognise them on the roster.",
                        delay: 0.08
                    )

                    BrandCard {
                        VStack(spacing: 18) {
                            photoSection

                            profileField(title: "Name", text: $state.newResidentProfileNameDraft, prompt: "Full name or preferred name")

                            profileField(title: "Age", text: $state.newResidentProfileAgeDraft, prompt: "Age", keyboard: .numberPad)

                            ResidentNationalityMenuField(
                                title: "Nationality",
                                selection: $state.newResidentProfileNationalityDraft
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 4)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    PrimaryButton(title: "Save to roster") {
                        errorMessage = state.saveNewResidentProfile()
                        if errorMessage == nil {
                            CalmExperienceFeedback.signInSuccess()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $state.newResidentProfilePhoto)
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, new in
            Task {
                guard let new else { return }
                if let data = try? await new.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    let resized = ui.downscaledForDisplay(maxDimension: 600)
                    await MainActor.run { state.newResidentProfilePhoto = resized }
                }
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 14) {
            if let photo = state.newResidentProfilePhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(BrandTheme.gold.opacity(0.45), lineWidth: 2))
                    .shadow(color: BrandTheme.brown.opacity(0.12), radius: 10, y: 4)
            } else {
                ZStack {
                    NoteStalgiaOrbBackdrop(diameter: 132, pulse: 0.5, glowPulse: 0.62)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(BrandTheme.goldDeep)
                }
                .frame(width: 132, height: 132)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                OrbPickerLabel(title: "Choose photo", systemImage: "photo.stack")
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    OrbPickerLabel(title: "Take photo", systemImage: "camera.fill")
                }
                .buttonStyle(ChimingPlainButtonStyle())
            }
        }
    }

    private func profileField(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .font(.body)
                .foregroundStyle(BrandTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(BrandTheme.creamMid.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Native `Menu` dropdown styled like the cream staff form fields — flag + country name.
struct ResidentNationalityMenuField: View {
    let title: String
    @Binding var selection: ResidentNationality
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)

            Menu {
                Picker(title, selection: $selection) {
                    ForEach(ResidentNationality.menuOrder) { nationality in
                        Text(nationality.menuLabel).tag(nationality)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(selection.flagEmoji)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(selection.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.goldDeep.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandTheme.creamMid.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                )
            }
            .accessibilityLabel("\(title), \(selection.displayName)")
            .accessibilityHint("Opens a list of nationalities")

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Environment & IoT prep (lighting, immersive / VR)

struct CareSessionPrepView: View {
    @ObservedObject var state: SessionPOCState

    private let durationChoices = [10, 12, 15, 20, 25]

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.selectedCarePatientId)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to profile",
                onBack: { state.phase = .carePatientDetail },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(alignment: .leading, spacing: 20) {
                    FadeInLine(
                        text: "If you use smart lights, a headset, or a TV in the room, set that up here so the session matches the space. None of this is required — it’s just so NoteStalgia knows what you have.",
                        font: BrandTheme.orbHintFont(),
                        muted: true,
                        delay: 0.06
                    )
                    .frame(maxWidth: .infinity)

                    if let patient {
                        BrandCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("With \(patient.displayName)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Text("Light: \(patient.preferredLight)")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text("Scent: \(patient.scentGuidance)")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text("Touch: \(patient.touchComfortNotes)")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)
                    }

                    Text("Smart lighting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .padding(.horizontal, 4)

                    BrandCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pair a bridge if you have one — then a calm scene can drift with the session: warmer dim, slow fades, no sudden bright flashes.")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textSecondary)
                            iotToggle("Philips Hue scenes", isOn: $state.iotPhilipsHueEnabled)
                            iotToggle("Apple HomeKit rooms", isOn: $state.iotHomeKitEnabled)
                            iotToggle("Matter accessories", isOn: $state.iotMatterEnabled)
                            Divider().opacity(0.35)
                            iotToggle("Soft light pulses with the breathing pace", isOn: $state.iotFollowSessionBreath)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Max scene brightness cap")
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Spacer()
                                    Text("\(Int((state.iotMaxSceneBrightness * 100).rounded()))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(BrandTheme.textSecondary)
                                }
                                Slider(value: $state.iotMaxSceneBrightness, in: 0.15 ... 1)
                                    .tint(BrandTheme.goldDeep)
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    Text("Immersive & VR")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .padding(.horizontal, 4)

                    BrandCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(
                                "Some teams use a headset or a wall screen for nature-led calm, with you right beside the person. In a real setting, consent, policy, and infection control come first — this is just the rehearsal."
                            )
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            iotToggle(
                                "VR / headset path (when your kit supports it)",
                                isOn: $state.carePrepVRImmersiveRoute
                            )
                            iotToggle(
                                "Also show on wall, TV, or bedside screen",
                                isOn: $state.carePrepRoomDisplayMirroring
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rough length")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Picker("Minutes", selection: $state.carePlannedDurationMinutes) {
                            ForEach(durationChoices, id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Only a guide — stop whenever it feels right. Lights can ease down with the closing breath.")
                            .font(.caption2)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    Text("Wellness support only — not clinical advice or a medical device. Device names here are examples.")
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.textSecondary.opacity(0.9))
                        .padding(.horizontal, 4)

                    PrimaryButton(title: "Continue — photo or quick session") {
                        state.continueCareSessionFromPrep()
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
    }

    private func iotToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .tint(BrandTheme.goldDeep)
    }
}

// MARK: - Patient detail

struct CarePatientDetailView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum DetailTypography {
        static let name = Font.title.weight(.semibold)
        static let context = Font.title3
        static let section = Font.headline.weight(.semibold)
        static let body = Font.body
        static let secondary = Font.callout
        static let label = Font.subheadline.weight(.semibold)
        static let pill = Font.subheadline.weight(.medium)
    }

    private var portraitSize: CGFloat {
        BrandLayout.scaled(112, regular: 144, horizontalSizeClass: horizontalSizeClass)
    }

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.selectedCarePatientId)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to roster",
                onBack: {
                    state.selectedCarePatientId = nil
                    state.phase = .carePatientList
                },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 26) {
                    if let patient {
                        CarePatientPortraitView(
                            assetName: patient.stockPortraitAssetName,
                            customImage: state.portraitImage(for: patient.id),
                            remoteURL: patient.remotePortraitURL,
                            size: portraitSize
                        )
                        .shadow(color: BrandTheme.brown.opacity(0.12), radius: 10, y: 4)

                        VStack(spacing: 6) {
                            Text(patient.displayName)
                                .font(BrandTheme.orbTitleFont(.title))
                                .orbOverlayText()
                                .multilineTextAlignment(.center)
                            Text(patient.careContextLabel)
                                .font(BrandTheme.orbLineFont())
                                .orbOverlayText(muted: true)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        patientSentimentSummaryCard(patient)

                        genrePlaylistsCard(patient)

                        suggestedLikedSongsCard(patient)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Resident session (handoff)")
                                    .font(DetailTypography.section)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Stepper(value: Binding(
                                    get: { patient.residentAgeYears },
                                    set: { state.setResidentAge(for: patient.id, age: $0) }
                                ), in: 55 ... 105) {
                                    Text("Approx. age: \(patient.residentAgeYears)")
                                        .font(DetailTypography.body)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                }
                                ResidentNationalityMenuField(
                                    title: "Nationality",
                                    selection: Binding(
                                        get: { patient.nationality },
                                        set: { state.setResidentNationality(for: patient.id, nationality: $0) }
                                    ),
                                    caption: "Used with age when discovery reorders clips and genres."
                                )
                                Text("Suggested liked songs above seed playlist order; the resident can still sun-like or cloud-skip live.")
                                    .font(DetailTypography.secondary)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                PrimaryButton(title: "Open resident calm surface") {
                                    state.openResidentProfile()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Listening discovery")
                                    .font(DetailTypography.section)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text("Up to six calm clips (about 30 seconds each, unless they tap sooner). Tap the traffic-light faces (red unhappy → green happy) to match each sound — each tap completes that clip and starts the next. If they listen without tapping, we move on when the slice ends using a neutral default. When the pass ends, we reshuffle playlist genres/stubs from those picks, open their calm sandbox, and surface more instrument glyphs when discovery finds gaps.")
                                    .font(DetailTypography.secondary)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                SecondaryButton(title: "Start discovery pass") {
                                    state.startDiscoveryCalibration(for: patient.id)
                                }
                                if let line = discoveryRunSummary(for: patient.id, state: state) {
                                    Text(line)
                                        .font(DetailTypography.body.weight(.medium))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 6)
                                        .accessibilityLabel(line)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Comfort & senses")
                                    .font(DetailTypography.section)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text("Light")
                                    .font(DetailTypography.label)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text(patient.preferredLight)
                                    .font(DetailTypography.body)
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Text("Scent")
                                    .font(DetailTypography.label)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .padding(.top, 4)
                                Text(patient.scentGuidance)
                                    .font(DetailTypography.body)
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Text("Touch")
                                    .font(DetailTypography.label)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .padding(.top, 4)
                                Text(patient.touchComfortNotes)
                                    .font(DetailTypography.body)
                                    .foregroundStyle(BrandTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("For next time")
                                    .font(DetailTypography.section)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                meterRow("Tempo — gentler ↔ slightly brighter", value: patient.musicTempoBias)
                                meterRow("Nature ↔ abstract", value: patient.natureVsAbstract)
                                meterRow("Instrumental ↔ voice", value: patient.voiceVsInstrumental)
                                Text("After you’re together, note how they responded — these sliders help the next visit land softly.")
                                    .font(DetailTypography.secondary)
                                    .foregroundStyle(BrandTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Previous sessions")
                                .font(DetailTypography.section)
                                .foregroundStyle(BrandTheme.textPrimary)
                                .padding(.horizontal, 4)

                            let rows = state.recordsForPatient(patient.id)
                            if rows.isEmpty {
                                Text("Nothing here yet.")
                                    .font(DetailTypography.body)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .padding(.horizontal, 8)
                            } else {
                                ForEach(rows) { rec in
                                    BrandCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(rec.date, style: .date)
                                                    .font(DetailTypography.label)
                                                    .foregroundStyle(BrandTheme.textSecondary)
                                                Spacer()
                                                Text("\(rec.calmPercent)% calm")
                                                    .font(DetailTypography.body.weight(.medium))
                                                    .foregroundStyle(BrandTheme.goldDeep)
                                            }
                                            Text("Mood tags: \(rec.moodSummary)")
                                                .font(DetailTypography.body)
                                                .foregroundStyle(BrandTheme.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                            if let line = outcomeLine(rec) {
                                                Text(line)
                                                    .font(DetailTypography.secondary)
                                                    .foregroundStyle(BrandTheme.textSecondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            if let insight = rec.insightPreviewLine() {
                                                Text(insight)
                                                    .font(DetailTypography.body)
                                                    .foregroundStyle(BrandTheme.textPrimary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            if let next = rec.insightSuggestedNextStep {
                                                Text("Next: \(next)")
                                                    .font(DetailTypography.secondary)
                                                    .foregroundStyle(BrandTheme.goldDeep)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            if let context = rec.sessionContextSummary, !context.isEmpty {
                                                Text(context)
                                                    .font(DetailTypography.secondary)
                                                    .foregroundStyle(BrandTheme.textSecondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            if let note = rec.staffNote, !note.isEmpty {
                                                Text(note)
                                                    .font(DetailTypography.secondary)
                                                    .foregroundStyle(BrandTheme.textSecondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        PrimaryButton(title: "Lights, headset & timing") {
                            state.openCareSessionPrep()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    } else {
                        FadeInLine(text: "No one’s selected.", delay: 0)
                    }
                }
                .padding(.vertical, 28)
            }
        }
    }

    private func discoveryRunSummary(for patientId: UUID, state: SessionPOCState) -> String? {
        guard state.selectedCarePatientId == patientId else { return nil }
        guard state.discoveryResults.count == DiscoveryFlowPOC.snippetCount else { return nil }
        let unpleasant = state.discoveryResults.filter { $0.sentiment == .unpleasant }.count
        let neutral = state.discoveryResults.filter { $0.sentiment == .neutral }.count
        let pleasant = state.discoveryResults.filter { $0.sentiment == .pleasant }.count
        return "Last pass: red (uncomfortable) \(unpleasant), amber (unsure) \(neutral), green (comforting) \(pleasant)."
    }

    private func patientSentimentSummaryCard(_ patient: CarePatientProfile) -> some View {
        let summary = state.sentimentSummary(for: patient.id)
        return Group {
            if summary.hasData {
                BrandCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Supervisor sentiment (recent sessions)")
                            .font(DetailTypography.section)
                            .foregroundStyle(BrandTheme.textSecondary)
                        Text("Rolling averages from post-session carer observations (1–10) — mood/affect, alertness, emotional presentation, and orientation.")
                            .font(DetailTypography.secondary)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let line = summary.formattedAveragesLine() {
                            Text(line)
                                .font(DetailTypography.body.weight(.medium))
                                .foregroundStyle(BrandTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("Based on \(summary.sessionCount) rated session\(summary.sessionCount == 1 ? "" : "s")")
                            .font(DetailTypography.secondary)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func orderedPlaylistGroups(_ patient: CarePatientProfile) -> [CareGenrePlaylistGroup] {
        patient.genrePlaylistGroups.sorted { $0.genre.rawValue < $1.genre.rawValue }
    }

    private func genrePlaylistsCard(_ patient: CarePatientProfile) -> some View {
        let groups = orderedPlaylistGroups(patient)
        return BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Playlists on file (by genre)")
                    .font(DetailTypography.section)
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("These appear as floating instruments for the resident — staff does not change them here.")
                    .font(DetailTypography.secondary)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider().opacity(0.35)
                    }
                    genrePlaylistSection(group: group)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    /// Supervisor-seeded likes that boost track order on the resident calm surface.
    private func suggestedLikedSongsCard(_ patient: CarePatientProfile) -> some View {
        let selected = patient.suggestedLikedTrackTitles
        let available = ResidentPlaybackTrackCatalog.allUniqueTitles.filter { !selected.contains($0) }

        return BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Suggested liked songs")
                    .font(DetailTypography.section)
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("Add tracks family or staff know they enjoy. These float earlier when a playlist starts — live sun taps still raise weight further.")
                    .font(DetailTypography.secondary)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if selected.isEmpty {
                    Text("None yet — add a song below.")
                        .font(DetailTypography.secondary)
                        .foregroundStyle(BrandTheme.textTertiary)
                } else {
                    FlowLayoutChipWrap {
                        ForEach(selected, id: \.self) { title in
                            Button {
                                state.removeSuggestedLikedTrack(for: patient.id, title: title)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2.weight(.semibold))
                                    Text(title)
                                        .font(DetailTypography.pill)
                                        .lineLimit(1)
                                    Image(systemName: "xmark")
                                        .font(.caption2.weight(.bold))
                                        .opacity(0.75)
                                }
                                .foregroundStyle(BrandTheme.textOnOrb)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    BrandTheme.nebulaPink.opacity(0.88),
                                                    BrandTheme.nebulaPurple.opacity(0.82),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                            }
                            .buttonStyle(ChimingPlainButtonStyle())
                            .accessibilityLabel("Remove \(title) from suggested liked songs")
                        }
                    }
                }

                Menu {
                    if available.isEmpty {
                        Text("All catalog songs are already suggested")
                    } else {
                        ForEach(available, id: \.self) { title in
                            Button {
                                state.addSuggestedLikedTrack(for: patient.id, title: title)
                            } label: {
                                let genres = ResidentPlaybackTrackCatalog.genres(containing: title)
                                    .map(\.accessibilityLabel)
                                    .joined(separator: " · ")
                                Text("\(title)\(genres.isEmpty ? "" : "  (\(genres))")")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(BrandTheme.gold)
                        Text(available.isEmpty ? "All songs added" : "Add suggested song")
                            .font(DetailTypography.body.weight(.medium))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.goldDeep.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandTheme.creamMid.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                    )
                }
                .disabled(available.isEmpty)
                .accessibilityLabel("Add suggested liked song")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func genrePlaylistSection(group: CareGenrePlaylistGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: group.genre.iconName)
                    .font(.title2)
                    .foregroundStyle(group.genre.accent)
                Text(group.genre.accessibilityLabel)
                    .font(DetailTypography.section)
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer(minLength: 0)
            }
            ForEach(group.playlists) { pl in
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "music.note.list")
                        .font(DetailTypography.body)
                        .foregroundStyle(BrandTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pl.title)
                            .font(DetailTypography.body.weight(.medium))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Text("\(pl.trackTitles.count) tracks in player · about \(pl.durationMinutes) min")
                            .font(DetailTypography.secondary)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func meterRow(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(DetailTypography.body)
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(DetailTypography.body.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BrandTheme.brown.opacity(0.1))
                    Capsule()
                        .fill(BrandTheme.gold.opacity(0.85))
                        .frame(width: max(4, g.size.width * CGFloat(value)))
                }
            }
            .frame(height: 8)
        }
    }

    private func outcomeLine(_ rec: CareSessionRecord) -> String? {
        var parts: [String] = []
        if let line = rec.residentInteractionSummaryLine() { parts.append(line) }
        if let line = sentimentLine(rec) { parts.append(line) }
        if rec.settledness != nil || rec.engagement != nil || rec.comfortTolerance != nil {
            if let s = rec.settledness { parts.append("Settled \(s)%") }
            if let e = rec.engagement { parts.append("Engaged \(e)%") }
            if let c = rec.comfortTolerance { parts.append("Comfort \(c)%") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func sentimentLine(_ rec: CareSessionRecord) -> String? {
        var parts: [String] = []
        if let v = rec.moodRating { parts.append("Mood/affect \(v)/10") }
        if let v = rec.alertnessRating { parts.append("Alertness \(v)/10") }
        if let v = rec.emotionalStateRating { parts.append("Emotional presentation \(v)/10") }
        if let v = rec.lucidityRating { parts.append("Orientation \(v)/10") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Sequential post-session sentiment (existing residents)

struct CareSessionSentimentFeedbackView: View {
    @ObservedObject var state: SessionPOCState
    @State private var autoAdvanceToken = 0

    private static let autoAdvanceDelay: TimeInterval = 0.42

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.activeCarePatientId ?? state.selectedCarePatientId)
    }

    private var currentStep: CareSessionSentimentStep {
        CareSessionSentimentStep(rawValue: state.sessionSentimentStep) ?? .mood
    }

    private var isLastStep: Bool {
        state.sessionSentimentStep >= CareSessionSentimentStep.allCases.count - 1
    }

    private var currentSelection: Int? {
        switch currentStep {
        case .mood: return state.sessionSentimentDraft.mood
        case .alertness: return state.sessionSentimentDraft.alertness
        case .emotionalState: return state.sessionSentimentDraft.emotionalState
        case .lucidity: return state.sessionSentimentDraft.lucidity
        }
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: backLabel,
                onBack: handleBack,
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 24) {
                    if let patient {
                        FadeInTitle(text: "Post-session observation", delay: 0)
                        FadeInLine(
                            text: "Structured carer observations after \(patient.displayName)'s reminiscence music session — not a clinical assessment.",
                            delay: 0.06
                        )

                        if let metricsLine = state.residentSurfaceMetrics.interactionSummary() {
                            BrandCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Session captured automatically")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BrandTheme.textSecondary)
                                    Text(metricsLine)
                                        .font(.body)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 4)
                        }

                        SessionContextCaptureCard(context: $state.sessionContextDraft)
                            .padding(.horizontal, 4)

                        stepProgress

                        BrandCard {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Step \(state.sessionSentimentStep + 1) of \(CareSessionSentimentStep.allCases.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text(currentStep.title)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Text(currentStep.prompt)
                                    .font(.body)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                SentimentScalePicker(
                                    selection: state.sessionSentimentBinding(for: currentStep),
                                    lowCaption: currentStep.lowCaption,
                                    highCaption: currentStep.highCaption,
                                    onValueSelected: { _ in
                                        scheduleAutoAdvanceIfNeeded()
                                    }
                                )

                                if isLastStep {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Optional note")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrandTheme.textSecondary)
                                        TextField("Anything else to remember?", text: $state.sessionSentimentDraft.note, axis: .vertical)
                                            .lineLimit(1 ... 4)
                                            .font(.body)
                                            .foregroundStyle(BrandTheme.textPrimary)
                                            .padding(12)
                                            .background(BrandTheme.creamMid.opacity(0.95))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(BrandTheme.gold.opacity(0.25), lineWidth: 1)
                                            )
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(state.sessionSentimentStep)
                            .transition(.etherealAppear)
                        }
                        .padding(.horizontal, 4)
                        .animation(CalmMotion.gentle, value: state.sessionSentimentStep)
                        .onChange(of: state.sessionSentimentStep) { _, _ in
                            autoAdvanceToken += 1
                        }

                        PrimaryButton(title: isLastStep ? "Save to profile" : "Next") {
                            if isLastStep {
                                state.saveSessionSentimentFeedback()
                                CalmExperienceFeedback.signInSuccess()
                            } else {
                                state.advanceSessionSentimentStep()
                            }
                        }
                        .disabled(currentSelection == nil)
                        .opacity(currentSelection == nil ? 0.45 : 1)
                        .animation(CalmMotion.subtle, value: currentSelection)
                        .padding(.horizontal, 24)

                        SecondaryButton(title: "Skip for now") {
                            state.skipSessionSentimentFeedback()
                        }
                        .padding(.horizontal, 24)
                    } else {
                        FadeInLine(text: "No resident linked to this session.", delay: 0)
                    }
                }
                .padding(.vertical, 28)
            }
        }
    }

    private var stepProgress: some View {
        HStack(spacing: 8) {
            ForEach(CareSessionSentimentStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= state.sessionSentimentStep ? BrandTheme.gold : BrandTheme.brown.opacity(0.12))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 4)
        .animation(CalmMotion.subtle, value: state.sessionSentimentStep)
        .accessibilityLabel("Step \(state.sessionSentimentStep + 1) of \(CareSessionSentimentStep.allCases.count)")
    }

    private var backLabel: String {
        state.sessionSentimentStep > 0 ? "Previous question" : "Skip feedback"
    }

    private func handleBack() {
        autoAdvanceToken += 1
        if state.sessionSentimentStep > 0 {
            state.retreatSessionSentimentStep()
        } else {
            state.skipSessionSentimentFeedback()
        }
    }

    private func scheduleAutoAdvanceIfNeeded() {
        let step = state.sessionSentimentStep
        guard step < CareSessionSentimentStep.allCases.count - 1 else { return }
        autoAdvanceToken += 1
        let token = autoAdvanceToken
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoAdvanceDelay) {
            guard token == autoAdvanceToken, state.sessionSentimentStep == step else { return }
            state.advanceSessionSentimentStep()
        }
    }
}

struct SentimentScalePicker: View {
    @Binding var selection: Int?
    let lowCaption: String
    let highCaption: String
    var onValueSelected: ((Int) -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1 ... 10, id: \.self) { value in
                    let isSelected = selection == value
                    Button {
                        selection = value
                        CalmExperienceFeedback.discoveryPick()
                        onValueSelected?(value)
                    } label: {
                        Text("\(value)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(isSelected ? BrandTheme.textPrimary : BrandTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? BrandTheme.goldSoft.opacity(0.55) : BrandTheme.creamMid.opacity(0.95))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? BrandTheme.gold.opacity(0.55) : BrandTheme.gold.opacity(0.2), lineWidth: 1)
                            )
                            .scaleEffect(isSelected ? 1.06 : 1)
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityLabel("\(value) out of 10")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .animation(CalmMotion.gentle, value: selection)

            HStack {
                Text(lowCaption)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
                Spacer(minLength: 8)
                Text(highCaption)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Post-session feedback & tuning

struct CareSessionFeedbackView: View {
    @ObservedObject var state: SessionPOCState
    @State private var settled: Double = 0.6
    @State private var engagement: Double = 0.55
    @State private var comfort: Double = 0.7
    @State private var tempo: Double = 0.5
    @State private var nature: Double = 0.5
    @State private var voice: Double = 0.5
    @State private var staffNote = ""

    private var targetPatient: CarePatientProfile? {
        state.carePatient(id: state.activeCarePatientId ?? state.selectedCarePatientId)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to session summary",
                onBack: { state.phase = .insight },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    if let patient = targetPatient {
                        FadeInLine(
                            text: "How did \(patient.displayName) seem? This isn’t a grade for you — it nudges the sound for next time.",
                            font: BrandTheme.orbHintFont(),
                            muted: true,
                            delay: 0.08
                        )

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("In the moment")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                outcomeSlider(
                                    title: "Seemed settled",
                                    caption: "Still unsettled  ←  →  More at ease",
                                    value: $settled
                                )
                                outcomeSlider(
                                    title: "With you",
                                    caption: "Withdrawn  ←  →  Present / connected",
                                    value: $engagement
                                )
                                outcomeSlider(
                                    title: "Comfort in the room",
                                    caption: "Struggling  ←  →  Comfortable throughout",
                                    value: $comfort
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        Text("Sound for next time")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        tuningSlider(title: "Tempo — gentler ↔ slightly brighter", value: $tempo)
                        tuningSlider(title: "Nature ↔ abstract", value: $nature)
                        tuningSlider(title: "Instrumental ↔ voice", value: $voice)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your note (optional)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.textSecondary)
                            TextField("What helped — light, touch, sound? What would you soften next time?", text: $staffNote, axis: .vertical)
                                .lineLimit(1 ... 10)
                                .font(.body)
                                .foregroundStyle(BrandTheme.textPrimary)
                                .padding(12)
                                .background(BrandTheme.creamMid.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(BrandTheme.gold.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 4)

                        PrimaryButton(title: "Save note & sound tweaks") {
                            state.saveCareFeedback(
                                tempoBias: tempo,
                                natureVsAbstract: nature,
                                voiceVsInstrumental: voice,
                                settledness: Int((settled * 100).rounded()),
                                engagement: Int((engagement * 100).rounded()),
                                comfortTolerance: Int((comfort * 100).rounded()),
                                staffNote: staffNote
                            )
                        }
                        .padding(.horizontal, 24)

                        SecondaryButton(title: "Skip — keep session only") {
                            state.skipCareFeedback()
                        }
                        .padding(.horizontal, 24)
                    } else {
                        FadeInLine(text: "Pick someone from the list to save a note.", delay: 0)
                    }
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            staffNote = ""
            syncFromPatient()
            settled = 0.55
            engagement = 0.55
            comfort = 0.65
        }
    }

    private func syncFromPatient() {
        guard let patient = targetPatient else { return }
        tempo = patient.musicTempoBias
        nature = patient.natureVsAbstract
        voice = patient.voiceVsInstrumental
    }

    private func outcomeSlider(title: String, caption: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(BrandTheme.textSecondary)
            Slider(value: value, in: 0 ... 1)
                .tint(BrandTheme.goldDeep)
        }
    }

    private func tuningSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            Slider(value: value, in: 0 ... 1)
                .tint(BrandTheme.goldDeep)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Session context capture (UK care-floor tags)

private struct SessionContextCaptureCard: View {
    @Binding var context: SessionContextDraft

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session context")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("Quick tags for nursing handover and care plan documentation — optional but valuable.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                contextChipRow(title: "Time of day", items: SessionTimeOfDay.allCases) { item in
                    context.timeOfDay = item
                } selection: { context.timeOfDay == $0 }

                contextChipRow(title: "Pre-session presentation", items: SessionPriorState.allCases) { item in
                    context.priorState = context.priorState == item ? nil : item
                } selection: { context.priorState == $0 }

                environmentTagsRow

                Toggle(isOn: $context.residentLedSession) {
                    Text("Resident chose the music")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textPrimary)
                }
                .tint(BrandTheme.goldDeep)

                Toggle(isOn: $context.distressOrPRNNearby) {
                    Text("Acute distress or PRN (as-required) medication nearby")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textPrimary)
                }
                .tint(BrandTheme.goldDeep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var environmentTagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environment")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            FlowLayoutChipWrap {
                ForEach(SessionEnvironmentTag.allCases) { tag in
                    let selected = context.environmentTags.contains(tag)
                    Button {
                        if selected {
                            context.environmentTags.remove(tag)
                        } else {
                            context.environmentTags.insert(tag)
                        }
                    } label: {
                        Text(tag.label)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selected ? BrandTheme.goldDeep.opacity(0.22) : BrandTheme.creamMid.opacity(0.9))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selected ? BrandTheme.goldDeep.opacity(0.55) : BrandTheme.gold.opacity(0.22), lineWidth: 1)
                            )
                            .foregroundStyle(BrandTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func contextChipRow<T: Identifiable & Equatable>(
        title: String,
        items: [T],
        onSelect: @escaping (T) -> Void,
        selection: @escaping (T) -> Bool
    ) -> some View where T: Hashable {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            FlowLayoutChipWrap {
                ForEach(items) { item in
                    let selected = selection(item)
                    Button {
                        onSelect(item)
                    } label: {
                        Text(chipLabel(for: item))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selected ? BrandTheme.logoCyan.opacity(0.22) : BrandTheme.creamMid.opacity(0.9))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selected ? BrandTheme.logoCyan.opacity(0.55) : BrandTheme.gold.opacity(0.22), lineWidth: 1)
                            )
                            .foregroundStyle(BrandTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chipLabel<T>(for item: T) -> String {
        if let time = item as? SessionTimeOfDay { return time.label }
        if let state = item as? SessionPriorState { return state.label }
        return "—"
    }
}

/// Simple wrapping chip row for context pickers.
private struct FlowLayoutChipWrap<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 108), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            content()
        }
    }
}

// MARK: - Post-session insight pack (handover + family export)

struct CareSessionInsightView: View {
    @ObservedObject var state: SessionPOCState
    @State private var copiedBanner: String?

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.activeCarePatientId ?? state.selectedCarePatientId)
    }

    private var pack: CareSessionInsightPack? {
        state.pendingSessionInsight
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to roster",
                onBack: { state.completeSessionInsightReview() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    if let patient, let pack {
                        FadeInTitle(text: "Session insight", delay: 0)
                        FadeInLine(
                            text: "Structured for nursing handover, care plan review, or family communication — generated from this session and \(patient.displayName)'s history. Carer-observed data only.",
                            delay: 0.06
                        )

                        insightCard(title: "Clinical narrative", body: pack.narrative)

                        if !pack.deltaLines.isEmpty {
                            insightCard(
                                title: "Compared to recent sessions",
                                body: pack.deltaLines.joined(separator: "\n")
                            )
                        }

                        insightCard(title: "Suggested care plan action", body: pack.suggestedNextStep, accent: true)

                        insightCard(title: "Care plan entry", body: pack.carePlanBullet)

                        insightCard(title: "Nursing handover record", body: pack.handoverText, monospaced: true)

                        insightCard(title: "Family communication", body: pack.familyText)

                        VStack(spacing: 12) {
                            PrimaryButton(title: "Copy nursing handover") {
                                copy(pack.handoverText, label: "Handover copied")
                            }
                            SecondaryButton(title: "Copy family update") {
                                copy(pack.familyText, label: "Family update copied")
                            }
                            SecondaryButton(title: "Copy care plan entry") {
                                copy(pack.carePlanBullet, label: "Care plan entry copied")
                            }
                        }
                        .padding(.horizontal, 24)

                        PrimaryButton(title: "Done — back to roster") {
                            state.completeSessionInsightReview()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                        if let copiedBanner {
                            Text(copiedBanner)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.goldDeep)
                                .transition(.opacity)
                        }
                    } else {
                        FadeInLine(text: "No insight available for this session.", delay: 0)
                        PrimaryButton(title: "Back to roster") {
                            state.completeSessionInsightReview()
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 28)
            }
        }
    }

    private func insightCard(
        title: String,
        body: String,
        accent: Bool = false,
        monospaced: Bool = false
    ) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text(body)
                    .font(monospaced ? .caption.monospaced() : .body)
                    .foregroundStyle(accent ? BrandTheme.goldDeep : BrandTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func copy(_ text: String, label: String) {
        UIPasteboard.general.string = text
        withAnimation(CalmMotion.subtle) {
            copiedBanner = label
        }
    }
}
