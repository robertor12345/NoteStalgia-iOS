import Foundation

/// Residents from a spreadsheet export. Columns are matched by header name (`name, room, wing,
/// age | date_of_birth, nationality, favourite_genre, notes`); rows become ordinary
/// `CarePatientProfile`s (`isProvisional: false`) that the existing sync push carries to the backend,
/// so nothing new touches the resident wire shape. Parsing is pure and runs off the main thread.
enum ResidentCSVImport {
    struct Row: Identifiable, Equatable {
        let id = UUID()
        let line: Int
        var name: String
        var room: String
        var wing: CareHomeWing?
        var age: Int?
        var nationality: ResidentNationality
        var genre: ResidentMusicGenre
        var notes: String
        /// Blocking: the row is skipped.
        var problems: [String]
        /// Informational: the row imports with a fallback.
        var warnings: [String]

        var isValid: Bool { problems.isEmpty }
    }

    struct Preview: Equatable {
        var fileName: String
        var home: CareHome
        var rows: [Row]

        var validRows: [Row] { rows.filter(\.isValid) }
        var skippedCount: Int { rows.count - validRows.count }
    }

    static let templateCSV = """
    name,room,wing,age,nationality,favourite_genre,notes
    Margaret Hale,12,Residential,84,United Kingdom,jazz,Loves Ella Fitzgerald
    Desmond Clarke,4,Memory care,79,Jamaica,soul,Sang in a church choir
    Anjali Mehta,7,Residential,88,India,classical,Prefers mornings
    """

    static let ageRange = 55 ... 105

    // MARK: Parse

    static func parse(_ text: String, fileName: String, home: CareHome, existing: [CarePatientProfile]) -> Preview {
        let table = parseCSV(text).filter { row in row.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard !table.isEmpty else { return Preview(fileName: fileName, home: home, rows: []) }

        var columns = columnIndex(header: table[0])
        var dataRows = Array(table.dropFirst())
        var firstLine = 2
        if columns["name"] == nil {
            // No recognisable header: assume the template order.
            columns = ["name": 0, "room": 1, "wing": 2, "age": 3, "nationality": 4, "genre": 5, "notes": 6]
            dataRows = table
            firstLine = 1
        }
        let existingKeys = Set(existing.filter { $0.homeId == home.id && $0.isActive }.map { key(name: $0.displayName, room: $0.roomLabel) })
        var seen = Set<String>()
        var rows: [Row] = []
        for (offset, cells) in dataRows.enumerated() {
            let cell = { (column: String) -> String in
                guard let index = columns[column], index < cells.count else { return "" }
                return cells[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var problems: [String] = []
            var warnings: [String] = []
            let name = InputRules.tidy(cell("name"))
            if name.isEmpty {
                problems.append("Name is missing")
            } else if InputRules.personName(name) != nil {
                problems.append("Name can only use letters, spaces, hyphens, apostrophes and full stops")
            }
            let rawRoom = cell("room")
            let room = normaliseRoom(rawRoom)
            if !rawRoom.isEmpty, rawRoom.count > 20 || rawRoom.range(of: #"^[\p{L}\p{N} ./-]+$"#, options: .regularExpression) == nil {
                problems.append("Room can only use letters, numbers and spaces, up to 20 characters")
            }

            var age = Int(cell("age").filter(\.isWholeNumber))
            if age == nil, let dob = parseDate(cell("dob")) {
                age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year
            }
            if let age, !ageRange.contains(age) {
                problems.append("Age must be \(ageRange.lowerBound)–\(ageRange.upperBound)")
            } else if age == nil {
                problems.append("Age or date of birth is missing")
            }

            let wingText = cell("wing")
            var wing = home.wings.first { $0.id.caseInsensitiveCompare(wingText) == .orderedSame || $0.name.caseInsensitiveCompare(wingText) == .orderedSame }
            if wing == nil {
                wing = home.wings.first
                if !wingText.isEmpty, let fallback = wing { warnings.append("Wing “\(wingText)” not found — using \(fallback.name)") }
                else if wingText.isEmpty, let fallback = wing { warnings.append("No wing given — using \(fallback.name)") }
            }

            let nationalityText = cell("nationality")
            let nationality = parseNationality(nationalityText)
            if nationality == nil, !nationalityText.isEmpty { warnings.append("Nationality “\(nationalityText)” not recognised") }
            let resolvedNationality = nationality ?? .default

            let genreText = cell("genre")
            let genre = parseGenre(genreText)
            if genre == nil, !genreText.isEmpty { warnings.append("Genre “\(genreText)” not recognised — starting from \(resolvedNationality.displayName)’s usual favourites") }
            let resolvedGenre = genre ?? resolvedNationality.preferredGenres.first ?? .classical

            let rowKey = key(name: name, room: room)
            if !name.isEmpty {
                if existingKeys.contains(rowKey) { problems.append("Already on the roster") }
                else if seen.contains(rowKey) { problems.append("Listed twice in this file") }
                seen.insert(rowKey)
            }

            let notes = cell("notes")
            if let problem = InputRules.freeText(notes, label: "notes", max: 200) { problems.append(problem) }
            rows.append(Row(line: firstLine + offset, name: name, room: room, wing: wing, age: age, nationality: resolvedNationality, genre: resolvedGenre, notes: notes, problems: problems, warnings: warnings))
        }
        return Preview(fileName: fileName, home: home, rows: rows)
    }

    /// A roster entry for one valid row, shaped like the ones `saveNewResidentProfile` writes.
    static func profile(from row: Row, home: CareHome) -> CarePatientProfile {
        CarePatientProfile(
            id: UUID(),
            displayName: row.name,
            careContextLabel: "Imported — discovery not yet run",
            likes: row.notes.isEmpty ? [] : [row.notes],
            dislikes: [],
            preferredLight: "Soft, indirect — avoid overhead glare.",
            scentGuidance: "Unscented room unless familiar and agreed.",
            touchComfortNotes: "Ask before touch; go slowly.",
            comfortThemes: [],
            prefersGentleSoundOnsets: true,
            musicTempoBias: 0.35,
            natureVsAbstract: 0.3,
            voiceVsInstrumental: 0.4,
            residentAgeYears: row.age ?? ageRange.lowerBound,
            nationality: row.nationality,
            favouriteMusicGenre: row.genre,
            stockPortraitAssetName: ResidentPortraitCatalog.assetName(displayName: row.name),
            isProvisional: false,
            genrePlaylistGroups: [DiscoveryPlaylistTuning.stubGenreGroup(for: row.genre)],
            homeId: home.id,
            wingId: row.wing?.id ?? home.wings.first?.id ?? CareTenancyMockData.wingResidential,
            roomLabel: row.room,
            isActive: true
        )
    }

    // MARK: Columns and values

    private static func columnIndex(header: [String]) -> [String: Int] {
        var index: [String: Int] = [:]
        for (i, raw) in header.enumerated() {
            let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
            let canonical: String?
            switch key {
            case "name", "resident", "resident_name", "full_name": canonical = "name"
            case "room", "room_number", "room_no", "bed": canonical = "room"
            case "wing", "unit", "area", "floor", "household": canonical = "wing"
            case "age", "age_years": canonical = "age"
            case "date_of_birth", "dob", "birth_date", "birthday", "born": canonical = "dob"
            case "nationality", "country", "country_of_birth", "heritage": canonical = "nationality"
            case "favourite_genre", "favorite_genre", "genre", "music", "favourite_music", "favorite_music": canonical = "genre"
            case "notes", "note", "comments", "comment", "likes": canonical = "notes"
            default: canonical = nil
            }
            if let canonical, index[canonical] == nil { index[canonical] = i }
        }
        return index
    }

    private static func normaliseRoom(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let lower = raw.lowercased()
        if lower.hasPrefix("room") || lower.hasPrefix("rm") { return raw }
        return "Room \(raw)"
    }

    private static func key(name: String, room: String) -> String {
        "\(name.lowercased())|\(room.lowercased())"
    }

    private static let dateFormats = ["yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy", "dd.MM.yyyy", "d MMM yyyy", "d MMMM yyyy"]

    private static func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    static func parseNationality(_ text: String) -> ResidentNationality? {
        let needle = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return nil }
        if let exact = ResidentNationality.allCases.first(where: { $0.displayName.lowercased() == needle || $0.rawValue.lowercased() == needle }) {
            return exact
        }
        switch needle {
        case "uk", "u.k.", "britain", "british", "great britain", "england", "english", "scotland", "scottish", "wales", "welsh", "northern ireland": return .unitedKingdom
        case "irish", "eire", "republic of ireland": return .ireland
        case "indian": return .india
        case "pakistani": return .pakistan
        case "bangladeshi": return .bangladesh
        case "jamaican": return .jamaica
        case "barbadian", "bajan": return .barbados
        case "trinidad", "trinidadian", "tobago": return .trinidadAndTobago
        case "polish": return .poland
        case "italian": return .italy
        case "nigerian": return .nigeria
        case "ghanaian": return .ghana
        case "kenyan": return .kenya
        case "somali": return .somalia
        case "chinese", "hong kong": return .china
        case "filipino", "filipina": return .philippines
        case "usa", "us", "u.s.", "american", "united states of america": return .unitedStates
        case "canadian": return .canada
        case "australian": return .australia
        case "south african": return .southAfrica
        case "german": return .germany
        case "french": return .france
        case "spanish": return .spain
        case "portuguese": return .portugal
        case "ukrainian": return .ukraine
        default: return nil
        }
    }

    static func parseGenre(_ text: String) -> ResidentMusicGenre? {
        let needle = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return nil }
        if let exact = ResidentMusicGenre.allCases.first(where: { $0.rawValue.lowercased() == needle }) { return exact }
        switch needle {
        case "swing", "big band", "blues": return .jazz
        case "opera", "choral", "orchestral": return .classical
        case "easy listening", "oldies", "musicals", "crooners", "vocal": return .pop
        case "rock and roll", "rock & roll", "rock n roll", "rockabilly": return .rock
        case "hymns", "church", "christian", "spiritual": return .gospel
        case "folk", "bluegrass", "country and western", "western": return .country
        case "r&b", "rnb", "motown", "reggae", "ska", "funk", "disco": return .soul
        default: return nil
        }
    }

    // MARK: CSV (RFC 4180-ish: quotes, escaped quotes, CRLF)

    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar? = nil
        func next() -> Unicode.Scalar? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }
        let separator: Unicode.Scalar = text.contains(";") && !text.contains(",") ? ";" : ","
        while let ch = next() {
            if inQuotes {
                if ch == "\"" {
                    if let peek = next() {
                        if peek == "\"" { field.unicodeScalars.append("\"") } else { inQuotes = false; pending = peek }
                    } else { inQuotes = false }
                } else {
                    field.unicodeScalars.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == separator {
                row.append(field); field = ""
            } else if ch == "\n" || ch == "\r" {
                if ch == "\r", let peek = next(), peek != "\n" { pending = peek }
                row.append(field); field = ""
                rows.append(row); row = []
            } else {
                field.unicodeScalars.append(ch)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

