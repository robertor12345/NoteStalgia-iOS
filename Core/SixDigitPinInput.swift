import SwiftUI

enum PinInputSpec {
    static let digitCount = 6
}

/// Six-digit PIN entry — individual masked cells, single hidden field for keyboard / OTP autofill.
/// Follows segmented PIN input guidance: max 6 digits, masked display, error borders, keyboard focus.
struct SixDigitPinInput<FocusValue: Hashable>: View {
    @Binding var pin: String
    var isError: Bool = false
    var focus: FocusState<FocusValue>.Binding
    var focusValue: FocusValue
    var onComplete: (() -> Void)?
    /// For scripted UI tests (`tools/demo`); the sign-in form uses the default.
    var accessibilityIdentifier: String = "signin.pin"

    private let cellSpacing: CGFloat = 10
    private let cellCornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PIN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
                .accessibilityHidden(true)

            ZStack {
                TextField("", text: binding)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focus, equals: focusValue)
                    .submitLabel(.go)
                    .onSubmit { onComplete?() }
                    .frame(width: 1, height: 1)
                    .opacity(0.02)
                    .accessibilityLabel("Enter your 6-digit PIN")
                    .accessibilityHint("Type six numbers. Digits are hidden as you enter them.")
                    .accessibilityIdentifier(accessibilityIdentifier)

                HStack(spacing: cellSpacing) {
                    ForEach(0 ..< PinInputSpec.digitCount, id: \.self) { index in
                        pinCell(at: index)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focus.wrappedValue = focusValue
                }
            }

            Text("Enter your 6-digit PIN")
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary.opacity(0.9))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PIN")
        .accessibilityValue(pinAccessibilityValue)
    }

    private var binding: Binding<String> {
        Binding(
            get: { pin },
            set: { newValue in
                let sanitized = Self.sanitize(newValue)
                guard sanitized != pin else { return }
                pin = sanitized
                if sanitized.count == PinInputSpec.digitCount {
                    onComplete?()
                }
            }
        )
    }

    private var pinAccessibilityValue: String {
        if pin.isEmpty { return "Empty" }
        return "\(pin.count) of \(PinInputSpec.digitCount) digits entered"
    }

    @ViewBuilder
    private func pinCell(at index: Int) -> some View {
        let digit = digit(at: index)
        let isActive = index == min(pin.count, PinInputSpec.digitCount - 1)
        let strokeColor: Color = {
            if isError { return BrandTheme.nebulaSalmon }
            if isActive { return BrandTheme.gold.opacity(0.82) }
            return BrandTheme.gold.opacity(0.28)
        }()
        let strokeWidth: CGFloat = isError ? 2 : (isActive ? 2 : 1)

        ZStack {
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .fill(BrandTheme.creamMid.opacity(0.95))
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .stroke(strokeColor, lineWidth: strokeWidth)

            if digit != nil {
                Text("•")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .accessibilityLabel("PIN digit \(index + 1)")
        .accessibilityValue(digit == nil ? "Empty" : "Entered")
    }

    private func digit(at index: Int) -> Character? {
        guard index < pin.count else { return nil }
        return pin[pin.index(pin.startIndex, offsetBy: index)]
    }

    private static func sanitize(_ raw: String) -> String {
        String(raw.filter(\.isWholeNumber).prefix(PinInputSpec.digitCount))
    }
}
