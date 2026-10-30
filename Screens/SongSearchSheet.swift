import SwiftUI

/// Staff/family song search over the backend catalogue (iTunes previews). iPad-first: a medium
/// sheet with a search field, results that play a 30-second preview, and an Add button that files
/// the song as a suggested like and into the resident's playlist for its genre.
struct SongSearchSheet: View {
    @ObservedObject var state: SessionPOCState
    let patient: CarePatientProfile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preview = AmbientAudioSession()
    @State private var query = ""
    @State private var results: [ResidentTrackRef] = []
    @State private var isSearching = false
    @State private var errorLine: String?
    @State private var playingId: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    private var alreadyAdded: Set<String> {
        Set(patient.suggestedLikedTrackIds?.values.map { $0 } ?? [])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(BrandTheme.textSecondary)
                    TextField("Song or artist", text: $query, prompt: BrandTheme.fieldPrompt("Try “Vera Lynn” or “Moonlight Serenade”"))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($fieldFocused)
                        .accessibilityIdentifier("search.query")
                        .onSubmit { runSearch(immediate: true) }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BrandTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .frame(minHeight: 48)
                .background(BrandTheme.creamMid.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1))
                .padding(.horizontal, 20)

                if let errorLine {
                    BrandMessageTile(text: errorLine)
                        .padding(.horizontal, 20)
                }

                if isSearching && results.isEmpty {
                    ProgressView("Searching…")
                        .tint(BrandTheme.gold)
                        .padding(.top, 24)
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Text(query.count < 2 ? "Search the songs of their youth." : "Nothing found — try the artist’s name.")
                            .font(.callout)
                            .foregroundStyle(BrandTheme.textSecondary)
                        Text("Previews are 30 seconds from Apple Music; the full song opens in the store.")
                            .font(.footnote)
                            .foregroundStyle(BrandTheme.textTertiary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                } else {
                    List(results) { ref in
                        row(ref)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(BrandTheme.gold.opacity(0.2))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .background(BrandTheme.cream.ignoresSafeArea())
            .navigationTitle("Find a song for \(firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Done")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("search.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in runSearch(immediate: false) }
        .onDisappear {
            searchTask?.cancel()
            preview.stop()
        }
    }

    private var firstName: String {
        String(patient.displayName.split(separator: " ").first ?? Substring(patient.displayName))
    }

    @ViewBuilder
    private func row(_ ref: ResidentTrackRef) -> some View {
        let added = alreadyAdded.contains(ref.id)
        HStack(spacing: 12) {
            Button {
                togglePreview(ref)
            } label: {
                // Apple cover art (from the catalogue) with the transport glyph over it; the
                // genre glyph stands in while it loads or when a track has none.
                ZStack {
                    TrackArtworkView(ref: ref, size: 56)
                    Circle().fill(Color.black.opacity(0.42)).frame(width: 30, height: 30)
                    Image(systemName: playingId == ref.id ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: playingId == ref.id ? 0 : 1)
                }
            }
            .buttonStyle(ChimingPlainButtonStyle())
            .accessibilityLabel(playingId == ref.id ? "Pause preview of \(ref.title)" : "Play preview of \(ref.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(ref.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text([ref.artist, ref.eraYear.map(String.init), ref.genre.accessibilityLabel].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .lineLimit(1)
                }
                if let link = ref.trackViewURL {
                    Link(destination: link) {
                        Label("Preview · Apple Music", systemImage: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.goldDeep.opacity(0.9))
                            .expandedHitArea(vertical: 9)   // a 26 pt line with a 44 pt target
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(ref.title) in Apple Music")
                }
            }
            Spacer(minLength: 8)
            Button(added ? "Added" : "Add") {
                CalmExperienceFeedback.buttonPress()
                state.addSuggestedLikedTrack(for: patient.id, ref: ref)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(added ? BrandTheme.textSecondary : BrandTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(added ? BrandTheme.surfaceInset : BrandTheme.logoCyan.opacity(0.22)))
            .overlay(Capsule().stroke(added ? BrandTheme.insetBorder : BrandTheme.logoCyan.opacity(0.6), lineWidth: 1))
            .expandedHitArea(vertical: 6, horizontal: 4)
            .disabled(added)
            .accessibilityIdentifier("search.add.\(ref.id)")
            .accessibilityLabel(added ? "\(ref.title) already added" : "Add \(ref.title) to suggested liked songs")
        }
        .padding(.vertical, 6)
    }

    private func runSearch(immediate: Bool) {
        searchTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        searchTask = Task { @MainActor in
            if !immediate { try? await Task.sleep(nanoseconds: 400_000_000) }
            guard !Task.isCancelled else { return }
            isSearching = true
            errorLine = nil
            do {
                let found = try await MusicCatalogClient.search(query: term, limit: 25)
                guard !Task.isCancelled else { return }
                results = found
            } catch let error as APIError {
                errorLine = error.userMessage
            } catch {
                errorLine = "Search failed. Try again."
            }
            isSearching = false
        }
    }

    private func togglePreview(_ ref: ResidentTrackRef) {
        if playingId == ref.id {
            preview.stop()
            playingId = nil
            return
        }
        playingId = ref.id
        preview.loops = false
        preview.onItemEnd = { if playingId == ref.id { playingId = nil } }
        preview.onFailure = {
            if playingId == ref.id { playingId = nil }
            errorLine = "That preview isn’t available right now."
        }
        preview.logTitle = ref.title
        preview.volumeMultiplier = 1.4
        preview.startFresh(streamURL: ref.audioURL, fallbackURL: nil)
    }
}
