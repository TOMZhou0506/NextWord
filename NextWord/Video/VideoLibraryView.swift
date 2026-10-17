import SwiftUI

// Group prepared video lessons by difficulty or interest.
struct VideoLibraryView: View {
    @AppStorage("learningQuestionnaireCompleted_v1") private var hasPreferences = false
    @AppStorage("englishLevel_v2") private var surveyLevel = 0
    // The 1–5 survey level as a content difficulty, e.g. "intermediate".
    private var englishLevel: String { RecommendationRules.difficulty(forLevel: surveyLevel) }
    @AppStorage("videoInterests_v1") private var savedInterests = ""

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

        var preferenceKey: String {
            switch self {
            case .gaming: "gaming"
            case .formulaOne: "f1"
            case .basketball: "basketball"
            case .lifestyle: "lifestyle"
            }
        }
    }

    @State private var grouping: Grouping = .difficulty
    @State private var difficultyFilter = "all"
    @State private var interestFilter = "all"

    private let videos = [
        VideoOption(
            id: "heycg7D5VZw",
            title: "Lesson 1: Welcome!",
            source: "VOA Learning English",
            transcriptResource: "VOAWelcome-full",
            difficulty: .beginner,
            interest: .lifestyle
        ),
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

    private var preferredInterests: Set<String> {
        Set(savedInterests.split(separator: ",").map(String.init)).subtracting(["none"])
    }

    private var visibleVideos: [VideoOption] {
        videos.filter { video in
            (difficultyFilter == "all" || video.difficulty.rawValue == difficultyFilter) &&
            (interestFilter == "all" || video.interest.rawValue == interestFilter)
        }
    }

    // Level is the first priority; matching interests break ties within a level.
    private var recommendedVideos: [VideoOption] {
        guard hasPreferences else { return [] }
        return Array(visibleVideos
            .filter { RecommendationRules.distance(level: englishLevel, content: $0.difficulty.rawValue) != nil }
            .sorted { first, second in
                let firstDistance = RecommendationRules.distance(level: englishLevel, content: first.difficulty.rawValue) ?? 3
                let secondDistance = RecommendationRules.distance(level: englishLevel, content: second.difficulty.rawValue) ?? 3
                if firstDistance != secondDistance { return firstDistance < secondDistance }
                let firstInterest = preferredInterests.contains(first.interest.preferenceKey)
                let secondInterest = preferredInterests.contains(second.interest.preferenceKey)
                if firstInterest != secondInterest { return firstInterest }
                return first.title < second.title
            }
            .prefix(2))
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

            if !recommendedVideos.isEmpty {
                Section("For you") {
                    ForEach(recommendedVideos) { video in
                        videoRow(video, reason: recommendationReason(for: video))
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

    private func recommendationReason(for video: VideoOption) -> String {
        let levelReason = RecommendationRules.reason(level: englishLevel, content: video.difficulty.rawValue)
        // Name the topic the learner picked in the survey, e.g. "You like Basketball".
        let interestReason = preferredInterests.contains(video.interest.preferenceKey) ? " · You like \(video.interest.rawValue)" : ""
        return "\(levelReason)\(interestReason)"
    }

    // Both grouping modes open the same video and timed transcript.
    private func videoRow(_ video: VideoOption, reason: String? = nil) -> some View {
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
                    if let reason {
                        Text(reason)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    Text(video.source)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }
}
