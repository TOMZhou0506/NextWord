import SwiftUI

// Show one curated video and its pre-generated English Whisper transcript.
struct VideoView: View {
    private static let videoID = "i21NAHe77UM"
    private static let transcriptResource = "LoLHighlights-full"

    @State private var playerStatus: VideoPlayerStatus = .loading
    @State private var transcript: VideoTranscript?
    @State private var transcriptError: String?
    @State private var selectedWord: SelectedVideoWord?

    private struct SelectedVideoWord: Identifiable {
        let id = UUID()
        let text: String
    }

    // Use the same word boundaries as the article reader.
    private static let wordPattern = try! NSRegularExpression(
        pattern: #"[A-Za-z]+(?:['’\-][A-Za-z]+)*"#
    )

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // In landscape, keep the player and transcript visible side by side.
                let playerWidth = min(geometry.size.width * 0.58, geometry.size.height * 16 / 9)
                HStack(alignment: .top, spacing: 0) {
                    player
                        .frame(width: playerWidth, height: playerWidth * 9 / 16)
                    transcriptList
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    player
                        .aspectRatio(16 / 9, contentMode: .fit)
                    transcriptList
                }
            }
        }
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWord) { selection in
            ArticleWordSheetView(word: selection.text)
                .presentationDetents([.medium, .large])
        }
        .task { loadTranscript() }
    }

    private var player: some View {
        YouTubePlayerView(videoID: Self.videoID, status: $playerStatus)
            .background(.black)
    }

    private var transcriptList: some View {
        ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text(transcript?.title ?? "League of Legends English commentary")
                        .font(.title2.bold())

                    Text(playerStatus.message)
                        .font(.footnote)
                        .foregroundStyle(playerStatus.colour)

                    Text("English transcript · prepared with Whisper")
                        .font(.headline)

                    Text("Tap a word in the transcript to look it up and save it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let transcript {
                        Text("\(formatTime(transcript.clipStart))–\(formatTime(transcript.clipEnd)) · \(transcript.sentences.count) sentences")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(transcript.sentences.indices, id: \.self) { index in
                            let sentence = transcript.sentences[index]
                            HStack(alignment: .top, spacing: 12) {
                                Text(formatTime(sentence.start))
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(.blue)
                                Text(linkedSentence(sentence.text))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .environment(\.openURL, OpenURLAction { url in
                                        guard url.scheme == "nextword", url.host == "lookup",
                                              let word = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                                .queryItems?.first(where: { $0.name == "word" })?.value else {
                                            return .systemAction
                                        }
                                        selectedWord = SelectedVideoWord(text: word)
                                        return .handled
                                    })
                            }
                            .padding(.vertical, 5)
                        }
                    } else if let transcriptError {
                        ContentUnavailableView("Transcript unavailable", systemImage: "text.badge.xmark", description: Text(transcriptError))
                    } else {
                        ProgressView("Loading prepared transcript…")
                    }

                    Text("This transcript is bundled with this specific video. It is not generated on the phone or synchronized to playback yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }

    // Preserve punctuation while giving each English word its own tap target.
    private func linkedSentence(_ sentence: String) -> AttributedString {
        var result = AttributedString()
        var cursor = sentence.startIndex
        let matches = Self.wordPattern.matches(
            in: sentence,
            range: NSRange(sentence.startIndex..<sentence.endIndex, in: sentence)
        )

        for match in matches {
            guard let range = Range(match.range, in: sentence) else { continue }
            result += AttributedString(String(sentence[cursor..<range.lowerBound]))

            let token = String(sentence[range])
            var linkedWord = AttributedString(token)
            var destination = URLComponents()
            destination.scheme = "nextword"
            destination.host = "lookup"
            destination.queryItems = [URLQueryItem(name: "word", value: token)]
            linkedWord.link = destination.url
            linkedWord.foregroundColor = .primary
            result += linkedWord
            cursor = range.upperBound
        }

        result += AttributedString(String(sentence[cursor...]))
        return result
    }

    private func loadTranscript() {
        guard transcript == nil else { return }
        do {
            transcript = try VideoTranscript.load(
                resourceName: Self.transcriptResource,
                expectedVideoID: Self.videoID
            )
            transcriptError = nil
        } catch {
            transcriptError = error.localizedDescription
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let wholeSeconds = max(0, Int(seconds))
        return String(format: "%02d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }
}
