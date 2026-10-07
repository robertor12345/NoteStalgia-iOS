import Foundation

/// Individual person-centred profiles for the mock roster. Before this, the 28 generated Maple Lodge
/// residents recycled three templates, so most profiles were word-for-word copies of Elena, James or
/// Sam. Each seed here is one believable person: their own sensory notes, reminiscence anchors,
/// listening preferences and a playlist pair drawn from the audible catalog.
///
/// Deterministic: keyed by first name, built once into `CareTenancyMockData.allPatientsSnapshot`.
/// Track titles come from `ResidentPlaybackTrackCatalog`, so playlists always have bundled audio.
/// Android parity: mirror any change here in the Android mock roster.
struct ResidentProfileSeed {
    let firstName: String
    let age: Int
    let nationality: ResidentNationality
    let favourite: ResidentMusicGenre
    let secondary: ResidentMusicGenre?
    let likes: [String]
    let dislikes: [String]
    let light: String
    let scent: String
    let touch: String
    let themes: [String]
    /// 0 = gentler pacing … 1 = slightly brighter.
    let tempo: Double
    /// 0 = nature-forward … 1 = abstract.
    let nature: Double
    /// 0 = instrumental … 1 = voice-forward.
    let voice: Double
    var gentleOnsets: Bool = true
    /// Display titles for the primary / secondary playlist.
    let playlistTitle: String
    var secondaryPlaylistTitle: String? = nil
}

enum ResidentProfileSeeds {
    static func seed(forFirstName name: String) -> ResidentProfileSeed {
        if let seed = all.first(where: { $0.firstName.caseInsensitiveCompare(name) == .orderedSame }) {
            return seed
        }
        return fallback(name)
    }

    /// Playlist groups with bundled audio: favourite genre first, then the secondary genre.
    static func playlistGroups(for seed: ResidentProfileSeed, residentIndex: Int) -> [CareGenrePlaylistGroup] {
        var groups = [
            CareGenrePlaylistGroup(genre: seed.favourite, playlists: [
                entry(genre: seed.favourite, title: seed.playlistTitle, residentIndex: residentIndex, slot: 1),
            ]),
        ]
        if let secondary = seed.secondary, secondary != seed.favourite {
            groups.append(CareGenrePlaylistGroup(genre: secondary, playlists: [
                entry(
                    genre: secondary,
                    title: seed.secondaryPlaylistTitle ?? "\(secondary.accessibilityLabel) — gentle",
                    residentIndex: residentIndex,
                    slot: 2
                ),
            ]))
        }
        return groups
    }

    /// The titles the carer has seeded as known favourites — the audible stem of each listed genre.
    static func suggestedTitles(for seed: ResidentProfileSeed) -> [String] {
        var genres = [seed.favourite]
        if let secondary = seed.secondary, secondary != seed.favourite { genres.append(secondary) }
        return genres.flatMap { ResidentPlaybackTrackCatalog.titles(for: $0) }
    }

    private static func entry(genre: ResidentMusicGenre, title: String, residentIndex: Int, slot: Int) -> CarePlaylistEntry {
        let titles = ResidentPlaybackTrackCatalog.titles(for: genre)
        return CarePlaylistEntry(
            id: UUID(uuidString: String(format: "dddd%04x-0000-4000-8000-%012x", residentIndex, slot))!,
            title: title,
            trackCount: titles.count,
            durationMinutes: durationMinutes(for: genre),
            trackTitles: titles
        )
    }

    private static func durationMinutes(for genre: ResidentMusicGenre) -> Int {
        switch genre {
        case .jazz, .pop: return 4
        case .gospel: return 2
        case .classical, .rock, .country, .soul: return 3
        }
    }

    private static func fallback(_ name: String) -> ResidentProfileSeed {
        ResidentProfileSeed(
            firstName: name, age: 80, nationality: .unitedKingdom, favourite: .classical, secondary: .soul,
            likes: ["Familiar melodies", "A calm, unhurried pace"],
            dislikes: ["Sudden loud sounds", "Rushed transitions"],
            light: "Soft, indirect light.",
            scent: "Unscented unless they ask.",
            touch: "Ask first; a light hand rest is usually welcome.",
            themes: ["Family", "Home"],
            tempo: 0.4, nature: 0.4, voice: 0.4,
            playlistTitle: "Gentle favourites"
        )
    }

    // MARK: - Maple Lodge (generated roster) and Riverside House

    static let all: [ResidentProfileSeed] = [
        ResidentProfileSeed(
            firstName: "Margaret", age: 88, nationality: .unitedKingdom, favourite: .classical, secondary: .gospel,
            likes: ["Choral music on Sunday mornings", "A cup of tea with the music", "Looking at the garden while listening"],
            dislikes: ["Drums", "Being asked questions over the music", "Doors banging"],
            light: "Morning daylight from the window; close blinds by mid-afternoon.",
            scent: "Lavender hand cream is familiar and welcome.",
            touch: "Likes her hand held once settled; always say her name first.",
            themes: ["Wartime choir", "Allotment roses", "Teaching infants"],
            tempo: 0.3, nature: 0.2, voice: 0.45,
            playlistTitle: "Sunday choir — soft piano",
            secondaryPlaylistTitle: "Hymns she knows the words to"
        ),
        ResidentProfileSeed(
            firstName: "Arthur", age: 91, nationality: .unitedKingdom, favourite: .jazz, secondary: .classical,
            likes: ["Big-band swing kept low", "Tapping along on the armrest", "Humming the brass lines"],
            dislikes: ["Singers he doesn't recognise", "Earphones", "Clapping"],
            light: "Table lamp rather than ceiling light; he squints at glare.",
            scent: "None — strong smells make him cough.",
            touch: "Firm handshake to start, then little touch; he prefers company at arm's length.",
            themes: ["National Service band", "Dance halls in Leeds", "Repairing clocks"],
            tempo: 0.55, nature: 0.6, voice: 0.2,
            playlistTitle: "Swing at low volume",
            secondaryPlaylistTitle: "Strings to settle after"
        ),
        ResidentProfileSeed(
            firstName: "Dorothy", age: 84, nationality: .ireland, favourite: .soul, secondary: .pop,
            likes: ["Warm female vocals", "Songs she can sway to", "Her daughter's visits with music on"],
            dislikes: ["Long instrumental stretches", "Silence between songs", "Cold rooms"],
            light: "Bright but warm; she becomes anxious in dim rooms.",
            scent: "Freshly cut grass or a little rose water on a tissue.",
            touch: "Enjoys a shoulder squeeze and dancing hands; approach from the front.",
            themes: ["Ballroom in Galway", "Raising five children", "Sunday roast with the radio on"],
            tempo: 0.6, nature: 0.35, voice: 0.8,
            playlistTitle: "Warm voices to sway to",
            secondaryPlaylistTitle: "Light pop she sings along to"
        ),
        ResidentProfileSeed(
            firstName: "Harold", age: 79, nationality: .unitedKingdom, favourite: .country, secondary: .rock,
            likes: ["Guitar you can hear every string of", "Storytelling songs", "Looking at photos of the Dales"],
            dislikes: ["Choirs", "Anything 'too slow'", "Being talked over"],
            light: "Daylight; sits by the window given the choice.",
            scent: "Coffee brewing nearby settles him.",
            touch: "Pat on the back is fine; avoid holding his hands — he fidgets with them.",
            themes: ["Driving lorries up the A1", "Rugby league Saturdays", "His border collie Bess"],
            tempo: 0.7, nature: 0.25, voice: 0.6,
            playlistTitle: "Open-road guitar",
            secondaryPlaylistTitle: "Steady rock, nothing shrill"
        ),
        ResidentProfileSeed(
            firstName: "Betty", age: 93, nationality: .unitedKingdom, favourite: .pop, secondary: .soul,
            likes: ["Songs from the sixties", "Mouthing the words", "A blanket over her knees while listening"],
            dislikes: ["Low male voices (hard to hear)", "Sudden endings", "Perfume"],
            light: "Soft lamp light; overhead lights make her close her eyes.",
            scent: "Unscented — perfume gives her a headache.",
            touch: "Welcomes hand-holding; tires quickly, so keep sessions short.",
            themes: ["Working at Woolworths", "Seaside at Scarborough", "Her sister Joyce"],
            tempo: 0.5, nature: 0.4, voice: 0.75,
            playlistTitle: "Sixties she remembers",
            secondaryPlaylistTitle: "Soul, soft and slow"
        ),
        ResidentProfileSeed(
            firstName: "George", age: 86, nationality: .jamaica, favourite: .gospel, secondary: .soul,
            likes: ["Gospel with a steady beat", "Singing the responses", "Sitting near a speaker"],
            dislikes: ["Thin, tinny sound", "Being hurried out of a song", "Fluorescent light"],
            light: "Warm and even; he dislikes flicker.",
            scent: "Nutmeg or cinnamon on a cloth brings back his kitchen.",
            touch: "Holds both your hands to pray along; let him lead.",
            themes: ["Pentecostal choir in Brixton", "Cricket on the radio", "Sunday dinner for twelve"],
            tempo: 0.5, nature: 0.5, voice: 0.85,
            playlistTitle: "Praise he can answer",
            secondaryPlaylistTitle: "Soul from his record shelf"
        ),
        ResidentProfileSeed(
            firstName: "Jean", age: 82, nationality: .unitedKingdom, favourite: .classical, secondary: .jazz,
            likes: ["Solo piano", "Quiet rooms", "Watching rain while the music plays"],
            dislikes: ["Vocals of any kind when tired", "Chairs scraping", "Bright screens"],
            light: "Dim, with the screen brightness turned right down.",
            scent: "A single lavender drop on her cardigan collar.",
            touch: "Prefers no touch until she reaches out; then a steady hand rest.",
            themes: ["Piano lessons as a girl", "Lake District walking holidays", "Librarian for thirty years"],
            tempo: 0.2, nature: 0.15, voice: 0.1,
            playlistTitle: "Solo piano, rain outside",
            secondaryPlaylistTitle: "Late-night jazz, no vocals"
        ),
        ResidentProfileSeed(
            firstName: "Ronald", age: 77, nationality: .unitedKingdom, favourite: .rock, secondary: .country,
            likes: ["Guitar solos", "Air drumming", "Telling you who the band is"],
            dislikes: ["Being corrected", "Classical music ('funeral music')", "Cold hands"],
            light: "Any; he closes his eyes and listens.",
            scent: "Engine oil and leather remind him of his motorbike — a photo works better than a scent.",
            touch: "Fist bump to start; shoulder clap welcome.",
            themes: ["Motorbike rallies", "Working the docks", "Isle of Wight festival"],
            tempo: 0.8, nature: 0.7, voice: 0.55,
            playlistTitle: "Classic rock, warm mix",
            secondaryPlaylistTitle: "Road songs"
        ),
        ResidentProfileSeed(
            firstName: "Patricia", age: 85, nationality: .ireland, favourite: .country, secondary: .gospel,
            likes: ["Fiddle and steel guitar", "Clapping on the beat", "Telling the story behind a song"],
            dislikes: ["Electronic sounds", "Loud brass", "Talking during the chorus"],
            light: "Natural light; a lamp in the evening.",
            scent: "Baking bread or a little vanilla.",
            touch: "Links arms happily; hand on hand while she sings.",
            themes: ["Country dances in Mayo", "The farm kitchen", "Her late husband's accordion"],
            tempo: 0.6, nature: 0.3, voice: 0.7,
            playlistTitle: "Fiddle and steel, gentle",
            secondaryPlaylistTitle: "Hymns from the farm kitchen"
        ),
        ResidentProfileSeed(
            firstName: "Frank", age: 89, nationality: .italy, favourite: .classical, secondary: .pop,
            likes: ["Opera and strings", "Conducting with one finger", "Espresso smell while listening"],
            dislikes: ["Guitars", "Very quiet playback (he can't hear it)", "Being seated with his back to the door"],
            light: "Bright daylight; he reads the room by faces.",
            scent: "Coffee — brew it nearby if you can.",
            touch: "Kisses both cheeks hello; otherwise hands folded, little touch.",
            themes: ["Naples harbour", "Running the café on the high street", "Verdi on Sundays"],
            tempo: 0.45, nature: 0.5, voice: 0.5,
            playlistTitle: "Strings for a Sunday",
            secondaryPlaylistTitle: "Light songs from the café radio"
        ),
        ResidentProfileSeed(
            firstName: "Irene", age: 83, nationality: .unitedKingdom, favourite: .soul, secondary: .jazz,
            likes: ["Soul with a slow groove", "Brushed drums", "Writing in her notebook while listening"],
            dislikes: ["Music that is 'too busy'", "Overhead lights", "Being interrupted mid-song"],
            light: "Soft, indirect — avoid overhead glare.",
            scent: "Unscented room; a mild linen spray if she asks.",
            touch: "Comfortable with a light hand rest; warn before touch.",
            themes: ["Dancing at the Palais", "Teaching needlework", "Letters from her brother at sea"],
            tempo: 0.4, nature: 0.3, voice: 0.6,
            playlistTitle: "Warm vocals, soft band",
            secondaryPlaylistTitle: "50s lounge — brushed drums"
        ),
        ResidentProfileSeed(
            firstName: "Albert", age: 90, nationality: .unitedKingdom, favourite: .pop, secondary: .jazz,
            likes: ["Crooners", "Tapping his cane in time", "Reading the newspaper with music on"],
            dislikes: ["Shouting vocals", "Repetition of the same song", "Cold draughts"],
            light: "Reading lamp over the shoulder; otherwise dim.",
            scent: "Pipe tobacco (unlit) in a tin — familiar and calming.",
            touch: "Handshake only; he values a little formality.",
            themes: ["Newspaper press rooms", "Dancing with Edna", "Allotment competitions"],
            tempo: 0.45, nature: 0.55, voice: 0.6,
            playlistTitle: "Crooners, newspaper hour",
            secondaryPlaylistTitle: "Lounge jazz for the afternoon"
        ),
        ResidentProfileSeed(
            firstName: "Gladys", age: 94, nationality: .unitedKingdom, favourite: .gospel, secondary: .classical,
            likes: ["Hymns she learned at chapel", "A hand to hold", "Birdsong between songs"],
            dislikes: ["Anything with a heavy beat", "Dark rooms", "Being rushed"],
            light: "Light and airy; blinds open.",
            scent: "Rose or sweet pea — her garden flowers.",
            touch: "Reaches for a hand straight away; hold it gently.",
            themes: ["Chapel Sundays", "Her rose garden", "Fifty years married"],
            tempo: 0.2, nature: 0.1, voice: 0.6,
            playlistTitle: "Chapel hymns, very gentle",
            secondaryPlaylistTitle: "Quiet strings for dozing"
        ),
        ResidentProfileSeed(
            firstName: "Stanley", age: 81, nationality: .poland, favourite: .classical, secondary: .country,
            likes: ["Chopin and piano", "Sitting upright to listen", "A map of Kraków on the table"],
            dislikes: ["Vocals in English when tired", "Sudden applause", "Screens too close"],
            light: "Even, warm light; nothing flickering.",
            scent: "Dill or caraway bread.",
            touch: "A hand on the forearm is welcome; speak slowly.",
            themes: ["Kraków conservatoire", "Arriving in Britain in 1947", "Chess in the park"],
            tempo: 0.35, nature: 0.45, voice: 0.2,
            playlistTitle: "Piano, sitting upright",
            secondaryPlaylistTitle: "Gentle guitar he came to like"
        ),
        ResidentProfileSeed(
            firstName: "Rose", age: 87, nationality: .unitedKingdom, favourite: .pop, secondary: .country,
            likes: ["Songs with a chorus", "Clapping", "Her photo album open beside her"],
            dislikes: ["Minor-key music", "Closed curtains", "Whispering"],
            light: "Bright; she likes to see everyone's faces.",
            scent: "Talcum powder — reminds her of her mother.",
            touch: "Loves a cuddle; happily holds hands with anyone.",
            themes: ["Holiday camps in the fifties", "Seven grandchildren", "The village fête"],
            tempo: 0.65, nature: 0.35, voice: 0.75,
            playlistTitle: "Choruses to clap along",
            secondaryPlaylistTitle: "Sunny country"
        ),
        ResidentProfileSeed(
            firstName: "Norman", age: 78, nationality: .unitedKingdom, favourite: .rock, secondary: .pop,
            likes: ["Guitars", "Turning the volume up a notch", "Explaining the lyrics"],
            dislikes: ["Hymns", "Sitting in a circle", "Being called 'Norm'"],
            light: "Low light; he says it feels like a gig.",
            scent: "None.",
            touch: "Not keen; a nod and eye contact work best.",
            themes: ["Record shop on the high street", "Seeing bands in Manchester", "His vinyl collection"],
            tempo: 0.75, nature: 0.65, voice: 0.5,
            playlistTitle: "Gig volume, minus one notch",
            secondaryPlaylistTitle: "Pop he grudgingly likes"
        ),
        ResidentProfileSeed(
            firstName: "Audrey", age: 86, nationality: .unitedKingdom, favourite: .jazz, secondary: .soul,
            likes: ["Smoky saxophone", "A single candle-style lamp", "Her shawl around her shoulders"],
            dislikes: ["Bright lights", "Fast tempos", "Crowded rooms"],
            light: "Dim, one warm lamp.",
            scent: "Jasmine, lightly.",
            touch: "A hand on the shoulder from the side; she startles from behind.",
            themes: ["Jazz clubs in Soho", "Dressmaking", "Dancing with her husband in the kitchen"],
            tempo: 0.3, nature: 0.6, voice: 0.4,
            playlistTitle: "Smoky sax, one lamp on",
            secondaryPlaylistTitle: "Slow soul to finish"
        ),
        ResidentProfileSeed(
            firstName: "Cyril", age: 92, nationality: .unitedKingdom, favourite: .country, secondary: .classical,
            likes: ["Steel guitar", "Looking out at the fields", "Wearing his flat cap indoors"],
            dislikes: ["Saxophone", "Talk radio", "Having his cap taken off"],
            light: "Daylight by the window.",
            scent: "Hay or cut grass if you can find it.",
            touch: "Handshake and a hand on the shoulder; nothing more.",
            themes: ["Dairy farming", "Market day", "His tractor"],
            tempo: 0.4, nature: 0.1, voice: 0.5,
            playlistTitle: "Steel guitar, fields outside",
            secondaryPlaylistTitle: "Quiet strings for dusk"
        ),
        ResidentProfileSeed(
            firstName: "Muriel", age: 89, nationality: .unitedKingdom, favourite: .soul, secondary: .gospel,
            likes: ["Harmony vocals", "Humming the bass line", "A warm drink in both hands"],
            dislikes: ["Instrumental-only music", "Chilly rooms", "Being seated alone"],
            light: "Warm, medium — not too bright.",
            scent: "Cocoa.",
            touch: "Enjoys her hair being brushed while listening.",
            themes: ["Singing in a trio with her sisters", "Church socials", "Nursing in the sixties"],
            tempo: 0.45, nature: 0.4, voice: 0.9,
            playlistTitle: "Three-part harmonies",
            secondaryPlaylistTitle: "Gospel for the evening"
        ),
        ResidentProfileSeed(
            firstName: "Keith", age: 74, nationality: .unitedKingdom, favourite: .pop, secondary: .rock,
            likes: ["Eighties pop", "Playing air keyboard", "Telling you where he was when a song came out"],
            dislikes: ["Classical", "Nature sounds ('what is that noise')", "Patronising tone"],
            light: "Normal room light.",
            scent: "None.",
            touch: "High-five on arrival; otherwise hands off.",
            themes: ["Running a pub", "Spain holidays", "Coaching the under-11s"],
            tempo: 0.7, nature: 0.8, voice: 0.6,
            playlistTitle: "Eighties, air keyboard",
            secondaryPlaylistTitle: "Pub jukebox rock"
        ),
        ResidentProfileSeed(
            firstName: "Joan", age: 84, nationality: .jamaica, favourite: .soul, secondary: .gospel,
            likes: ["Soul with a smile in it", "Swaying in her chair", "Her Sunday hat on the side table"],
            dislikes: ["Thin speakers", "Rushed goodbyes", "Grey light"],
            light: "Warm and bright.",
            scent: "Coconut oil — familiar from her hair routine.",
            touch: "Hugs; both hands held while she sings.",
            themes: ["Arriving at Tilbury", "Church choir in Birmingham", "Dominoes with the neighbours"],
            tempo: 0.55, nature: 0.45, voice: 0.85,
            playlistTitle: "Soul with a smile",
            secondaryPlaylistTitle: "Choir songs she leads"
        ),
        ResidentProfileSeed(
            firstName: "Raymond", age: 80, nationality: .unitedKingdom, favourite: .jazz, secondary: .classical,
            likes: ["Trumpet", "Nodding slowly to the beat", "Black-and-white photographs"],
            dislikes: ["Vocals", "Over-bright rooms", "Being asked how he feels"],
            light: "Low lamp light.",
            scent: "Shoe polish — his army days; a photo of his unit works too.",
            touch: "Formal; handshake only, say 'Mr V.' first.",
            themes: ["Army bandsman", "Photography darkroom", "Walking the Pennine Way"],
            tempo: 0.35, nature: 0.55, voice: 0.1,
            playlistTitle: "Trumpet, lamps low",
            secondaryPlaylistTitle: "Orchestral for after"
        ),
        ResidentProfileSeed(
            firstName: "Ethel", age: 95, nationality: .unitedKingdom, favourite: .classical, secondary: .pop,
            likes: ["Very gentle piano", "Her cat Tilly's photo", "A blanket tucked in"],
            dislikes: ["Any sudden sound", "Cold hands", "Too many people"],
            light: "Dim and warm.",
            scent: "Lavender pillow spray.",
            touch: "Light hand rest; she may fall asleep — that is fine.",
            themes: ["Making hats", "Her cats", "Dancing at the Tower Ballroom"],
            tempo: 0.15, nature: 0.2, voice: 0.3,
            playlistTitle: "Piano for dozing",
            secondaryPlaylistTitle: "Soft songs she hums"
        ),
        ResidentProfileSeed(
            firstName: "Leslie", age: 76, nationality: .unitedKingdom, favourite: .rock, secondary: .jazz,
            likes: ["Guitar-led rock", "Drumming his knees", "Band T-shirts"],
            dislikes: ["Gospel", "Perfumed rooms", "Low volume"],
            light: "Any; dislikes blinds fully closed.",
            scent: "None.",
            touch: "Pat on the arm; not a hugger.",
            themes: ["Roadie in the seventies", "Fixing amplifiers", "Brighton seafront"],
            tempo: 0.75, nature: 0.7, voice: 0.5,
            playlistTitle: "Guitar rock, knees drumming",
            secondaryPlaylistTitle: "Late-night jazz to wind down"
        ),
        ResidentProfileSeed(
            firstName: "Phyllis", age: 88, nationality: .unitedKingdom, favourite: .country, secondary: .pop,
            likes: ["Harmonies", "Telling you the lyrics before they come", "Knitting while listening"],
            dislikes: ["Trumpets", "Talking during songs", "Dark rooms"],
            light: "Bright enough to knit by.",
            scent: "Clean washing.",
            touch: "Happy to hold hands; tires if the session runs long.",
            themes: ["Land girl on a Norfolk farm", "WI baking", "Her twin sister"],
            tempo: 0.5, nature: 0.2, voice: 0.7,
            playlistTitle: "Harmonies while knitting",
            secondaryPlaylistTitle: "Cheerful songs for the afternoon"
        ),
        ResidentProfileSeed(
            firstName: "Bernard", age: 83, nationality: .unitedKingdom, favourite: .classical, secondary: .jazz,
            likes: ["Full orchestras", "Closing his eyes for the strings", "Programme notes read aloud"],
            dislikes: ["Pop", "Interruptions", "Dry air"],
            light: "Low; he conducts in the half-dark.",
            scent: "Old books — a hardback on his lap helps.",
            touch: "Handshake; a hand on the shoulder when a piece ends.",
            themes: ["Schoolmaster", "Concerts at the Free Trade Hall", "Stamp collecting"],
            tempo: 0.3, nature: 0.6, voice: 0.15,
            playlistTitle: "Orchestral, eyes closed",
            secondaryPlaylistTitle: "Jazz piano for the evening"
        ),
        ResidentProfileSeed(
            firstName: "Winifred", age: 90, nationality: .unitedKingdom, favourite: .gospel, secondary: .soul,
            likes: ["Hymns with a swing", "Raising her hands", "Her Bible on her lap"],
            dislikes: ["Rock guitars", "Cold rooms", "Being left mid-song"],
            light: "Warm, medium.",
            scent: "Polish — she kept the chapel brass.",
            touch: "Both hands; she will squeeze back.",
            themes: ["Chapel caretaker", "Sunday school outings", "Her brother's tenor voice"],
            tempo: 0.5, nature: 0.35, voice: 0.85,
            playlistTitle: "Hymns with a swing",
            secondaryPlaylistTitle: "Soul from the Sunday social"
        ),
        ResidentProfileSeed(
            firstName: "Gordon", age: 85, nationality: .unitedKingdom, favourite: .country, secondary: .classical,
            likes: ["Guitar and a slow story", "The window open a crack", "Whittling (supervised)"],
            dislikes: ["Saxophone", "Hurrying", "Loud laughter nearby"],
            light: "Daylight; a lamp after four.",
            scent: "Pine or wood shavings.",
            touch: "A pat on the hand; let him set the pace.",
            themes: ["Forestry work", "Sailing on Windermere", "Building a dinghy with his son"],
            tempo: 0.35, nature: 0.1, voice: 0.45,
            playlistTitle: "Slow story, open window",
            secondaryPlaylistTitle: "Strings for the lake"
        ),
        // Riverside House
        ResidentProfileSeed(
            firstName: "Helen", age: 78, nationality: .unitedKingdom, favourite: .classical, secondary: .jazz,
            likes: ["Cello", "Fresh air during a session", "Her reading glasses within reach"],
            dislikes: ["Pop", "Clutter", "Being talked down to"],
            light: "Soft daylight.",
            scent: "Fresh coffee.",
            touch: "Handshake; a light touch on the arm once she knows you.",
            themes: ["Hospital pharmacist", "Walking in the Cotswolds", "Chamber concerts"],
            tempo: 0.3, nature: 0.3, voice: 0.15,
            playlistTitle: "Cello by the window",
            secondaryPlaylistTitle: "Quiet jazz"
        ),
        ResidentProfileSeed(
            firstName: "Peter", age: 79, nationality: .ireland, favourite: .country, secondary: .pop,
            likes: ["Guitar songs", "Singing the chorus", "A hurling match on mute"],
            dislikes: ["Classical", "Silence", "Being still too long"],
            light: "Bright.",
            scent: "Turf smoke — a photo of the home fire works.",
            touch: "Arm around the shoulder; he reciprocates.",
            themes: ["Hurling for Kilkenny", "Building sites in Birmingham", "The pub quiz"],
            tempo: 0.65, nature: 0.4, voice: 0.7,
            playlistTitle: "Chorus songs, guitar",
            secondaryPlaylistTitle: "Pub-radio favourites"
        ),
        ResidentProfileSeed(
            firstName: "Grace", age: 80, nationality: .unitedKingdom, favourite: .soul, secondary: .classical,
            likes: ["Soul ballads", "Candle-style lamp", "Her sketchbook open"],
            dislikes: ["Shrill sounds", "Overhead lights", "Being hurried"],
            light: "Dim and warm.",
            scent: "Oil paint — a tube to hold, not opened.",
            touch: "Hand rest once invited.",
            themes: ["Art college", "Painting the Thames", "Her studio cat"],
            tempo: 0.35, nature: 0.5, voice: 0.6,
            playlistTitle: "Ballads, sketchbook open",
            secondaryPlaylistTitle: "Strings while she draws"
        ),
        ResidentProfileSeed(
            firstName: "David", age: 81, nationality: .ireland, favourite: .jazz, secondary: .rock,
            likes: ["Double bass", "Finger-snapping", "A whiskey tumbler of water"],
            dislikes: ["Hymns", "Low volume", "Fuss"],
            light: "Low.",
            scent: "None.",
            touch: "Handshake; he likes a bit of banter more than touch.",
            themes: ["Showband drummer", "Driving taxis in Dublin", "Greyhound racing"],
            tempo: 0.6, nature: 0.7, voice: 0.3,
            playlistTitle: "Double bass, finger snaps",
            secondaryPlaylistTitle: "Rock from the showband days"
        ),
        ResidentProfileSeed(
            firstName: "Mary", age: 82, nationality: .unitedKingdom, favourite: .gospel, secondary: .pop,
            likes: ["Hymns", "Holding a rosary", "A shawl over her shoulders"],
            dislikes: ["Loud guitars", "Cold", "Being rushed"],
            light: "Warm lamp light.",
            scent: "Beeswax candle (unlit).",
            touch: "Holds your hand throughout.",
            themes: ["Convent school", "Her five brothers", "The Christmas crib"],
            tempo: 0.3, nature: 0.25, voice: 0.7,
            playlistTitle: "Hymns with her rosary",
            secondaryPlaylistTitle: "Gentle songs from the radio"
        ),
        ResidentProfileSeed(
            firstName: "John", age: 83, nationality: .ireland, favourite: .rock, secondary: .country,
            likes: ["Guitar rock at a steady pace", "Tapping his foot", "Football scores read out"],
            dislikes: ["Opera", "Dim rooms", "Being asked to sing"],
            light: "Bright.",
            scent: "Cut grass.",
            touch: "Handshake, shoulder clap.",
            themes: ["Playing in a wedding band", "Gaelic football", "Fixing cars with his brother"],
            tempo: 0.65, nature: 0.45, voice: 0.5,
            playlistTitle: "Steady rock, foot tapping",
            secondaryPlaylistTitle: "Country for the drive home"
        ),
    ]
}
