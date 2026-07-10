import SwiftUI

// MARK: - Resident session: genre glyphs play immediately → idle & playing layouts span the playable hull

private enum GlyphFloatLayout {
    private struct Metrics {
        let glyphRadius: CGFloat
        let restingEdgeSeparation: CGFloat
        let topInset: CGFloat
        let bottomInset: CGFloat
        let motionCap: CGFloat

        static func forSize(_ size: CGSize) -> Metrics {
            let scale = BrandLayout.hullScale(for: size)
            return Metrics(
                glyphRadius: 46 * scale,
                restingEdgeSeparation: 54 * scale,
                topInset: 52 * scale,
                bottomInset: 88 * scale,
                motionCap: 19 * scale
            )
        }
    }

    /// Backing radius for constellation math — use `Metrics.forSize` when layout depends on canvas size.
    static let glyphRadius: CGFloat = 46

    private static func minCenterDistance(metrics: Metrics, resting: Bool = true) -> CGFloat {
        2 * metrics.glyphRadius + (resting ? metrics.restingEdgeSeparation : 20)
    }

    /// Playscreen inset — kept fairly tight so **idle** constellation can use nearly the whole view (staff FAB overlays top-trailing).
    private static func playableRect(in size: CGSize, metrics: Metrics) -> CGRect {
        let padX = max(BrandTheme.contentGutter, 18)
        let side = metrics.glyphRadius + 10 + padX
        return CGRect(
            x: side,
            y: metrics.topInset,
            width: max(120, size.width - side * 2),
            height: max(220, size.height - metrics.topInset - metrics.bottomInset)
        )
    }

    /// Evenly spaced on an ellipse inside `playable`, with pairwise separation guarded by relaxation.
    static func constellation(count: Int, in size: CGSize) -> (centers: [CGPoint], hub: CGPoint) {
        let metrics = Metrics.forSize(size)
        guard count > 0 else { return ([], .zero) }
        let playable = playableRect(in: size, metrics: metrics)
        let hub = CGPoint(x: playable.midX, y: playable.midY)
        switch count {
        case 1:
            return ([hub], hub)
        default:
            let minD = minCenterDistance(metrics: metrics)
            let sinHalfChord = CGFloat(sin(Double.pi / Double(count)))
            let maxEllipseX = playable.width / 2 - metrics.glyphRadius - 8
            let maxEllipseY = playable.height / 2 - metrics.glyphRadius - 10
            // Chord-derived radius prefers non-overlap on a perfect ring; blending with hull scale spreads glyphs edge-to-edge.
            let radiusChord = CGFloat(minD * 1.06) / (2 * max(sinHalfChord, CGFloat(1e-3)))
            var rx = min(maxEllipseX * 0.995, radiusChord * 1.48)
            var ry = min(maxEllipseY * 0.99, radiusChord * CGFloat(1.32))
            rx = max(rx, maxEllipseX * 0.84)
            ry = max(min(ry, maxEllipseY), maxEllipseY * 0.8)

            var pts = ellipsePoints(count: count, hub: hub, rx: rx, ry: ry)
            pts = pts.map { clampToPlayable($0, playable: playable, glyphR: metrics.glyphRadius) }
            pts = relaxCenters(pts, playable: playable, minDist: minD * 1.03, iterations: 24, clampRadius: metrics.glyphRadius)

            let spread = pairwiseMinSpacing(pts)
            if spread < minD * 1.015, count >= 2 {
                let scale: CGFloat = 1.128
                let rx2 = min(maxEllipseX * 0.999, rx * scale)
                let ry2 = min(maxEllipseY * 0.99, ry * scale)
                var pts2 = ellipsePoints(count: count, hub: hub, rx: rx2, ry: ry2)
                pts2 = pts2.map { clampToPlayable($0, playable: playable, glyphR: metrics.glyphRadius) }
                pts = relaxCenters(pts2, playable: playable, minDist: minD * 1.03, iterations: 22, clampRadius: metrics.glyphRadius)
            }
            return (pts, hub)
        }
    }

    private static func pairwiseMinSpacing(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count >= 2 else { return CGFloat.greatestFiniteMagnitude }
        var m = CGFloat.greatestFiniteMagnitude
        for i in pts.indices {
            for j in (i &+ 1) ..< pts.count {
                m = min(m, hypot(pts[j].x - pts[i].x, pts[j].y - pts[i].y))
            }
        }
        return m
    }

    private static func ellipsePoints(count: Int, hub: CGPoint, rx: CGFloat, ry: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        let start = -CGFloat.pi / 2 + 0.16
        return (0..<count).map { i in
            let θ = start + CGFloat(i) * (2 * .pi / CGFloat(count))
            return CGPoint(x: hub.x + cos(θ) * rx, y: hub.y + sin(θ) * ry)
        }
    }

    private static func clampToPlayable(_ p: CGPoint, playable: CGRect, glyphR: CGFloat) -> CGPoint {
        let edge: CGFloat = 4
        return CGPoint(
            x: min(max(playable.minX + glyphR + edge, p.x), playable.maxX - glyphR - edge),
            y: min(max(playable.minY + glyphR + edge, p.y), playable.maxY - glyphR - edge)
        )
    }

    private static func clampToPlayable(_ p: CGPoint, playable: CGRect) -> CGPoint {
        clampToPlayable(p, playable: playable, glyphR: glyphRadius)
    }

    /// Push overlaps apart gently while respecting the playable hull.
    private static func relaxCenters(
        _ pts: [CGPoint],
        playable: CGRect,
        minDist: CGFloat,
        iterations: Int,
        clampRadius: CGFloat = glyphRadius
    ) -> [CGPoint] {
        var p = pts
        guard p.count >= 2 else { return p }
        for _ in 0 ..< iterations {
            for i in p.indices {
                var ax: CGFloat = 0
                var ay: CGFloat = 0
                for j in p.indices where j != i {
                    let dx = p[i].x - p[j].x
                    let dy = p[i].y - p[j].y
                    let dist = hypot(dx, dy)
                    guard dist > 0.001, dist < minDist else { continue }
                    let push = (minDist - dist) / dist * 0.42
                    ax += dx * push
                    ay += dy * push
                }
                p[i].x += ax
                p[i].y += ay
                p[i] = clampToPlayable(p[i], playable: playable, glyphR: clampRadius)
            }
        }
        return p
    }

    /// Multi-layer motion that keeps typical displacement modest so relaxation margins hold.
    static func animatedDelta(index: Int, base: CGPoint, hub: CGPoint, phase: TimeInterval, in size: CGSize) -> CGSize {
        let metrics = Metrics.forSize(size)
        let hullScale = BrandLayout.hullScale(for: size)
        let ω1 = 0.19 + Double(index % 7) * 0.063
        let ω2 = 0.247 + Double((index ^ 5) % 9) * 0.058
        let ω3 = 0.089 + Double((index + 2) % 11) * 0.031

        let drift = CGSize(
            width: CGFloat(sin(phase * 0.049 + Double(index % 13) + 2.08) * 11 * hullScale),
            height: CGFloat(cos(phase * 0.043 + Double(index % 17) + 1.71) * 9.5 * hullScale)
        )

        let vx = base.x - hub.x
        let vy = base.y - hub.y
        let len = hypot(vx, vy)
        let tx = len > 0.5 ? -vy / len : 0
        let ty = len > 0.5 ? vx / len : 1

        let tangentialCarrier =
            sin(phase * ω3 + Double(index))
            + 0.34 * cos(phase * ω3 * 1.618 + Double(index + 9))
            + 0.26 * sin(phase * (ω3 + 0.067) + Double(index))

        let tangentialAmp = CGFloat(tangentialCarrier * Double(7 + index % 3))

        let normCarrier = CGFloat(0.42 * cos(phase * ω2 + Double(index)))
        let alongX = len > 0.5 ? vx / len : 1
        let alongY = len > 0.5 ? vy / len : 0

        let ripple = CGSize(
            width: CGFloat(sin(phase * ω1 + Double(index))) * CGFloat(7 + CGFloat(index % 4)) * hullScale,
            height: CGFloat(cos(phase * ω2 + Double(index) * 0.93)) * CGFloat(7 + CGFloat((index >> 1) % 5)) * hullScale
        )

        let orbital = CGSize(
            width: (tx * tangentialAmp + alongX * normCarrier) * hullScale,
            height: (ty * tangentialAmp + alongY * normCarrier) * hullScale
        )

        var Δ = CGSize(
            width: drift.width + ripple.width + orbital.width,
            height: drift.height + ripple.height + orbital.height
        )
        Δ = clampMotionVector(Δ, maxLength: metrics.motionCap)
        return Δ
    }

    private static func clampMotionVector(_ Δ: CGSize, maxLength: CGFloat) -> CGSize {
        let length = hypot(Δ.width, Δ.height)
        guard length > maxLength, length > 0.001 else { return Δ }
        let s = maxLength / length
        return CGSize(width: Δ.width * s, height: Δ.height * s)
    }

    /// Keeps a disk center ≥ `minRadius` from `hub` (clears centred hero occupancy).
    private static func ensureMinRadialDistanceFromHub(_ p: CGPoint, hub: CGPoint, minRadius: CGFloat) -> CGPoint {
        let dx = p.x - hub.x
        let dy = p.y - hub.y
        let d = hypot(dx, dy)
        guard d > 1e-3 else {
            return CGPoint(x: hub.x + minRadius, y: hub.y)
        }
        guard d < minRadius else { return p }
        let scale = minRadius / d
        return CGPoint(x: hub.x + dx * scale, y: hub.y + dy * scale)
    }

    static func rotationDynamics(index: Int, phase: TimeInterval) -> Double {
        sin(phase * 0.21 + Double(index) * 0.97) * 6.2
            + cos(phase * 0.33 + Double(index) * 0.63) * 4.1
            + sin(phase * 0.11 + Double(index) * 2.71) * 3.2
    }

    static func scalePulse(index: Int, phase: TimeInterval) -> CGFloat {
        CGFloat(1 + 0.028 * sin(phase * (0.24 + Double(index % 11) * 0.036) + Double(index)))
    }

    /// Center of the music-glyph playable area — same hull `constellation` uses.
    static func musicGlyphHub(in size: CGSize) -> CGPoint {
        constellation(count: 1, in: size).hub
    }

    /// While one genre occupies **`hub`** as hero, lays out the inactive picks on an **ellipse** through the playable hull —
    /// same spreading idea as idle `constellation`, but with pairwise spacing for the smaller periphery disks and a ring floor outside the hero.
    static func focusedInactivePeriphery(
        inactiveCount: Int,
        heroDiameter: CGFloat,
        hub: CGPoint,
        in size: CGSize
    ) -> [CGPoint] {
        guard inactiveCount > 0 else { return [] }
        let metrics = Metrics.forSize(size)
        let hullScale = BrandLayout.hullScale(for: size)
        let playable = playableRect(in: size, metrics: metrics)
        let inactiveR: CGFloat = 32 * hullScale
        let minPairSep = CGFloat(2 * inactiveR + metrics.restingEdgeSeparation * 0.94)
        let minOrbitRadius = CGFloat(heroDiameter * 0.5 + inactiveR + 54 * hullScale)

        if inactiveCount == 1 {
            var solo = CGPoint(
                x: playable.minX + inactiveR + 14 + playable.width * 0.08,
                y: playable.minY + inactiveR + 18 + playable.height * 0.16
            )
            solo = ensureMinRadialDistanceFromHub(solo, hub: hub, minRadius: minOrbitRadius)
            return [clampToPlayable(solo, playable: playable, glyphR: inactiveR)]
        }

        let sinHalfChord = CGFloat(sin(Double.pi / Double(inactiveCount)))
        let maxEllipseX = playable.width / 2 - inactiveR - 8
        let maxEllipseY = playable.height / 2 - inactiveR - 10
        let radiusChord = CGFloat(minPairSep * 1.06) / (2 * max(sinHalfChord, CGFloat(1e-3)))

        var rx = min(maxEllipseX * 0.995, radiusChord * 1.52)
        var ry = min(maxEllipseY * 0.99, radiusChord * CGFloat(1.36))
        rx = max(rx, maxEllipseX * 0.84)
        ry = max(ry, maxEllipseY * 0.8)
        rx = max(rx, min(minOrbitRadius * 1.06, maxEllipseX * 0.998))
        ry = max(ry, min(minOrbitRadius * CGFloat(1.02), maxEllipseY * 0.998))

        var pts = ellipsePoints(count: inactiveCount, hub: hub, rx: rx, ry: ry)
        pts = pts.map { ensureMinRadialDistanceFromHub($0, hub: hub, minRadius: minOrbitRadius) }
        pts = pts.map { clampToPlayable($0, playable: playable, glyphR: inactiveR) }
        pts = relaxCenters(pts, playable: playable, minDist: minPairSep * 1.03, iterations: 26, clampRadius: inactiveR)

        pts = pts.map { ensureMinRadialDistanceFromHub($0, hub: hub, minRadius: minOrbitRadius) }
        pts = pts.map { clampToPlayable($0, playable: playable, glyphR: inactiveR) }

        let spread = pairwiseMinSpacing(pts)
        if spread < minPairSep * 1.012, inactiveCount >= 2 {
            let scale: CGFloat = 1.14
            let rx2 = min(maxEllipseX * 0.999, rx * scale)
            let ry2 = min(maxEllipseY * 0.99, ry * scale)
            var pts2 = ellipsePoints(count: inactiveCount, hub: hub, rx: rx2, ry: ry2)
            pts2 = pts2.map { ensureMinRadialDistanceFromHub($0, hub: hub, minRadius: minOrbitRadius) }
            pts2 = pts2.map { clampToPlayable($0, playable: playable, glyphR: inactiveR) }
            pts = relaxCenters(pts2, playable: playable, minDist: minPairSep * 1.03, iterations: 22, clampRadius: inactiveR)

            pts = pts.map { ensureMinRadialDistanceFromHub($0, hub: hub, minRadius: minOrbitRadius) }
            pts = pts.map { clampToPlayable($0, playable: playable, glyphR: inactiveR) }
        }
        return pts
    }
}

/// Rest drift, hero bloom, or periphery positions when another genre’s playlist is audible.
private enum ResidentGlyphEmphasis {
    case idle
    case hero
    case sideStrip
}

struct ResidentProfileView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.flowContainerSize) private var flowContainerSize
    @Environment(\.flowOrbShellSize) private var flowOrbShellSize
    @StateObject private var residentAudio = AmbientAudioSession()
    /// Highlights the glyph whose playlist is sounding; reshapes the floating layout around it.
    @State private var selectedPlayingGenre: ResidentMusicGenre?
    @State private var activePlaylist: CarePlaylistEntry?
    @State private var activeTrackIndex: Int = 0
    @State private var activeAudioKey: String?
    @State private var comfortInvitePhase: PlaylistComfortInvitePhase = .hidden
    @State private var playbackAnchor: Date?
    @State private var lastPromptedPlaybackKey: String?
    @State private var comfortPromptCount = 0
    @State private var comfortDismissGeneration = 0
    @State private var comfortAffirmationChoice: ResidentPlaylistComfortChoice?
    @State private var comfortAffirmationTick: UInt = 0
    @State private var mediaExpansion: CGFloat = 0
    @State private var genreMediaCycleToken = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var comfortInviteActive: Bool { comfortInvitePhase == .visible }

    /// Size when playlist retro visuals fill the screen — a full-bleed rectangle (covers the page
    /// corners), with slight overscan so the subtle pulse never reveals an edge gap.
    private func expandedMediaSize(in container: CGSize) -> CGSize {
        CGSize(width: container.width * 1.12, height: container.height * 1.12)
    }

    private func displayMediaSize(in container: CGSize) -> CGSize {
        let compact = orbSize
        let expanded = expandedMediaSize(in: container)
        let t = mediaExpansion
        return CGSize(
            width: compact.width + (expanded.width - compact.width) * t,
            height: compact.height + (expanded.height - compact.height) * t
        )
    }

    private func displayMediaFillScale() -> CGFloat {
        0.90 + mediaExpansion * 0.10
    }

    private func mediaCenter(hub: CGPoint, in container: CGSize) -> CGPoint {
        let screenCenter = CGPoint(x: container.width * 0.5, y: container.height * 0.5)
        let t = mediaExpansion
        return CGPoint(
            x: hub.x + (screenCenter.x - hub.x) * t,
            y: hub.y + (screenCenter.y - hub.y) * t
        )
    }

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.selectedCarePatientId)
    }

    private var genresOnFile: [ResidentMusicGenre] {
        guard let patient else { return [] }
        let set = Set(patient.genrePlaylistGroups.map(\.genre))
        return ResidentMusicGenre.allCases.filter { set.contains($0) }
    }

    private var orbSize: CGSize {
        if flowOrbShellSize.width > 1, flowOrbShellSize.height > 1 {
            return flowOrbShellSize
        }
        return BrandLayout.discoveryPanelSize(in: flowContainerSize)
    }

    var body: some View {
        GeometryReader { geo in
            let playbackHub = GlyphFloatLayout.musicGlyphHub(in: geo.size)
            let mediaSize = displayMediaSize(in: geo.size)
            let mediaAnchor = mediaCenter(hub: playbackHub, in: geo.size)
            let phoneScale = BrandLayout.compactPhoneScale(for: geo.size)

            ZStack {
                if let genre = selectedPlayingGenre,
                   activePlaylist != nil {
                    let audibleTrack = ResidentPlaybackTrackCatalog.track(
                        for: genre,
                        trackIndex: activeTrackIndex
                    )
                    ResidentPlaylistPanelBackdropView(
                        genre: genre,
                        trackTitle: audibleTrack.title,
                        trackIndex: activeTrackIndex,
                        orbSize: mediaSize,
                        mediaFillScale: displayMediaFillScale(),
                        pageExpansion: mediaExpansion
                    )
                    .position(x: mediaAnchor.x, y: mediaAnchor.y)
                    .transition(.opacity.animation(.easeInOut(duration: 0.45)))
                    .allowsHitTesting(false)
                }

                if activePlaylist != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .gesture(playlistSwipeGesture)
                        .accessibilityLabel("Swipe for previous or next track")
                        .accessibilityHint("Swipe right for the previous song, left for the next.")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(CalmMotion.playlistOrbMorph, value: mediaExpansion)
            .overlay {
                residentGlyphCanvas
            }
            .overlay {
                if comfortInviteActive {
                    Color.black.opacity(0.07)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                HStack {
                    Spacer()
                    Button {
                        stopPlayback()
                        state.leaveResidentProfileToStaff()
                    } label: {
                        ResidentLuminousFloatingButton(
                            systemImage: "person.badge.key",
                            accent: BrandTheme.logoCyan,
                            diameter: 48 * phoneScale
                        )
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityLabel("Return to roster and record session")
                }
                .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
                .padding(.top, 10)
            }
            .overlay(alignment: .center) {
                if comfortInviteActive, selectedPlayingGenre != nil {
                    PlaylistComfortDock(
                        affirmationChoice: comfortAffirmationChoice,
                        affirmationTick: comfortAffirmationTick,
                        onFeelsGood: { handleComfortChoice(.feelsGood) },
                        onTryElse: { handleComfortChoice(.trySomethingElse) }
                    )
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
                    .animation(CalmMotion.gentle, value: comfortInvitePhase)
                }
            }
            .overlay(alignment: .bottom) {
                if let sg = selectedPlayingGenre {
                    Button {
                        stopResidentAudio()
                        state.prepareResidentImmersiveFromPlaylist(genre: sg)
                        stopPlayback()
                    } label: {
                        ResidentLuminousFloatingButton(
                            systemImage: "leaf.fill",
                            accent: BrandTheme.logoPink,
                            diameter: 56 * phoneScale
                        )
                    }
                    .buttonStyle(SoftPressButtonStyle())
                    .accessibilityLabel("Calm room visuals")
                    .padding(.bottom, max(42, geo.safeAreaInsets.bottom + 16))
                    .animation(CalmMotion.gentle, value: comfortInvitePhase)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            evaluateComfortInviteSchedule()
        }
        .onChange(of: state.selectedCarePatientId) { _, _ in
            stopPlayback()
        }
        .onChange(of: selectedPlayingGenre) { old, new in
            if new == nil {
                collapsePlaybackMedia()
                resetComfortInvite()
            } else if let old, old != new {
                cyclePlaybackMediaForGenreChange()
                markPlaybackAnchor()
                playCurrentTrack()
            } else {
                expandPlaybackMedia(afterBriefPause: true)
                markPlaybackAnchor()
                playCurrentTrack()
            }
        }
        .onChange(of: activeTrackIndex) { _, _ in
            if selectedPlayingGenre != nil {
                markPlaybackAnchor()
                playCurrentTrack()
            }
        }
        .onAppear {
            state.reaffirmPhaseContentVisible()
            StreamAudioCache.prefetch(StreamAudioCache.ambientPlaybackURLs)
        }
        .onDisappear {
            stopResidentAudio()
            collapsePlaybackMedia()
            resetComfortInvite()
        }
    }

    /// Floating genre glyphs — isolated in an overlay so layout size is stable and implicit
    /// animations from screen transitions cannot interfere with `.position()` placement.
    private var residentGlyphCanvas: some View {
        GeometryReader { geo in
            let hullScale = BrandLayout.hullScale(for: geo.size)
            let heroDiskDiameter = 154 * hullScale
            let hub = GlyphFloatLayout.musicGlyphHub(in: geo.size)
            let idle = GlyphFloatLayout.constellation(count: genresOnFile.count, in: geo.size)
            let playingPeriphery: [CGPoint] = {
                guard let sg = selectedPlayingGenre else { return [] }
                let others = genresOnFile.filter { $0 != sg }
                guard others.isEmpty == false else { return [] }
                return GlyphFloatLayout.focusedInactivePeriphery(
                    inactiveCount: others.count,
                    heroDiameter: heroDiskDiameter,
                    hub: hub,
                    in: geo.size
                )
            }()

            TimelineView(.animation(minimumInterval: 1 / OrbRenderBudget.contentFramesPerSecond, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Array(genresOnFile.enumerated()), id: \.element.id) { index, genre in
                        let emphasis = glyphRole(for: genre)
                        let (computedCenter, disk, icon) = glyphFrames(
                            genre: genre,
                            index: index,
                            in: geo.size,
                            hullScale: hullScale,
                            idleCenters: idle.centers,
                            idleHub: idle.hub,
                            peripheryPlayingCenters: playingPeriphery
                        )
                        let anchor = emphasis == .hero ? hub : computedCenter

                        floatingGlyphButton(
                            genre: genre,
                            index: index,
                            baseCenter: anchor,
                            constellationHub: hub,
                            phase: t,
                            canvasSize: geo.size,
                            diskDiameter: disk,
                            iconSize: icon,
                            emphasis: emphasis,
                            showComfortBreathingRing: emphasis == .hero && comfortInviteActive,
                            action: { playGenreImmediately(genre) }
                        )
                        .zIndex(emphasis == .hero ? 50 : CGFloat(index))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(!comfortInviteActive)
        .animation(CalmMotion.playlistOrbMorph, value: mediaExpansion)
    }

    private var playlistSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onEnded { value in
                guard let playlist = activePlaylist else { return }
                let count = max(1, playlist.trackTitles.count)
                if value.translation.width <= -50 {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        activeTrackIndex = (activeTrackIndex + 1) % count
                    }
                    state.recordResidentTrackChange()
                    resetComfortInviteForNewPlayback()
                } else if value.translation.width >= 50 {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        activeTrackIndex = (activeTrackIndex - 1 + count) % count
                    }
                    state.recordResidentTrackChange()
                    resetComfortInviteForNewPlayback()
                }
            }
    }

    private func playCurrentTrack() {
        guard let genre = selectedPlayingGenre, activePlaylist != nil else { return }
        let track = ResidentPlaybackTrackCatalog.track(for: genre, trackIndex: activeTrackIndex)
        let key = "\(genre.rawValue)|\(activeTrackIndex)|\(track.title)"
        guard activeAudioKey != key else { return }
        activeAudioKey = key
        stopResidentAudio()
        residentAudio.musicReactiveProfile = .discovery
        residentAudio.startFresh(streamURL: track.audioURL)
    }

    private func stopResidentAudio() {
        residentAudio.musicReactiveProfile = .standard
        residentAudio.stop()
    }

    private func stopPlayback() {
        stopResidentAudio()
        activeAudioKey = nil
        selectedPlayingGenre = nil
        activePlaylist = nil
        activeTrackIndex = 0
        collapsePlaybackMedia()
        resetComfortInvite()
    }

    private func expandPlaybackMedia(afterBriefPause: Bool = false) {
        genreMediaCycleToken += 1
        let apply = {
            if reduceMotion {
                mediaExpansion = 1
            } else {
                withAnimation(CalmMotion.playlistOrbMorph) {
                    mediaExpansion = 1
                }
            }
        }
        if afterBriefPause {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: apply)
        } else {
            apply()
        }
    }

    private func collapsePlaybackMedia() {
        genreMediaCycleToken += 1
        if reduceMotion {
            mediaExpansion = 0
        } else {
            withAnimation(CalmMotion.playlistOrbMorph) {
                mediaExpansion = 0
            }
        }
    }

    /// Switching to another playlist shrinks the visuals fully back to the orb, then blooms the new
    /// genre's media out to full-page — so a genre change reads as "collapse → new orb → expand".
    private func cyclePlaybackMediaForGenreChange() {
        genreMediaCycleToken += 1
        let token = genreMediaCycleToken

        if reduceMotion {
            mediaExpansion = 1
            return
        }

        withAnimation(CalmMotion.playlistOrbCollapse) {
            mediaExpansion = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard token == genreMediaCycleToken, selectedPlayingGenre != nil else { return }
            withAnimation(CalmMotion.playlistOrbMorph) {
                mediaExpansion = 1
            }
        }
    }

    private func playbackKey() -> String? {
        guard let genre = selectedPlayingGenre else { return nil }
        return "\(genre.rawValue)-\(activeTrackIndex)"
    }

    private func markPlaybackAnchor() {
        playbackAnchor = Date()
        comfortDismissGeneration += 1
        withAnimation(CalmMotion.gentle) {
            comfortInvitePhase = .hidden
        }
        comfortAffirmationChoice = nil
    }

    private func resetComfortInviteForNewPlayback() {
        playbackAnchor = Date()
        comfortDismissGeneration += 1
        withAnimation(CalmMotion.gentle) {
            comfortInvitePhase = .hidden
        }
        comfortAffirmationChoice = nil
    }

    private func resetComfortInvite() {
        playbackAnchor = nil
        lastPromptedPlaybackKey = nil
        comfortPromptCount = 0
        comfortDismissGeneration += 1
        comfortInvitePhase = .hidden
        comfortAffirmationChoice = nil
    }

    private func evaluateComfortInviteSchedule() {
        guard comfortInvitePhase == .hidden else { return }
        guard selectedPlayingGenre != nil, activePlaylist != nil else { return }
        guard comfortPromptCount < PlaylistComfortTiming.maxPromptsPerSession else { return }
        guard let anchor = playbackAnchor else { return }
        guard Date().timeIntervalSince(anchor) >= PlaylistComfortTiming.settleSeconds else { return }
        guard let key = playbackKey(), key != lastPromptedPlaybackKey else { return }
        presentComfortInvite(for: key)
    }

    private func presentComfortInvite(for key: String) {
        lastPromptedPlaybackKey = key
        comfortDismissGeneration += 1
        let generation = comfortDismissGeneration
        withAnimation(CalmMotion.gentle) {
            comfortInvitePhase = .visible
        }
        CalmExperienceFeedback.sessionSettle()

        DispatchQueue.main.asyncAfter(deadline: .now() + PlaylistComfortTiming.inviteVisibleSeconds) {
            guard generation == comfortDismissGeneration, comfortInvitePhase == .visible else { return }
            dismissComfortInvite(recording: .implicitNeutral)
        }
    }

    private func handleComfortChoice(_ choice: ResidentPlaylistComfortChoice) {
        guard comfortInvitePhase == .visible else { return }
        comfortDismissGeneration += 1
        comfortAffirmationChoice = choice
        comfortAffirmationTick &+= 1
        state.recordResidentPlaylistComfort(choice)
        comfortPromptCount += 1
        CalmExperienceFeedback.discoveryPick()

        if choice == .trySomethingElse, let current = selectedPlayingGenre {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                playAdjacentGenre(from: current)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(CalmMotion.gentle) {
                comfortInvitePhase = .hidden
            }
            comfortAffirmationChoice = nil
        }
    }

    private func dismissComfortInvite(recording choice: ResidentPlaylistComfortChoice) {
        comfortDismissGeneration += 1
        state.recordResidentPlaylistComfort(choice)
        comfortPromptCount += 1
        withAnimation(CalmMotion.gentle) {
            comfortInvitePhase = .hidden
        }
        comfortAffirmationChoice = nil
    }

    private func playAdjacentGenre(from current: ResidentMusicGenre) {
        let ordered = genresOnFile
        guard ordered.count > 1, let idx = ordered.firstIndex(of: current) else { return }
        let next = ordered[(idx + 1) % ordered.count]
        playGenreImmediately(next)
    }

    private func glyphRole(for genre: ResidentMusicGenre) -> ResidentGlyphEmphasis {
        guard let sel = selectedPlayingGenre else { return .idle }
        return genre == sel ? .hero : .sideStrip
    }

    private func glyphFrames(
        genre: ResidentMusicGenre,
        index: Int,
        in size: CGSize,
        hullScale: CGFloat,
        idleCenters: [CGPoint],
        idleHub: CGPoint,
        peripheryPlayingCenters: [CGPoint]
    ) -> (CGPoint, CGFloat, CGFloat) {
        let idleDisk: CGFloat = 92 * hullScale
        let idleIcon: CGFloat = 42 * hullScale
        let heroDisk: CGFloat = 154 * hullScale
        let heroIcon: CGFloat = 66 * hullScale
        let sideDisk: CGFloat = 68 * hullScale
        let sideIcon: CGFloat = 30 * hullScale

        switch glyphRole(for: genre) {
        case .idle:
            guard index < idleCenters.count else {
                return (idleHub, idleDisk, idleIcon)
            }
            return (idleCenters[index], idleDisk, idleIcon)
        case .hero:
            return (idleHub, heroDisk, heroIcon)
        case .sideStrip:
            guard let sg = selectedPlayingGenre else {
                guard index < idleCenters.count else {
                    return (idleHub, sideDisk, sideIcon)
                }
                return (idleCenters[index], sideDisk, sideIcon)
            }
            let inactiveOrdered = genresOnFile.filter { $0 != sg }
            guard let idx = inactiveOrdered.firstIndex(of: genre), idx < peripheryPlayingCenters.count else {
                guard index < idleCenters.count else {
                    return (idleHub, sideDisk, sideIcon)
                }
                return (idleCenters[index], sideDisk, sideIcon)
            }
            return (peripheryPlayingCenters[idx], sideDisk, sideIcon)
        }
    }

    private func playGenreImmediately(_ genre: ResidentMusicGenre) {
        guard let group = patient?.genrePlaylistGroups.first(where: { $0.genre == genre }),
              group.playlists.isEmpty == false
        else {
            return
        }
        let playlist = group.playlists.first(where: { !$0.trackTitles.isEmpty }) ?? group.playlists[0]

        withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
            selectedPlayingGenre = genre
            activePlaylist = playlist
            activeTrackIndex = 0
        }
        CalmExperienceFeedback.playlistStart()
        state.recordResidentGenrePlay(genre)
        markPlaybackAnchor()
    }

    private func floatingGlyphButton(
        genre: ResidentMusicGenre,
        index: Int,
        baseCenter: CGPoint,
        constellationHub: CGPoint,
        phase: TimeInterval,
        canvasSize: CGSize,
        diskDiameter: CGFloat,
        iconSize: CGFloat,
        emphasis: ResidentGlyphEmphasis,
        showComfortBreathingRing: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let rawΔ = GlyphFloatLayout.animatedDelta(
            index: index,
            base: baseCenter,
            hub: constellationHub,
            phase: phase,
            in: canvasSize
        )
        /// Periphery icons still orbit the hull — drift can be lighter now that anchors sit farther out.
        let motionScale: CGFloat =
            emphasis == .sideStrip ? 0.58 : emphasis == .hero ? 0.82 : 1
        let Δ = CGSize(width: rawΔ.width * motionScale, height: rawΔ.height * motionScale)
        let pos = CGPoint(x: baseCenter.x + Δ.width, y: baseCenter.y + Δ.height)
        let rot = GlyphFloatLayout.rotationDynamics(index: index, phase: phase)
        let driftScale = GlyphFloatLayout.scalePulse(index: index, phase: phase)
        let roleScale: CGFloat =
            emphasis == .hero ? 1.02 : emphasis == .sideStrip ? 0.98 : 1
        let endR = diskDiameter * 0.62
        let eqRibbon = emphasis == .hero ? OrbRadialBarEqualizerView.outwardPad(for: diskDiameter) : 0
        let glyphStackSquare = diskDiameter + eqRibbon * 2
        let barCanvas = OrbRadialBarEqualizerView.canvasDiameter(for: diskDiameter)
        let barOrbRadius = OrbRadialBarEqualizerView.orbRadius(for: diskDiameter)

        return Button(action: action) {
            ZStack {
                if showComfortBreathingRing {
                    PlaylistComfortBreathingRing(diameter: diskDiameter, phase: phase)
                }

                Circle()
                    .fill(genre.accent.opacity(emphasis == .hero ? 0.38 : 0.24))
                    .blur(radius: emphasis == .hero ? 22 : 12)
                    .frame(width: diskDiameter * 1.14, height: diskDiameter * 1.14)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(emphasis == .hero ? 0.96 : 0.92),
                                genre.accent.opacity(emphasis == .hero ? 0.72 : 0.64),
                                genre.accent.opacity(emphasis == .hero ? 0.52 : 0.46),
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: endR
                        )
                    )
                    .frame(width: diskDiameter, height: diskDiameter)
                    .shadow(color: genre.accent.opacity(emphasis == .hero ? 0.62 : 0.38), radius: emphasis == .hero ? 32 : 18)
                    .shadow(color: BrandTheme.logoCyan.opacity(emphasis == .hero ? 0.48 : 0.28), radius: emphasis == .hero ? 24 : 14)
                    .shadow(color: BrandTheme.logoPink.opacity(0.22), radius: emphasis == .hero ? 16 : 8)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: emphasis == .hero
                                        ? [
                                            BrandTheme.logoCyan.opacity(0.95),
                                            BrandTheme.logoPink.opacity(0.82),
                                            BrandTheme.gold.opacity(0.72),
                                        ]
                                        : [
                                            BrandTheme.logoCyan.opacity(0.72),
                                            BrandTheme.logoPink.opacity(0.52),
                                            BrandTheme.goldSoft.opacity(0.38),
                                        ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: emphasis == .hero ? 1.6 : 1.1
                            )
                    )

                ResidentGenreGlyphIcon(genre: genre, iconSize: iconSize, emphasis: emphasis)
            }
            .frame(width: diskDiameter, height: diskDiameter)
            .background {
                if emphasis == .hero {
                    OrbRadialBarEqualizerView(
                        canvasDiameter: barCanvas,
                        orbRadius: barOrbRadius,
                        visibleBarCount: OrbRadialBarEqualizerMotion.defaultBarCount,
                        reactsToMusic: true,
                        liveAudioOnly: true,
                        liveAudioGain: OrbRadialBarEqualizerView.LiveMusicTuning.liveAudioGain,
                        liveLevelExponent: OrbRadialBarEqualizerView.LiveMusicTuning.liveLevelExponent,
                        barAmplitudeFloor: OrbRadialBarEqualizerView.LiveMusicTuning.barAmplitudeFloor,
                        barReach: OrbRadialBarEqualizerView.LiveMusicTuning.barReach,
                        neighbourMix: OrbRadialBarEqualizerView.LiveMusicTuning.neighbourMix
                    )
                    .accessibilityHidden(true)
                }
            }
            .frame(width: glyphStackSquare, height: glyphStackSquare)
            .contentShape(
                Circle()
                    .path(
                        in: CGRect(
                            x: (glyphStackSquare - diskDiameter) / 2,
                            y: (glyphStackSquare - diskDiameter) / 2,
                            width: diskDiameter,
                            height: diskDiameter
                        )
                    )
            )
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel(genre.accessibilityLabel)
        .accessibilityAddTraits(selectedPlayingGenre == genre ? .isSelected : [])
        .position(x: pos.x, y: pos.y)
        .rotationEffect(.degrees(rot))
        .scaleEffect(driftScale * roleScale, anchor: .center)
        .opacity(emphasis == .sideStrip ? max(0.42, 0.88 - mediaExpansion * 0.46) : 1)
        .saturation(emphasis == .sideStrip ? max(0.72, 0.94 - mediaExpansion * 0.22) : 1.04)
    }
}

// MARK: - Genre instrument glyph (high-contrast on luminous disks)

private struct ResidentGenreGlyphIcon: View {
    let genre: ResidentMusicGenre
    let iconSize: CGFloat
    let emphasis: ResidentGlyphEmphasis

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(emphasis == .hero ? 0.98 : 0.94))
                .frame(width: iconSize * 1.62, height: iconSize * 1.62)
                .shadow(color: .black.opacity(0.14), radius: 2, y: 1)

            Image(systemName: genre.iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(genre.glyphIconColor)
                .shadow(color: .white.opacity(0.55), radius: 0, x: 0, y: -0.5)
                .shadow(color: .black.opacity(0.22), radius: 1.5, y: 1)
                .symbolRenderingMode(.monochrome)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Luminous floating controls (resident calm surface)

private struct ResidentLuminousFloatingButton: View {
    let systemImage: String
    let accent: Color
    var diameter: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.32))
                .blur(radius: diameter * 0.22)
                .frame(width: diameter * 1.2, height: diameter * 1.2)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.52),
                            BrandTheme.logoCyan.opacity(0.22),
                            BrandTheme.cream.opacity(0.38),
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: diameter * 0.52
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.82),
                                    accent.opacity(0.78),
                                    BrandTheme.logoCyan.opacity(0.62),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.38, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, accent.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: accent.opacity(0.65), radius: 8)
        }
        .shadow(color: accent.opacity(0.45), radius: 14)
        .shadow(color: BrandTheme.logoCyan.opacity(0.28), radius: 22)
    }
}

// MARK: - Playlist comfort dock (binary sentiment — advanced dementia friendly)

private struct PlaylistComfortDock: View {
    let affirmationChoice: ResidentPlaylistComfortChoice?
    let affirmationTick: UInt
    var onFeelsGood: () -> Void
    var onTryElse: () -> Void
    @Environment(\.flowContainerSize) private var flowContainerSize

    var body: some View {
        HStack(spacing: 52 * BrandLayout.compactPhoneScale(for: flowContainerSize)) {
            PlaylistComfortChoiceButton(
                choice: .feelsGood,
                systemImage: SFCompat.resolve("sun.max.fill", "sun.max"),
                palette: .sun,
                affirmationChoice: affirmationChoice,
                affirmationTick: affirmationTick,
                action: onFeelsGood
            )
            PlaylistComfortChoiceButton(
                choice: .trySomethingElse,
                systemImage: SFCompat.resolve("cloud.fill", "cloud"),
                palette: .cloud,
                affirmationChoice: affirmationChoice,
                affirmationTick: affirmationTick,
                action: onTryElse
            )
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }
}

/// Vivid, high-contrast colour identity for the two comfort choices — a warm **yellow sun** for
/// "feels good" and a cool **grey cloud** for "not for me".
private enum ComfortChoicePalette {
    case sun
    case cloud

    /// Face of the puck (center → rim).
    var diskColors: [Color] {
        switch self {
        case .sun:
            return [Color(red: 1.0, green: 0.97, blue: 0.74), Color(red: 1.0, green: 0.84, blue: 0.24), Color(red: 1.0, green: 0.68, blue: 0.06)]
        case .cloud:
            return [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.75, green: 0.79, blue: 0.84), Color(red: 0.49, green: 0.55, blue: 0.62)]
        }
    }

    var glow: Color {
        switch self {
        case .sun: return Color(red: 1.0, green: 0.80, blue: 0.12)
        case .cloud: return Color(red: 0.58, green: 0.63, blue: 0.70)
        }
    }

    var stroke: Color {
        switch self {
        case .sun: return Color(red: 1.0, green: 0.90, blue: 0.48)
        case .cloud: return Color(red: 0.86, green: 0.89, blue: 0.93)
        }
    }

    var icon: Color { .white }

    var iconShadow: Color {
        switch self {
        case .sun: return Color(red: 0.78, green: 0.45, blue: 0.0).opacity(0.55)
        case .cloud: return Color(red: 0.30, green: 0.36, blue: 0.44).opacity(0.55)
        }
    }
}

private struct PlaylistComfortChoiceButton: View {
    let choice: ResidentPlaylistComfortChoice
    let systemImage: String
    let palette: ComfortChoicePalette
    let affirmationChoice: ResidentPlaylistComfortChoice?
    let affirmationTick: UInt
    var action: () -> Void

    @State private var pressPopScale: CGFloat = 1
    @State private var glowBurst: CGFloat = 0
    @Environment(\.flowContainerSize) private var flowContainerSize

    /// Larger on Pro Max-class phones; unchanged on standard phones and iPad.
    private var diameter: CGFloat {
        132 * BrandLayout.compactPhoneScale(for: flowContainerSize)
    }

    private var luminousLevel: CGFloat {
        glowBurst > 0.01 ? glowBurst : 0.44
    }

    var body: some View {
        Button {
            action()
            triggerPressFlash()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.glow.opacity(0.5 * luminousLevel + 0.16),
                                palette.glow.opacity(0.26 * luminousLevel),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: diameter * 0.66
                        )
                    )
                    .frame(width: diameter * (1.18 + luminousLevel * 0.18), height: diameter * (1.18 + luminousLevel * 0.18))
                    .blur(radius: 7 + luminousLevel * 16)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: palette.diskColors,
                            center: UnitPoint(x: 0.42, y: 0.36),
                            startRadius: 4,
                            endRadius: diameter * 0.58
                        )
                    )
                    .frame(width: diameter * 0.9, height: diameter * 0.9)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.95),
                                        palette.stroke.opacity(0.7 + luminousLevel * 0.25),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5 + luminousLevel * 2
                            )
                    )
                    .shadow(color: palette.glow.opacity(0.4 + luminousLevel * 0.5), radius: 14 + luminousLevel * 20)

                Image(systemName: systemImage)
                    .font(.system(size: diameter * 0.4, weight: .bold))
                    .foregroundStyle(palette.icon)
                    .shadow(color: palette.iconShadow, radius: 3, y: 1.5)
                    .shadow(color: .white.opacity(0.5), radius: 0.5, y: -0.5)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(pressPopScale)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel(choice.accessibilityLabel)
        .onChange(of: affirmationTick) { _, _ in
            guard affirmationChoice == choice else { return }
            playAffirmationGlow()
        }
    }

    private func triggerPressFlash() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        withAnimation(.easeOut(duration: 0.12)) { pressPopScale = 1.08 }
        withAnimation(.easeOut(duration: 0.28).delay(0.1)) { pressPopScale = 1 }
    }

    private func playAffirmationGlow() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        glowBurst = 1
        withAnimation(.easeOut(duration: 0.55)) { glowBurst = 0 }
    }
}

private struct PlaylistComfortBreathingRing: View {
    let diameter: CGFloat
    let phase: TimeInterval

    var body: some View {
        let pulse = 0.5 + 0.5 * sin(phase * 1.15)
        Circle()
            .strokeBorder(BrandTheme.gold.opacity(0.28 + pulse * 0.32), lineWidth: 2 + pulse * 3)
            .frame(width: diameter * (1.18 + pulse * 0.06), height: diameter * (1.18 + pulse * 0.06))
            .blur(radius: 0.5 + pulse * 1.5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

