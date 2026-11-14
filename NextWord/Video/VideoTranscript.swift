import Foundation

// Decode only the fields the video screen needs.
struct VideoTranscript: Decodable {
    let videoID: String
    let title: String
    let clipStart: Double
    let clipEnd: Double
    let sentences: [VideoSentence]

    // Load the bundled transcript and check that it belongs to the video being played.
    static func load(resourceName: String, expectedVideoID: String) throws -> VideoTranscript {
        // Xcode may copy synchronized JSON resources to the app bundle's root.
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Video")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw VideoTranscriptError.missingFile
        }
        let transcript = try JSONDecoder().decode(VideoTranscript.self, from: Data(contentsOf: url))
        guard transcript.videoID == expectedVideoID else {
            throw VideoTranscriptError.videoMismatch
        }
        return transcript
    }
}

struct VideoSentence: Decodable {
    let text: String
    let start: Double
    let end: Double
}

private enum VideoTranscriptError: LocalizedError {
    case missingFile
    case videoMismatch

    var errorDescription: String? {
        switch self {
        case .missingFile: "The prepared transcript is missing from the app."
        case .videoMismatch: "The prepared transcript does not belong to this video."
        }
    }
}
