import SwiftUI

// Group prepared video lessons by difficulty or interest.
// The list comes from ContentCatalog; recommendations live only on Home.
struct VideoLibraryView: View {
    private enum Grouping: String, CaseIterable {
        case difficulty = "Difficulty"
        case interest = "Interest"
    }

    @State private var grouping: Grouping = .difficulty
    @State private var difficultyFilter = "all"
    @State private var interestFilter = "all"

    private var visibleVideos: [VideoOption] {
        ContentCatalog.videos.filter { video in
            (difficultyFilter == "all" || video.difficulty.rawValue == difficultyFilter) &&
            (interestFilter == "all" || video.interest.rawValue == interestFilter)
        }
    }

    var body: some View {
        List {
            Section("Filters") {
                Picker("Difficulty", selection: $difficultyFilter) {
                    Text("All levels").tag("all")
                    ForEach(VideoDifficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.rawValue).tag(difficulty.rawValue)
                    }
                }
                Picker("Interest", selection: $interestFilter) {
                    Text("All topics").tag("all")
                    ForEach(VideoInterest.allCases, id: \.self) { interest in
                        Text(interest.rawValue).tag(interest.rawValue)
                    }
                }
            }

            Picker("Group videos by", selection: $grouping) {
                ForEach(Grouping.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if visibleVideos.isEmpty {
                Text("No videos match these filters. Try another level or topic.")
                    .foregroundStyle(.secondary)
            }

            if grouping == .difficulty {
                ForEach(VideoDifficulty.allCases, id: \.self) { difficulty in
                    let matches = visibleVideos.filter { $0.difficulty == difficulty }
                    if !matches.isEmpty {
                        Section(difficulty.rawValue) {
                            ForEach(matches) { video in videoRow(video) }
                        }
                    }
                }
            } else {
                ForEach(VideoInterest.allCases, id: \.self) { interest in
                    let matches = visibleVideos.filter { $0.interest == interest }
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
