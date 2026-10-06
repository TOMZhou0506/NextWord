import SwiftUI

// Show one curated video and its pre-generated English Whisper transcript.
struct VideoView: View {
    private static let videoID = "i21NAHe77UM"
    private static let transcriptResource = "LoLHighlights-full"

    @State private var playerStatus: VideoPlayerStatus = .loading
    @State private var transcript: VideoTranscript?
    @State private var transcriptError: String?

    var body: some View {
        VStack(spacing: 0) {
            YouTubePlayerView(videoID: Self.videoID, status: $playerStatus)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(.black)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text(transcript?.title ?? "League of Legends English commentary")
                        .font(.title2.bold())

                    Text(playerStatus.message)
                        .font(.footnote)
                        .foregroundStyle(playerStatus.colour)

                    Text("English transcript · prepared with Whisper")
                        .font(.headline)

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
                                Text(sentence.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadTranscript() }
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
