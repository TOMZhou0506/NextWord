import SwiftUI

// Let the learner choose a video with its matching prepared transcript.
struct VideoLibraryView: View {
    private let videos = [
        VideoOption(
            id: "i21NAHe77UM",
            title: "The Most GOATED English Caster Calls in League of Legends History",
            source: "LoL Esports",
            transcriptResource: "LoLHighlights-full"
        ),
        VideoOption(
            id: "G2YToseV8aw",
            title: "Max Verstappen's END OF SEASON REVIEW! | Talking Bull",
            source: "Oracle Red Bull Racing",
            transcriptResource: "RedBullTalkingBull-full"
        ),
        VideoOption(
            id: "t6_vawdzRok",
            title: "Why no one guards Steph Curry this way | NBA Finals Game 4 analysis",
            source: "Thinking Basketball",
            transcriptResource: "ThinkingBasketballCurry-full"
        )
    ]

    private struct VideoOption: Identifiable {
        let id: String
        let title: String
        let source: String
        let transcriptResource: String
    }

    var body: some View {
        List(videos) { video in
            NavigationLink {
                VideoView(videoID: video.id, transcriptResource: video.transcriptResource)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title)
                            .font(.headline)
                        Text(video.source)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Videos")
    }
}
