import Foundation

// MARK: - What the set-up forms accept
//
// The same rules, limits and wording as the Worker's `src/lib/validate.ts`, so the app refuses what
// the server would, before the round trip. Each check returns a plain-English message for the field,
// or nil when the value is fine. Letters are Unicode letters: O’Brien, Zoë, Nuñez and Łukasz are all
// names. Change a rule here and in the Worker together (and in Android when it gains these forms).

enum InputRules {
    // MARK: Cleaning

    /// Trimmed, with inner runs of spaces and line breaks collapsed to one space.
    static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func letterCount(_ text: String) -> Int { text.filter(\.isLetter).count }

    private static func capital(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    // MARK: Names

    /// A person: letters, spaces, hyphens, apostrophes and full stops; two letters at least.
    static func personName(_ raw: String, required: Bool = false, label: String = "Name") -> String? {
        let name = tidy(raw)
        if name.isEmpty { return required ? "Enter \(label == "Name" ? "a name" : label.lowercased())." : nil }
        if name.count > 80 { return "\(label) is too long — 80 characters at most." }
        if !matches(name, #"^[\p{L}\p{M}][\p{L}\p{M}'’. -]*$"#) || letterCount(name) < 2 {
            return "\(label) can only use letters, spaces, hyphens, apostrophes and full stops."
        }
        return nil
    }

    /// An organisation, home, wing or iPad: letters, numbers, spaces and `& ’ . , ( ) / + : · -`.
    static func businessName(_ raw: String, label: String, required: Bool = false, min: Int = 2, max: Int = 120) -> String? {
        let name = tidy(raw)
        if name.isEmpty { return required ? "Enter \(label)." : nil }
        if name.count < min { return "\(capital(label)) needs at least \(min) characters." }
        if name.count > max { return "\(capital(label)) is too long — \(max) characters at most." }
        if !matches(name, #"^[\p{L}\p{M}\p{N}][\p{L}\p{M}\p{N} &'’.,()/+:·-]*$"#) || letterCount(name) < 1 {
            return "\(capital(label)) can only use letters, numbers, spaces and & ’ . , ( ) / + : · -"
        }
        return nil
    }

    // MARK: Address

    static func addressLine(_ raw: String, label: String = "The address", required: Bool = false) -> String? {
        let line = tidy(raw)
        if line.isEmpty { return required ? "Enter \(label.lowercased())." : nil }
        if line.count < 3 { return "\(label) needs at least 3 characters." }
        if line.count > 120 { return "\(label) is too long — 120 characters at most." }
        if !matches(line, #"^[\p{L}\p{M}\p{N}][\p{L}\p{M}\p{N} ,.'’/#&()-]*$"#) || letterCount(line) < 1 {
            return "\(label) can only use letters, numbers, spaces and , . ’ / # & ( ) -"
        }
        return nil
    }

    static func town(_ raw: String, required: Bool = false) -> String? {
        let town = tidy(raw)
        if town.isEmpty { return required ? "Enter the town." : nil }
        if town.count < 2 { return "The town needs at least 2 letters." }
        if town.count > 60 { return "The town is too long — 60 characters at most." }
        if !matches(town, #"^[\p{L}\p{M}][\p{L}\p{M} .'’-]*$"#) { return "The town can only use letters, spaces, hyphens, apostrophes and full stops." }
        return nil
    }

    /// "sk11aa" → "SK1 1AA"; nil when it isn't a UK postcode.
    static func normalisePostcode(_ raw: String) -> String? {
        let compact = tidy(raw).uppercased().replacingOccurrences(of: " ", with: "")
        guard matches(compact, #"^[A-Z]{1,2}[0-9][A-Z0-9]?[0-9][A-Z]{2}$"#) else { return nil }
        return "\(compact.dropLast(3)) \(compact.suffix(3))"
    }

    static func postcode(_ raw: String, required: Bool = false) -> String? {
        if tidy(raw).isEmpty { return required ? "Enter a postcode like SK1 1AA." : nil }
        return normalisePostcode(raw) == nil ? "A UK postcode looks like SK1 1AA." : nil
    }

    // MARK: Contact details

    /// Expects a trimmed, lowercased address. Ordinary work addresses pass; spaces, a missing dot or a
    /// one-letter ending do not.
    static func isValidEmail(_ email: String) -> Bool {
        email.count <= 254 && matches(email, #"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+([a-z]{2,}|xn--[a-z0-9-]{2,})$"#)
    }

    static func email(_ raw: String, label: String = "a work email address") -> String? {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if email.isEmpty { return "Enter \(label)." }
        return isValidEmail(email) ? nil : "That doesn’t look like an email address. Use name@company.co.uk."
    }

    static func phone(_ raw: String) -> String? {
        let phone = tidy(raw)
        if phone.isEmpty { return nil }
        let digits = phone.filter(\.isNumber).count
        if !matches(phone, #"^\+?[0-9 ()-]+$"#) || digits < 10 || digits > 15 { return "Enter a phone number with 10 to 15 digits, like 0161 000 0000." }
        return nil
    }

    // MARK: Identifiers and numbers

    /// A CQC provider or location id: `1-` and nine or ten digits. Optional.
    static func cqcId(_ raw: String, kind: String) -> String? {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { return nil }
        return matches(id, #"^1-[0-9]{9,10}$"#) ? nil : "A CQC \(kind) ID looks like 1-123456789."
    }

    /// Beds: a whole number from 1 to 2000, or nothing.
    static func beds(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        guard matches(text, #"^[0-9]{1,5}$"#), let n = Int(text), (1 ... 2000).contains(n) else { return "Beds must be a whole number from 1 to 2000." }
        return nil
    }

    /// "https://www.Willow-Care.co.uk/about" → "www.willow-care.co.uk"; what the server expects.
    static func normaliseDomain(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        if text.hasPrefix("@") { text.removeFirst() }
        if let slash = text.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) { text = String(text[..<slash]) }
        while text.hasSuffix(".") { text.removeLast() }
        return text
    }

    static func domain(_ raw: String) -> String? {
        let domain = normaliseDomain(raw)
        if domain.isEmpty { return "Enter a domain like sunrise-care.co.uk." }
        let valid = domain.count >= 3 && domain.count <= 253 && matches(domain, #"^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$"#)
        return valid ? nil : "Enter a domain like sunrise-care.co.uk — just the part after the @."
    }

    // MARK: Free text

    /// Notes: no angle brackets and no hidden characters, so nothing can pose as markup.
    static func freeText(_ raw: String, label: String, max: Int) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if text.count > max { return "\(capital(label)) is too long — \(max) characters at most." }
        let hidden = text.unicodeScalars.contains { $0.properties.generalCategory == .control && $0 != "\n" && $0 != "\t" }
        if text.contains("<") || text.contains(">") || hidden { return "\(capital(label)) can’t contain < or > or hidden characters." }
        return nil
    }

    // MARK: Wings

    /// Every name valid and no two the same (ignoring case).
    static func wings(_ names: [String]) -> String? {
        var seen = Set<String>()
        for raw in names {
            let name = tidy(raw)
            if name.isEmpty { continue }
            if let problem = businessName(name, label: "a wing name", min: 1, max: 40) { return problem }
            if !seen.insert(name.lowercased()).inserted { return "Two wings are called “\(name)”. Give each wing its own name." }
        }
        return nil
    }
}

// MARK: - Keeping typed characters sensible

/// Applied as someone types or pastes, for fields where only some characters can ever be right
/// (digits in a bed count, no spaces in an email). Names and addresses are not filtered: they are
/// checked, with a message, so nothing is silently dropped from what was typed.
enum InputFilter {
    case digits(max: Int)
    case cqcId
    case phone
    case postcode
    case email
    case domain

    /// Applied to every set-up field: angle brackets and hidden control characters have no place in a
    /// name, an address or a note. Line breaks survive only in multi-line fields.
    static func withoutMarkup(_ text: String, allowsLineBreaks: Bool) -> String {
        String(text.unicodeScalars.filter { scalar in
            if scalar == "<" || scalar == ">" { return false }
            if scalar == "\n" || scalar == "\r" { return allowsLineBreaks }
            if scalar == "\t" { return false }
            return scalar.properties.generalCategory != .control
        })
    }

    func apply(_ text: String) -> String {
        switch self {
        case .digits(let max):
            return String(text.filter { $0.isASCII && $0.isNumber }.prefix(max))
        case .cqcId:
            return String(text.filter { ($0.isASCII && $0.isNumber) || $0 == "-" }.prefix(12))
        case .phone:
            return String(text.filter { ($0.isASCII && $0.isNumber) || "+()- ".contains($0) }.prefix(20))
        case .postcode:
            return String(text.uppercased().filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == " " }.prefix(8))
        case .email:
            return String(text.lowercased().filter { !$0.isWhitespace }.prefix(254))
        case .domain:
            return String(text.lowercased().filter { !$0.isWhitespace }.prefix(253))
        }
    }
}
