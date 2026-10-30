import SwiftUI

// MARK: - Data display primitives
//
// Shared pieces for every screen that shows numbers, ratings and handover notes: the post-session
// summary, carer observation cards, the home-admin dashboard, Care at home insights, the group
// planner and the profile's session history. One visual grammar (card → inset tile → hairline
// rows), one set of status tints, and the accessibility behaviour built in: section titles are
// announced as headers, meters read their value, chips carry an icon so colour is never the only cue.

/// Card section title. VoiceOver users can jump between headers, so every card gets one.
struct BrandSectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = BrandTheme.logoCyan
    var subtitle: String? = nil
    /// Goes on the title text itself, so scripted walkthroughs still find it as a static text.
    var identifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(identifier ?? "")
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A step lifted from the card: grouped numbers, quoted notes and write-ups sit on this.
struct BrandInsetTile<Content: View>: View {
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 14
    /// Tints the edge (a highlighted "next step", an attention block).
    var accent: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BrandTheme.surfaceInset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent?.opacity(0.5) ?? BrandTheme.insetBorder, lineWidth: accent == nil ? 1 : 1.5)
            )
    }
}

/// One number with its label. The value comes first so the eye lands on it; an optional tint
/// carries the status as a thin bar along the top, and the label still says what it is.
struct BrandStatTile: View {
    let value: String
    let label: String
    var detail: String? = nil
    var tint: Color? = nil
    var centered: Bool = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(BrandTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Fills the row's height so a tile whose label wraps does not leave its neighbours short.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centered ? .center : .topLeading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BrandTheme.surfaceInset))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandTheme.insetBorder, lineWidth: 1))
        .overlay(alignment: .top) {
            if let tint {
                Capsule()
                    .fill(tint)
                    .frame(height: 3)
                    .padding(.horizontal, 14)
                    .padding(.top, 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)\(detail.map { ", \($0)" } ?? "")")
    }
}

/// A row of stat tiles at equal height. The row takes the tallest tile's height and the tiles fill
/// it; without this an `HStack` of tiles inside a scrolling column would soak up spare height.
struct BrandStatTileRow<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: () -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes four tiles across would break every label mid-word, so they stack.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
        } else {
            HStack(alignment: .top, spacing: spacing) {
                content()
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension BrandLayout {
    /// Columns for a grid of stat tiles: four on a wide screen, two on a phone, one at accessibility text sizes.
    static func statTileColumns(regularWidth: Bool, dynamicTypeSize: DynamicTypeSize) -> Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        return regularWidth ? 4 : 2
    }
}

/// Horizontal meter with a visible track. Decorative on its own — pair it with a labelled row.
struct BrandMeterBar: View {
    /// 0 … 1.
    let fraction: Double
    var tint: Color = BrandTheme.logoCyan
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(BrandTheme.meterTrack)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Label on the left, value on the right, a meter beneath — the row for every 1–10 rating and
/// percentage. Reads as one element: "Mood, 7 out of 10".
struct BrandRatingRow: View {
    let label: String
    let valueText: String
    let fraction: Double
    var tint: Color = BrandTheme.logoCyan
    var spokenValue: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
            }
            BrandMeterBar(fraction: fraction, tint: tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue ?? valueText)
    }
}

/// Status tint for a 1–10 carer rating: low = attention, middle = caution, high = positive.
enum BrandRatingTone {
    static func tint(outOfTen value: Double) -> Color {
        if value < 4.5 { return BrandTheme.statusAttention }
        if value < 6.5 { return BrandTheme.statusCaution }
        return BrandTheme.statusPositive
    }

    /// The legend that goes with the tints, so the colours are explained where they are used.
    static let legend = "Below 4.5 needs attention · 4.5–6.4 worth a look · 6.5 and above settled"
}

/// Icon + text status chip. The icon and the words carry the meaning; the tint only reinforces it.
struct BrandStatusChip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = BrandTheme.textSecondary
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(filled ? BrandTheme.creamDeep : tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        // A base of ink under the tint: on a half-transparent card the pale tint alone gave the small text 2.6–4:1.
        .background(Capsule().fill(BrandTheme.cardInk.opacity(filled ? 0 : 0.6)))
        .background(Capsule().fill(filled ? tint : tint.opacity(0.16)))
        .overlay(Capsule().stroke(tint.opacity(filled ? 0 : 0.55), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Thin separator between rows inside a card.
struct BrandHairline: View {
    var body: some View {
        Rectangle()
            .fill(BrandTheme.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A short quoted note (carer note, staff note): italic on an inset tile with an accent edge.
struct BrandQuoteBlock: View {
    var title: String? = nil
    let text: String
    var accent: Color = BrandTheme.logoPink

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            Text(text)
                .font(.callout.italic())
                .foregroundStyle(BrandTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BrandTheme.surfaceInset))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 8)
                .padding(.leading, 5)
                .accessibilityHidden(true)
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BrandTheme.insetBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Label on the left, value on the right, with a hairline beneath when it is not the last row.
struct BrandKeyValueRow: View {
    let label: String
    let value: String
    var valueTint: Color = BrandTheme.textPrimary
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.textSecondary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(valueTint)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 8)
            if !isLast { BrandHairline() }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One option of a `BrandSegmentedChoice`.
struct BrandChoiceOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    var id: Value { value }
}

/// Segmented control that stays usable at accessibility text sizes. The system segmented picker
/// never scales its labels, so at those sizes the same options become a vertical list of buttons.
struct BrandSegmentedChoice<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [BrandChoiceOption<Value>]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(options) { option in
                    let selected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        HStack(spacing: 10) {
                            Text(option.label)
                                .font(.body.weight(selected ? .semibold : .regular))
                                .foregroundStyle(BrandTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? BrandTheme.logoCyan : BrandTheme.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? BrandTheme.logoCyan.opacity(0.16) : BrandTheme.surfaceInset)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selected ? BrandTheme.logoCyan.opacity(0.55) : BrandTheme.insetBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        } else {
            // The system segmented control is 32 pt tall; these segments are 44 pt, drawn like the selectable chips
            // (selected = cyan tint + tick), and each one is a button named by its label.
            HStack(spacing: 4) {
                ForEach(options) { option in
                    let selected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        HStack(spacing: 5) {
                            // The tick takes room a narrow phone does not have with four segments ("Mana…"); there the
                            // fill, border and weight carry the selection, and VoiceOver hears "selected".
                            if selected, options.count <= 3 {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .accessibilityHidden(true)
                            }
                            Text(option.label)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(BrandTheme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? BrandTheme.cardInk.opacity(0.55) : Color.clear)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? BrandTheme.logoCyan.opacity(0.26) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? BrandTheme.logoCyan.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(BrandTheme.surfaceInset))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(BrandTheme.insetBorder, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }
}

/// Selectable chip for tag pickers (context tags, environment). Selected state shows a tick as
/// well as the tint, and the chip is at least 44 pt tall to tap.
struct BrandSelectableChip: View {
    let label: String
    let selected: Bool
    var tint: Color = BrandTheme.logoCyan
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(BrandTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(Capsule().fill(selected ? tint.opacity(0.26) : BrandTheme.surfaceInset))
            .overlay(Capsule().stroke(selected ? tint.opacity(0.7) : BrandTheme.insetBorder, lineWidth: 1))
            .expandedHitArea(vertical: 4)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Card surface

/// The fill and edge of every card, row tile and picker row. Half transparent (`BrandTheme.cardOpacity`) so
/// the orb and sparkles behind the page stay visible; opaque again when the person has Reduce Transparency
/// on, which is what that setting is for.
struct BrandCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 20
    var edge: Color = BrandTheme.cardBorder
    var opacity: Double = BrandTheme.cardOpacity
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(reduceTransparency ? BrandTheme.cream.opacity(0.94) : BrandTheme.cardInk.opacity(opacity))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(edge, lineWidth: 1)
                }
        }
    }
}

extension View {
    func brandCardSurface(cornerRadius: CGFloat = 20, edge: Color = BrandTheme.cardBorder, opacity: Double = BrandTheme.cardOpacity) -> some View {
        modifier(BrandCardSurface(cornerRadius: cornerRadius, edge: edge, opacity: opacity))
    }
}

// MARK: - Page message

/// An error, notice or confirmation under a form: an icon and words on a firm tile, so it reads on the orb and never
/// relies on colour alone (it used to be a line of salmon text straight on the orb).
struct BrandMessageTile: View {
    enum Kind { case error, notice, success }
    let text: String
    var kind: Kind = .error

    private var tint: Color {
        switch kind {
        case .error: return BrandTheme.statusAttention
        case .notice: return BrandTheme.statusNeutral
        case .success: return BrandTheme.statusPositive
        }
    }

    private var icon: String {
        switch kind {
        case .error: return "exclamationmark.triangle.fill"
        case .notice: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(BrandTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .brandCardSurface(cornerRadius: 14, edge: tint.opacity(0.65), opacity: 0.75)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rows tile

/// A run of list rows sunk into a card on one tile. The card above is half transparent, so a long stretch of small
/// text needs a firmer base than the card alone gives it over the orb's glow (the stat tiles already have one).
struct BrandRowsTile<Content: View>: View {
    var spacing: CGFloat = 12
    var verticalPadding: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BrandTheme.surfaceInset))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BrandTheme.insetBorder, lineWidth: 1))
    }
}
