import SwiftUI

// Show the selected video and its matching pre-generated Whisper transcript.
struct VideoView: View {
    let videoID: String
    let transcriptResource: String

    @State private var playerStatus: VideoPlayerStatus = .loading
    @State private var playbackTime = 0.0
    @State private var syncStatus = "Connecting to player clock…"
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

    // Match the player's elapsed seconds to the prepared sentence timestamps.
    private var activeSentenceIndex: Int? {
        guard let sentences = transcript?.sentences else { return nil }
        return sentences.indices.first {
            sentences[$0].start <= playbackTime && playbackTime < sentences[$0].end
        }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // In landscape, keep the player and transcript visible side by side.
                let playerWidth = min(geometry.size.width * 0.58, geometry.size.height * 16 / 9)
                HStack(alignment: .top, spacing: 0) {
                    player
                        .frame(width: playerWidth, height: playerWidth * 9 / 16)
                        .clipped()
                    transcriptList
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    player
                        .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                        .clipped()
                    transcriptList
                }
            }
        }
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWord) { selection in
            ArticleWordSheetView(word: selection.text, source: .video)
                .presentationDetents([.medium, .large])
        }
        .task(id: videoID) { loadTranscript() }
    }

    private var player: some View {
        YouTubePlayerView(videoID: videoID, status: $playerStatus,
                          currentTime: $playbackTime, syncStatus: $syncStatus)
            .background(.black)
    }

    private var transcriptList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text(transcript?.title ?? "Video transcript")
                        .font(.title2.bold())

                    if case .failed(let reason) = playerStatus {
                        Text("Player error: \(reason)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

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
                            .padding(.horizontal, 8)
                            .background(index == activeSentenceIndex ? Color.blue.opacity(0.14) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                            .id(index)
                        }
                    } else if let transcriptError {
                        ContentUnavailableView("Transcript unavailable", systemImage: "text.badge.xmark", description: Text(transcriptError))
                    } else {
                        ProgressView("Loading prepared transcript…")
                    }

                    Text("This transcript is bundled with this video and follows its playback time. It is not generated on the phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .onChange(of: activeSentenceIndex) { _, index in
                guard let index else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(index, anchor: .center)
                }
            }
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
        transcript = nil
        transcriptError = nil
        playbackTime = 0
        playerStatus = .loading
        do {
            transcript = try VideoTranscript.load(
                resourceName: transcriptResource,
                expectedVideoID: videoID
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
