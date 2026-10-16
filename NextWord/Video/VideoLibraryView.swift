import SwiftUI

// Group prepared video lessons by difficulty or interest.
struct VideoLibraryView: View {
    private enum Grouping: String, CaseIterable {
        case difficulty = "Difficulty"
        case interest = "Interest"
    }

    private enum VideoDifficulty: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }

    private enum VideoInterest: String, CaseIterable {
        case gaming = "Gaming"
        case formulaOne = "F1 Racing"
        case basketball = "Basketball"
        case lifestyle = "Lifestyle"
    }

    @State private var grouping: Grouping = .difficulty

    private let videos = [
        VideoOption(
            id: "i21NAHe77UM",
            title: "The Most GOATED English Caster Calls in League of Legends History",
            source: "LoL Esports",
            transcriptResource: "LoLHighlights-full",
            difficulty: .advanced,
            interest: .gaming
        ),
        VideoOption(
            id: "G2YToseV8aw",
            title: "Max Verstappen's END OF SEASON REVIEW! | Talking Bull",
            source: "Oracle Red Bull Racing",
            transcriptResource: "RedBullTalkingBull-full",
            difficulty: .intermediate,
            interest: .formulaOne
        ),
        VideoOption(
            id: "t6_vawdzRok",
            title: "Why no one guards Steph Curry this way | NBA Finals Game 4 analysis",
            source: "Thinking Basketball",
            transcriptResource: "ThinkingBasketballCurry-full",
            difficulty: .advanced,
            interest: .basketball
        ),
        VideoOption(
            id: "v9QtM6qnG50",
            title: "I Built A City To Save Kids From Illegal Labor",
            source: "MrBeast",
            transcriptResource: "MrBeastCity-full",
            difficulty: .intermediate,
            interest: .lifestyle
        )
    ]

    private struct VideoOption: Identifiable {
        let id: String
        let title: String
        let source: String
        let transcriptResource: String
        let difficulty: VideoDifficulty
        let interest: VideoInterest
    }

    var body: some View {
        List {
            Picker("Group videos by", selection: $grouping) {
                ForEach(Grouping.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if grouping == .difficulty {
                ForEach(VideoDifficulty.allCases, id: \.self) { difficulty in
                    let matches = videos.filter { $0.difficulty == difficulty }
                    if !matches.isEmpty {
                        Section(difficulty.rawValue) {
                            ForEach(matches) { video in videoRow(video) }
                        }
                    }
                }
            } else {
                ForEach(VideoInterest.allCases, id: \.self) { interest in
                    let matches = videos.filter { $0.interest == interest }
                    if !matches.isEmpty {
                        Section(interest.rawValue) {
                            ForEach(matches) { video in videoRow(video) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Videos")
    }

    // Both grouping modes open the same video and timed transcript.
    private func videoRow(_ video: VideoOption) -> some View {
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
}
