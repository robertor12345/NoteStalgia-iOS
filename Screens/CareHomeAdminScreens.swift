import SwiftUI

// MARK: - Care home admin — session impact dashboard

struct CareHomeAdminDashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var state: SessionPOCState

    private var dashboard: CareHomeDashboardPresentation {
        state.careHomeDashboardPresentation()
    }

    private var canSwitchHome: Bool {
        (state.currentSupervisorAccount()?.homeIds.count ?? 0) > 1
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to home selection",
                onBack: { state.returnFromAdminDashboard() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    headerSection
                    if !dashboard.trendSeries.isEmpty {
                        trendGraphsSection
                    }
                    kpiGrid
                    if !dashboard.wingBreakdown.isEmpty {
                        wingSection
                    }
                    groupProgrammeSection
                    if !dashboard.positiveHighlights.isEmpty {
                        impactSection(
                            title: "Positive session impact",
                            subtitle: "Residents trending up vs their recent sessions",
                            residents: dashboard.positiveHighlights,
                            accent: BrandTheme.statusPositive
                        )
                    }
                    if !dashboard.attentionNeeded.isEmpty {
                        impactSection(
                            title: "Needs attention",
                            subtitle: "Overdue visits or declining observed wellbeing",
                            residents: dashboard.attentionNeeded,
                            accent: BrandTheme.statusAttention
                        )
                    }
                    recentSessionsSection
                    adminActions
                }
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            if !state.isSignedIn || !state.isCareHomeAdmin {
                state.phase = .home
            } else if state.currentHomeId == nil {
                state.phase = .careHomePicker
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            FadeInTitle(text: dashboard.homeName, delay: 0)
            FadeInLine(
                text: "Session impact · \(dashboard.periodLabel)",
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            if let account = state.currentSupervisorAccount() {
                FadeInLine(
                    text: "\(account.displayName) · Home admin",
                    font: .caption.weight(.medium),
                    muted: true,
                    delay: 0.06
                )
            }
            if !dashboard.hasSessionData {
                FadeInLine(
                    text: "Session data will populate as staff complete calm visits.",
                    font: BrandTheme.orbHintFont(),
                    muted: true,
                    delay: 0.08
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            }
        }
    }

    private var trendGraphsSection: some View {
        DashboardTrendGraphsStrip(series: dashboard.trendSeries)
            .padding(.horizontal, 4)
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
            ForEach(Array(dashboard.kpis.enumerated()), id: \.element.id) { index, kpi in
                DashboardKPICardView(card: kpi, delay: 0.05 + Double(index) * 0.04)
            }
        }
        .padding(.horizontal, 4)
    }

    /// The home's group programme — sessions, reach, how they land, and who has had none.
    private var groupProgrammeSection: some View {
        let g = state.groupProgrammeSummary()
        return BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "Group programme",
                    systemImage: "person.3",
                    subtitle: "Group activities over the same \(GroupActivityPlanner.windowDays) days, alongside the one-to-ones above.",
                    identifier: "admin.groupProgramme"
                )
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
                LazyVGrid(columns: columns, spacing: 10) {
                    BrandStatTile(value: "\(g.sessions14d)", label: "Sessions")
                    BrandStatTile(value: "\(g.residentsReached) of \(g.activeResidents)", label: "Residents reached")
                    BrandStatTile(
                        value: g.averageEngagement.map { String(format: "%.1f", $0) } ?? "—",
                        label: "Engagement",
                        detail: "out of 10",
                        tint: g.averageEngagement.map { BrandRatingTone.tint(outOfTen: $0) }
                    )
                    BrandStatTile(
                        value: g.averageMorale.map { String(format: "%.1f", $0) } ?? "—",
                        label: "Morale",
                        detail: "out of 10",
                        tint: g.averageMorale.map { BrandRatingTone.tint(outOfTen: $0) }
                    )
                    // Activities staff logged as held outside the app, so the programme isn't only what the app played.
                    BrandStatTile(
                        value: "\(g.activities14d)",
                        label: "Outside the app",
                        detail: g.activities14d == 0 ? "none logged" : "\(g.activityAttendances14d) attended"
                    )
                    BrandStatTile(
                        value: g.activityAverageEngagement.map { String(format: "%.1f", $0) } ?? "—",
                        label: "Their engagement",
                        detail: "out of 10",
                        tint: g.activityAverageEngagement.map { BrandRatingTone.tint(outOfTen: $0) }
                    )
                }
                if let best = g.bestActivity {
                    BrandInsetTile {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.statusCaution)
                                .accessibilityHidden(true)
                            Text("Lands best: \(best.title) · \(String(format: "%.1f", best.averageEngagement))/10 engagement over \(best.sessions) session\(best.sessions == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if g.noGroupCount > 0 {
                    let names = g.noGroupNames.joined(separator: ", ")
                    let more = g.noGroupCount - g.noGroupNames.count
                    // "Muriel S." already ends in a full stop; do not add a second one.
                    let stop = names.hasSuffix(".") && more <= 0 ? "" : "."
                    let tail = names.isEmpty ? "." : " — \(names)\(more > 0 ? " and \(more) more." : stop)"
                    // A warning sits on a tile, not loose on the card: coral text alone faded over the orb's glow.
                    BrandInsetTile(accent: BrandTheme.statusAttention) {
                        Label {
                            Text("\(g.noGroupCount) resident\(g.noGroupCount == 1 ? "" : "s") who would welcome a group \(g.noGroupCount == 1 ? "has" : "have") had none in \(GroupActivityPlanner.windowDays) days\(tail)")
                                .foregroundStyle(BrandTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(BrandTheme.statusAttention)
                        }
                        .font(.caption.weight(.medium))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var wingSection: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: "Impact by wing",
                    systemImage: "building.2",
                    subtitle: "Where calm sessions are landing across the home."
                )
                BrandRowsTile(spacing: 14) {
                    ForEach(Array(dashboard.wingBreakdown.enumerated()), id: \.element.id) { index, wing in
                        if index > 0 { BrandHairline() }
                        DashboardWingImpactRow(wing: wing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func impactSection(
        title: String,
        subtitle: String,
        residents: [CareHomeResidentImpact],
        accent: Color
    ) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: title,
                    systemImage: accent == BrandTheme.statusAttention ? "exclamationmark.circle" : "arrow.up.right.circle",
                    tint: accent,
                    subtitle: subtitle
                )
                BrandRowsTile(spacing: 14) {
                    ForEach(Array(residents.enumerated()), id: \.element.id) { index, resident in
                        if index > 0 { BrandHairline() }
                        DashboardResidentImpactRow(resident: resident)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var recentSessionsSection: some View {
        Group {
            if !dashboard.recentSessions.isEmpty {
                BrandCard {
                    VStack(alignment: .leading, spacing: 14) {
                        BrandSectionHeader(title: "Recent sessions", systemImage: "clock")
                        BrandRowsTile(spacing: 14) {
                            ForEach(Array(dashboard.recentSessions.enumerated()), id: \.element.id) { index, session in
                                if index > 0 { BrandHairline() }
                                DashboardRecentSessionRow(session: session)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var adminActions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Open the roster") {
                state.openRosterFromAdminDashboard()
            }
            .accessibilityIdentifier("admin.openRoster")
            .padding(.horizontal, 24)
            Text("Residents, their profiles and the group activities planner for \(dashboard.homeName).")
                .font(.caption)
                .orbOverlayText(muted: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if canSwitchHome {
                SecondaryButton(title: "Switch care home") {
                    state.switchHome()
                }
                .accessibilityIdentifier("admin.switchHome")
                .padding(.horizontal, 24)
            }
            if state.usesBackend, state.currentSupervisorAccount()?.role == .orgAdmin {
                OrgSetupDashboardCard(state: state, onboarding: state.onboarding)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Trend graphs (compact, expandable)

struct DashboardTrendGraphsStrip: View {
    let series: [CareHomeTrendSeries]
    var title = "Home trends"
    var subtitle = "Tap a chart to expand — tap again to collapse."
    @State private var expandedId: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// On iPad the compact cards share the card's width in a grid (three across, or two by two for
    /// four series) — the third chart used to clip in a horizontal scroll. The scroll stays for phone width.
    private var fitsAcross: Bool {
        BrandLayout.isRegularWidth(horizontalSizeClass)
    }

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(title: title, systemImage: "chart.line.uptrend.xyaxis", subtitle: subtitle)

                if fitsAcross {
                    let columns = Array(
                        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                        count: series.count <= 3 ? max(series.count, 1) : 2
                    )
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        compactCards(flexible: true)
                    }
                    .padding(.vertical, 2)
                } else {
                    HorizontalScrollEdgeFade(coordinateSpace: "adminTrendGraphs") {
                        HStack(alignment: .top, spacing: 10) {
                            compactCards(flexible: false)
                        }
                        .padding(.vertical, 2)
                    }
                }

                if let expandedId,
                   let expanded = series.first(where: { $0.id == expandedId }) {
                    DashboardTrendGraphCard(
                        series: expanded,
                        isExpanded: true,
                        compact: false
                    ) {
                        withAnimation(CalmMotion.gentle) {
                            self.expandedId = nil
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func compactCards(flexible: Bool) -> some View {
        ForEach(series) { item in
            DashboardTrendGraphCard(
                series: item,
                isExpanded: expandedId == item.id,
                compact: true,
                flexible: flexible
            ) {
                withAnimation(CalmMotion.gentle) {
                    expandedId = expandedId == item.id ? nil : item.id
                }
            }
        }
    }
}

private struct DashboardTrendGraphCard: View {
    let series: CareHomeTrendSeries
    var isExpanded: Bool
    var compact: Bool
    /// Compact card that shares the row's width instead of a fixed 168 pt.
    var flexible: Bool = false
    var onTap: () -> Void

    private var accent: Color {
        switch series.id {
        case "sessions": return BrandTheme.nebulaTeal
        case "reach": return BrandTheme.nebulaLavender
        case "calm": return BrandTheme.logoCyan
        case "wellbeing": return BrandTheme.gold
        default: return BrandTheme.nebulaTeal
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(series.title)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BrandTheme.textSecondary)
                        .opacity(compact ? 0.85 : 1)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                    Text(series.legendDescription)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DashboardTrendChart(
                    series: series,
                    accent: accent,
                    height: isExpanded && !compact ? 112 : 40,
                    showArea: isExpanded && !compact,
                    showFullXAxis: isExpanded && !compact,
                    showAxisTitles: isExpanded && !compact
                )

                if isExpanded && !compact {
                    if let summary = series.latestSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    Text(series.unitLabel)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary.opacity(0.85))
                } else if compact, let summary = series.latestSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(compact ? 10 : 14)
            .frame(width: compact && !flexible ? 168 : nil, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BrandTheme.surfaceInset)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isExpanded ? accent.opacity(0.6) : BrandTheme.insetBorder, lineWidth: isExpanded ? 1.5 : 1)
                    }
            }
        }
        .accessibilityIdentifier("admin.trend.\(series.id)")
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel("\(series.title) trend chart\(series.latestSummary.map { ", \($0)" } ?? "")")
        .accessibilityHint(isExpanded ? "Collapses the chart" : "Expands the chart")
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
    }
}

private struct DashboardTrendChart: View {
    let series: CareHomeTrendSeries
    var accent: Color
    var height: CGFloat
    var showArea: Bool
    var showFullXAxis: Bool
    var showAxisTitles: Bool

    private let yAxisWidth: CGFloat = 34
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The ticks to draw. The small charts are about 54 pt tall; at accessibility text sizes five numbers no longer fit and
    /// stacked on top of each other, so there they keep the lowest and highest only (the expanded chart keeps them all).
    private var ticks: [Double] {
        let all = series.axis.tickValues
        guard dynamicTypeSize.isAccessibilitySize, !showFullXAxis, all.count > 2, let first = all.first, let last = all.last else { return all }
        return [first, last]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showAxisTitles {
                Text(series.axis.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
            }

            HStack(alignment: .top, spacing: 6) {
                yAxisLabels(chartHeight: height)

                VStack(spacing: 4) {
                    chartBody(height: height)
                    if showFullXAxis {
                        xAxisLabels
                        Text("Day")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    private func yAxisLabels(chartHeight: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { tick in
                    Text(formatAxisValue(tick))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(BrandTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: yAxisWidth, alignment: .trailing)
                        .position(
                            x: yAxisWidth / 2,
                            y: yPosition(for: tick, in: geo.size.height)
                        )
                }
            }
        }
        .frame(width: yAxisWidth, height: chartHeight)
    }

    private func chartBody(height: CGFloat) -> some View {
        GeometryReader { geo in
            let plotted = plottedPoints(in: geo.size)
            ZStack {
                ForEach(ticks, id: \.self) { tick in
                    let y = yPosition(for: tick, in: geo.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(BrandTheme.textSecondary.opacity(showFullXAxis ? 0.24 : 0.16), lineWidth: 1)
                }

                if showArea, plotted.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: plotted[0].point.x, y: geo.size.height))
                        for plot in plotted {
                            path.addLine(to: plot.point)
                        }
                        path.addLine(to: CGPoint(x: plotted[plotted.count - 1].point.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.28), accent.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                if plotted.isEmpty {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(BrandTheme.textSecondary.opacity(0.12))
                        .frame(height: 2)
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    Path { path in
                        for (index, plot) in plotted.enumerated() {
                            if index == 0 { path.move(to: plot.point) }
                            else { path.addLine(to: plot.point) }
                        }
                    }
                    .stroke(
                        accent,
                        style: StrokeStyle(
                            lineWidth: showArea ? 2.5 : 1.8,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                    if showFullXAxis {
                        // Each dot carries its own source day — `plotted` skips days with no data, so
                        // indexing back into `series.points` put dots on the wrong day.
                        ForEach(plotted, id: \.source.id) { plot in
                            if let value = plot.source.value {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 5, height: 5)
                                    .position(plot.point)
                                    .accessibilityLabel("\(plot.source.dayLabel): \(formatAxisValue(value))")
                            }
                        }
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var xAxisLabels: some View {
        HStack(spacing: 0) {
            ForEach(series.points) { point in
                Text(point.dayLabel)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func plottedPoints(in size: CGSize) -> [(point: CGPoint, source: CareHomeTrendPoint)] {
        let minV = series.axis.minimum
        let maxV = series.axis.maximum
        let range = max(maxV - minV, 0.001)
        return series.points.enumerated().compactMap { index, point -> (point: CGPoint, source: CareHomeTrendPoint)? in
            guard let value = point.value else { return nil }
            let x = size.width * CGFloat(index) / CGFloat(max(series.points.count - 1, 1))
            let clamped = min(max(value, minV), maxV)
            let y = size.height * (1 - CGFloat((clamped - minV) / range))
            return (CGPoint(x: x, y: y), point)
        }
    }

    private func yPosition(for tick: Double, in height: CGFloat) -> CGFloat {
        let minV = series.axis.minimum
        let maxV = series.axis.maximum
        let range = max(maxV - minV, 0.001)
        let clamped = min(max(tick, minV), maxV)
        return height * (1 - CGFloat((clamped - minV) / range))
    }

    private func formatAxisValue(_ value: Double) -> String {
        switch series.valueFormat {
        case .count:
            return String(format: "%.0f", value)
        case .percent:
            return "\(Int(value.rounded()))%"
        case .score:
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            }
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Dashboard components

struct DashboardKPICardView: View {
    let card: CareHomeKPICard
    var delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            Text(card.value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(BrandTheme.textPrimary)
            Text(card.detail)
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .brandCardSurface(cornerRadius: 16)
        .overlay(alignment: .top) {
            Capsule()
                .fill(BrandTheme.logoLavenderBlue.opacity(0.85))
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.top, 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title), \(card.value), \(card.detail)")
    }
}

/// Status chip for a resident's or a home's trend: icon + word, so the tint is never the only cue.
struct DashboardTrendChip: View {
    let trend: CareHomeImpactTrend

    var body: some View {
        BrandStatusChip(text: trend.label, systemImage: icon, tint: tint)
    }

    private var icon: String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "equal"
        case .declining: return "arrow.down.right"
        case .noData: return "minus"
        }
    }

    private var tint: Color {
        switch trend {
        case .improving: return BrandTheme.statusPositive
        case .stable: return BrandTheme.statusNeutral
        case .declining: return BrandTheme.statusAttention
        case .noData: return BrandTheme.textSecondary
        }
    }
}

private struct DashboardWingImpactRow: View {
    let wing: CareHomeWingImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(wing.wingName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(wing.sessionCount) session\(wing.sessionCount == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            BrandMeterBar(fraction: wing.intensity, tint: BrandTheme.nebulaCyan)
            // Wraps instead of truncating: three chips do not fit one line at phone width.
            InsightChipFlow(spacing: 8) {
                BrandStatusChip(text: "\(wing.residentsReached) residents", systemImage: "person.2")
                if let calm = wing.averageCalmPercent {
                    BrandStatusChip(text: "\(calm)% at ease", systemImage: "leaf.fill", tint: CareAtEaseTone.tint(percent: calm))
                }
                if let wellbeing = wing.averageWellbeing {
                    BrandStatusChip(
                        text: String(format: "%.1f/10 wellbeing", wellbeing),
                        systemImage: "heart.fill",
                        tint: BrandRatingTone.tint(outOfTen: wellbeing)
                    )
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardResidentImpactRow: View {
    let resident: CareHomeResidentImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resident.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text("\(resident.roomLabel.isEmpty ? resident.wingLabel : "\(resident.roomLabel) · \(resident.wingLabel)")")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                Spacer(minLength: 8)
                DashboardTrendChip(trend: resident.trend)
            }
            Text(resident.impactLine)
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct DashboardRecentSessionRow: View {
    let session: CareHomeRecentSessionRow

    private var dateLabel: String {
        session.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(session.patientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                Spacer(minLength: 8)
                BrandStatusChip(
                    text: "\(session.calmPercent)% at ease",
                    systemImage: "leaf.fill",
                    tint: CareAtEaseTone.tint(percent: session.calmPercent)
                )
            }
            Text(session.moodSummary.isEmpty || session.moodSummary == "—" ? session.wingLabel : "\(session.wingLabel) · \(session.moodSummary)")
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let impact = session.impactLine {
                Text(impact)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Admin welcome (routes to dashboard)

struct CareHomeAdminWelcomeView: View {
    @ObservedObject var state: SessionPOCState
    @State private var greetingVisible = false
    @State private var loaderVisible = false
    @State private var didAnimateEntrance = false
    /// Shown only when the readiness gate runs past `RosterWarmUp.longWaitHintDelay`.
    @State private var showsLongerWaitHint = false

    private var displayName: String {
        state.currentSupervisorAccount()?.displayName ?? "Admin"
    }

    private var homeName: String? {
        state.currentHome()?.name
    }

    private var isManualReturn: Bool {
        state.careHomeAdminWelcomeIsManual
    }

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                CalmCircularLoader(diameter: 76)
                    .opacity(loaderVisible ? 1 : 0)
                    .scaleEffect(loaderVisible ? 1 : 0.92)

                Text(welcomeLine)
                    .font(BrandTheme.orbTitleFont(.largeTitle))
                    .tracking(2)
                    .orbOverlayText()
                    .multilineTextAlignment(.center)
                    .opacity(greetingVisible ? 1 : 0)
                    .offset(y: greetingVisible ? 0 : 14)
                    .scaleEffect(greetingVisible ? 1 : 0.97)

                if isManualReturn {
                    PrimaryButton(title: "Open home insights") {
                        state.openAdminDashboardFromWelcome()
                    }
                    .accessibilityIdentifier("admin.open")
                    .padding(.horizontal, 32)
                    .opacity(greetingVisible ? 1 : 0)
                } else {
                    // Space is reserved so the greeting never shifts when the hint fades in.
                    Text("Preparing home insights…")
                        .font(BrandTheme.orbHintFont())
                        .orbOverlayText(muted: true)
                        .opacity(showsLongerWaitHint ? 1 : 0)
                        .accessibilityHidden(!showsLongerWaitHint)
                }
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Welcome \(displayName). Loading home insights.")
        .onAppear {
            if !didAnimateEntrance {
                didAnimateEntrance = true
                withAnimation(CalmMotion.softFade.delay(0.12)) {
                    loaderVisible = true
                }
                withAnimation(CalmMotion.gentle.delay(0.28)) {
                    greetingVisible = true
                }
            }
        }
        // Auto-advance waits for the dashboard's data to be seeded and its presentation cached —
        // never before the minimum dwell, never after the cap. Manual mode shows the button instead.
        .task {
            guard !isManualReturn else { return }
            let start = Date()
            let hint = Task { @MainActor in
                try? await Task.sleep(for: .seconds(RosterWarmUp.longWaitHintDelay))
                guard !Task.isCancelled else { return }
                withAnimation(CalmMotion.softFade) { showsLongerWaitHint = true }
            }
            _ = await RosterWarmUp.awaitAdminReady(state: state, start: start)
            hint.cancel()
            guard !Task.isCancelled, state.phase == .careHomeAdminWelcome else { return }
            state.openAdminDashboardFromWelcome()
        }
    }

    private var welcomeLine: String {
        if let homeName {
            return "Welcome \(displayName)\n\(homeName) insights"
        }
        return "Welcome \(displayName)"
    }
}
