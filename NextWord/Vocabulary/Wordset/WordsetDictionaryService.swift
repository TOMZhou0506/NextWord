import Foundation

// A Wordset entry contains English meanings, but no phonetic or audio fields.
struct WordsetEntry: Decodable, Sendable {
    let word: String
    let meanings: [WordsetMeaning]

    enum CodingKeys: String, CodingKey {
        case word, meanings
    }

    // A few original entries omit meanings; treat them as empty instead of failing the whole file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        meanings = try container.decodeIfPresent([WordsetMeaning].self, forKey: .meanings) ?? []
    }
}

struct WordsetMeaning: Decodable, Sendable {
    let id: String
    let definition: String
    let partOfSpeech: String
    let example: String?
    let synonyms: [String?]?

    enum CodingKeys: String, CodingKey {
        case id, example, synonyms
        case definition = "def"
        case partOfSpeech = "speech_part"
    }
}

enum WordsetDictionaryError: LocalizedError {
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let name): "The offline dictionary file \(name) is missing from the app."
        }
    }
}

// Decode only one first-letter file at a time and reuse it for nearby lookups.
actor WordsetDictionaryService {
    static let shared = WordsetDictionaryService()

    private var loadedGroup: String?
    private var loadedEntries: [String: WordsetEntry] = [:]

    func lookup(_ word: String) throws -> WordsetEntry? {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }

        let first = String(key.prefix(1))
        let group = "abcdefghijklmnopqrstuvwxyz".contains(first) ? first : "misc"
        if loadedGroup != group {
            let name = "Wordset-\(group)"
            // Xcode may flatten synchronized resources into the app bundle's root.
            guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Vocabulary/Wordset")
                ?? Bundle.main.url(forResource: name, withExtension: "json") else {
                throw WordsetDictionaryError.missingFile("\(name).json")
            }
            loadedEntries = try JSONDecoder().decode(
                [String: WordsetEntry].self,
                from: Data(contentsOf: url)
            )
            loadedGroup = group
        }

        // The source contains some capitalized keys; never guess a different word form.
        return loadedEntries[key] ?? loadedEntries.first(where: { $0.key.lowercased() == key })?.value
    }
}
