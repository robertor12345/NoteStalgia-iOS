import SwiftUI

// MARK: - Care home admin — session impact dashboard

struct CareHomeAdminDashboardView: View {
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
                    if !dashboard.positiveHighlights.isEmpty {
                        impactSection(
                            title: "Positive session impact",
                            subtitle: "Residents trending up vs their recent sessions",
                            residents: dashboard.positiveHighlights,
                            accent: BrandTheme.nebulaTeal
                        )
                    }
                    if !dashboard.attentionNeeded.isEmpty {
                        impactSection(
                            title: "Needs attention",
                            subtitle: "Overdue visits or declining observed wellbeing",
                            residents: dashboard.attentionNeeded,
                            accent: BrandTheme.nebulaSalmon
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(dashboard.kpis.enumerated()), id: \.element.id) { index, kpi in
                DashboardKPICardView(card: kpi, delay: 0.05 + Double(index) * 0.04)
            }
        }
        .padding(.horizontal, 4)
    }

    private var wingSection: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Impact by wing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("Where calm sessions are landing across the home.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                ForEach(dashboard.wingBreakdown) { wing in
                    DashboardWingImpactRow(wing: wing)
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
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent.opacity(0.85))
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(residents) { resident in
                    DashboardResidentImpactRow(resident: resident)
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
                        Text("Recent sessions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                        ForEach(dashboard.recentSessions) { session in
                            DashboardRecentSessionRow(session: session)
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
            if canSwitchHome {
                SecondaryButton(title: "Switch care home") {
                    state.switchHome()
                }
                .accessibilityIdentifier("admin.switchHome")
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Trend graphs (compact, expandable)

private struct DashboardTrendGraphsStrip: View {
    let series: [CareHomeTrendSeries]
    @State private var expandedId: String?

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Home trends")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("Tap a chart to expand — tap again to collapse.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)

                HorizontalScrollEdgeFade(coordinateSpace: "adminTrendGraphs") {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(series) { item in
                            DashboardTrendGraphCard(
                                series: item,
                                isExpanded: expandedId == item.id,
                                compact: true
                            ) {
                                withAnimation(CalmMotion.gentle) {
                                    expandedId = expandedId == item.id ? nil : item.id
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
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
}

private struct DashboardTrendGraphCard: View {
    let series: CareHomeTrendSeries
    var isExpanded: Bool
    var compact: Bool
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
                        .font(.caption2)
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
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.textSecondary.opacity(0.85))
                } else if compact, let summary = series.latestSummary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(compact ? 10 : 14)
            .frame(width: compact ? 168 : nil, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BrandTheme.creamMid.opacity(compact ? 0.55 : 0.35))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(accent.opacity(isExpanded ? 0.45 : 0.22), lineWidth: 1)
                    }
            }
        }
        .accessibilityIdentifier("admin.trend.\(series.id)")
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel("\(series.title) trend chart")
        .accessibilityHint(isExpanded ? "Collapse chart" : "Expand chart")
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
            let ticks = series.axis.tickValues
            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { tick in
                    Text(formatAxisValue(tick))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(BrandTheme.textSecondary)
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
                ForEach(series.axis.tickValues, id: \.self) { tick in
                    let y = yPosition(for: tick, in: geo.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(BrandTheme.textSecondary.opacity(showFullXAxis ? 0.16 : 0.1), lineWidth: 1)
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
                    .font(.system(size: 9))
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

private struct DashboardKPICardView: View {
    let card: CareHomeKPICard
    var delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            Text(card.value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(BrandTheme.textPrimary)
            Text(card.detail)
                .font(.caption2)
                .foregroundStyle(BrandTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(BrandTheme.cream.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandTheme.gold.opacity(0.22), lineWidth: 1)
        )
        .opacity(1)
    }
}

private struct DashboardWingImpactRow: View {
    let wing: CareHomeWingImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(wing.wingName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(wing.sessionCount) session\(wing.sessionCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BrandTheme.creamDeep.opacity(0.5))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [BrandTheme.nebulaTeal.opacity(0.7), BrandTheme.nebulaCyan.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * wing.intensity))
                }
            }
            .frame(height: 8)
            HStack(spacing: 12) {
                Text("\(wing.residentsReached) residents")
                if let calm = wing.averageCalmPercent {
                    Text("avg \(calm)% at ease")
                }
                if let wellbeing = wing.averageWellbeing {
                    Text(String(format: "%.1f/10 wellbeing", wellbeing))
                }
            }
            .font(.caption2)
            .foregroundStyle(BrandTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

private struct DashboardResidentImpactRow: View {
    let resident: CareHomeResidentImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(resident.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text(resident.trend.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(trendColor)
            }
            Text("\(resident.roomLabel.isEmpty ? resident.wingLabel : "\(resident.roomLabel) · \(resident.wingLabel)")")
                .font(.caption2)
                .foregroundStyle(BrandTheme.textSecondary)
            Text(resident.impactLine)
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    private var trendColor: Color {
        switch resident.trend {
        case .improving: return BrandTheme.nebulaTeal
        case .stable: return BrandTheme.textSecondary
        case .declining: return BrandTheme.nebulaSalmon
        case .noData: return BrandTheme.textSecondary
        }
    }
}

private struct DashboardRecentSessionRow: View {
    let session: CareHomeRecentSessionRow

    private var dateLabel: String {
        session.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.patientName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text(dateLabel)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            Text("\(session.wingLabel) · \(session.moodSummary) · \(session.calmPercent)% at ease")
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
            if let impact = session.impactLine {
                Text(impact)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
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
