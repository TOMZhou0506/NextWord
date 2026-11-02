import Foundation

// Translate one English word for the review card; dictionary details come later.
// Preparing for the DeepL Translation Service: Configure the network connection, and define how to read
// the key, send requests, and receive responses
enum ReviewTranslationService {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        return URLSession(configuration: configuration)
    }()

    private struct LocalSecrets: Decodable {
        let deeplAPIKey: String

        enum CodingKeys: String, CodingKey {
            case deeplAPIKey = "DeepLAPIKey"
        }
    }

    private struct RequestBody: Encodable {
        let text: [String]
        let source_lang = "EN"
        let target_lang = "ZH"
    }

    private struct ResponseBody: Decodable {
        struct Translation: Decodable {
            let text: String
        }
        let translations: [Translation]
    }
//translate reads the API key, sends a POST request with the word as JSON, waits for the response without
//blocking the UI
    static func translate(_ word: String) async throws -> String {
        guard let secretsURL = Bundle.main.url(forResource: "LocalSecrets", withExtension: "plist"),
              let secrets = try? PropertyListDecoder().decode(LocalSecrets.self, from: Data(contentsOf: secretsURL)) else {
            throw TranslationError.missingKey
        }
        let apiKey = secrets.deeplAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_KEY_HERE" else {
            throw TranslationError.missingKey
        }

        let url = URL(string: "https://api-free.deepl.com/v2/translate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(text: [word]))

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw TranslationError.httpStatus(response.statusCode)
        }
        guard let translation = try JSONDecoder().decode(ResponseBody.self, from: data).translations.first else {
            throw TranslationError.emptyResult
        }
        return translation.text
    }

    // TranslationError lists every failure with a readable message
    private enum TranslationError: LocalizedError {
        case missingKey
        case invalidResponse
        case emptyResult
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .missingKey: "Add your DeepL key to the local LocalSecrets.plist and rebuild the app."
            case .invalidResponse: "DeepL returned an invalid response."
            case .emptyResult: "DeepL returned no translation."
            case .httpStatus(403): "DeepL rejected the API key (HTTP 403)."
            case .httpStatus(429): "Too many translation requests (HTTP 429)."
            case .httpStatus(456): "DeepL usage limit reached (HTTP 456)."
            case .httpStatus(let status): "DeepL request failed (HTTP \(status))."
            }
        }
    }
}
