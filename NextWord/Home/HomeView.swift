import Charts
import SwiftData
import SwiftUI

// Home answers "what about today?": the streak first, then today's task,
// something to read or watch, and a short look at progress.
struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @Query private var words: [SavedWord]
    @Query private var events: [StudyEvent]
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @State private var isReviewPresented = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return authService.displayName.isEmpty ? part : "\(part), \(authService.displayName)"
    }

    var body: some View {
        // Build the history once and share it with every section.
        let history = StudyHistory(events: events)
        let plan = ReviewPlan.words(from: words, limit: reviewLimit)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(greeting)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                StreakCard(history: history)
                TodayTaskCard(planCount: plan.count, reviewedToday: history.reviewsToday) {
                    isReviewPresented = true
                }
                ForYouSection()
                LearningRecordPreview(words: words, history: history)
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("NextWord")
        .toolbar {
            NavigationLink { VocabularySearchView() } label: { Image(systemName: "magnifyingglass") }
                .accessibilityLabel("Look up a word")
        }
        .fullScreenCover(isPresented: $isReviewPresented) {
            VocabularyReviewView(words: plan)
        }
    }
}

// MARK: - Streak

// The most important number on Home: how many days in a row the learner has kept going.
private struct StreakCard: View {
    let history: StudyHistory

    private var message: String {
        if history.currentStreak == 0 { return "Start a streak today: review or save a word." }
        return history.studiedToday ? "You've learned today. See you tomorrow!" : "Review today to keep it going."
    }

    var body: some View {
        let streak = history.currentStreak
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // The flame bird when there's a streak; the sleeping bird waits for the first day.
                BirdMascot(pose: streak > 0 ? .flame : .sleeping, size: 84)
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak.counted("day"))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("Your learning streak · best \(history.bestStreak)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(message).font(.subheadline)

            HStack {
                ForEach(history.thisWeek, id: \.self) { day in
                    WeekDayDot(day: day, studied: history.studied(on: day))
                        .frame(maxWidth: .infinity)
                }
            }

            NavigationLink { LearningInsightsView() } label: {
                Label("See calendar", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .homeCard()
    }
}

private struct WeekDayDot: View {
    let day: Date
    let studied: Bool

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        VStack(spacing: 4) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ZStack {
                // Green with a tick means "done", matching the finished daily task.
                Circle().fill(studied ? Color.green : Color(.tertiarySystemFill))
                if studied {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                }
            }
            .frame(width: 30, height: 30)
            // Today gets a blue ring, studied or not.
            .overlay { if isToday { Circle().stroke(.blue, lineWidth: 2) } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(studied ? "studied" : "not studied")")
    }
}

// MARK: - Today's task

// The review plan turned into a daily task: "Review N words", with today's progress.
private struct TodayTaskCard: View {
    let planCount: Int
    let reviewedToday: Int
    let startReview: () -> Void

    private var isDone: Bool { planCount > 0 && reviewedToday >= planCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's task").font(.title3.bold())

            if planCount == 0 {
                BirdMessage(pose: .sleeping, title: "Nothing to review right now",
                            message: "Save words from articles and videos to get today's task.", birdSize: 80)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isDone ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review \(planCount.counted("word"))").font(.headline)
                        Text("\(min(reviewedToday, planCount)) of \(planCount) done today")
                            .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                    if isDone { BirdMascot(pose: .celebrate, size: 60, popsIn: true) }
                }
                ProgressView(value: Double(min(reviewedToday, planCount)), total: Double(planCount))
                    .tint(isDone ? .green : .blue)
                Button(action: startReview) {
                    Text(isDone ? "Review again" : "Start review").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .homeCard()
    }
}

// MARK: - For you

// One article and one video picked from the survey answers. Recommendations live only here.
private struct ForYouSection: View {
    @AppStorage("learningQuestionnaireCompleted_v1") private var hasPreferences = false
    @AppStorage("englishLevel_v2") private var surveyLevel = 0
    @AppStorage("videoInterests_v1") private var savedInterests = ""
    @State private var articles: [ArticleItem] = []

    private var level: String { RecommendationRules.difficulty(forLevel: surveyLevel) }
    private var interests: Set<String> { RecommendationRules.interests(from: savedInterests) }

    // Recommendations need a finished survey with a valid 1–5 level.
    private var hasValidLevel: Bool { hasPreferences && (1...5).contains(surveyLevel) }

    var body: some View {
        let article = hasValidLevel ? RecommendationRules.recommendedArticle(from: articles, level: level) : nil
        let video = hasValidLevel
            ? RecommendationRules.recommendedVideo(from: ContentCatalog.videos, level: level, interests: interests)
            : nil
        // Safety net: never show an empty section. If nothing can be picked, invite the survey instead.
        let hasPicks = article != nil || video != nil

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("For you").font(.title3.bold())
                Spacer()
                if hasPicks {
                    Text("Based on your survey").font(.caption).foregroundStyle(.secondary)
                }
            }

            if hasPicks {
                // Side by side when they fit; stacked at large text sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { cards(article: article, video: video) }
                    VStack(spacing: 12) { cards(article: article, video: video) }
                }
            } else {
                NavigationLink { LearningPreferencesIntroView() } label: {
                    HStack(spacing: 12) {
                        BirdMascot(pose: .wave, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get recommendations").font(.headline)
                            Text("Take the learning survey so we can pick articles and videos for you.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .homeCard()
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            if articles.isEmpty { articles = (try? ContentCatalog.loadArticles()) ?? [] }
        }
    }

    @ViewBuilder private func cards(article: ArticleItem?, video: VideoOption?) -> some View {
        if let article {
            NavigationLink { ArticleReaderView(resourceName: article.resourceName) } label: {
                RecommendationCard(symbol: "doc.text.fill", kind: "Article", title: article.article.title,
                                   reason: RecommendationRules.reason(level: level, content: article.article.difficulty.rawValue))
            }
            .buttonStyle(.plain)
        }
        if let video {
            NavigationLink { VideoView(videoID: video.id, transcriptResource: video.transcriptResource) } label: {
                RecommendationCard(symbol: "play.rectangle.fill", kind: "Video", title: video.title,
                                   reason: RecommendationRules.videoReason(for: video, level: level, interests: interests))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RecommendationCard: View {
    let symbol: String
    let kind: String
    let title: String
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(kind, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }
}

// MARK: - Learning record

// A short preview of the Learning insights page: three numbers and the five colours.
private struct LearningRecordPreview: View {
    let words: [SavedWord]
    let history: StudyHistory

    private var accuracyText: String {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let recent = history.reviews(since: start)
        guard !recent.isEmpty else { return "–" }
        let correct = recent.filter { $0.wasCorrect == true }.count
        return "\(Int((Double(correct) / Double(recent.count) * 100).rounded()))%"
    }

    private var stageCounts: [(stage: LearningStage, count: Int)] {
        LearningStage.allCases.map { stage in (stage, words.filter { $0.stage == stage }.count) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your learning record").font(.title3.bold())
                Spacer()
                NavigationLink { LearningInsightsView() } label: {
                    Text("See all").font(.subheadline.weight(.semibold))
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    recordNumber(words.count.formatted(), "Words")
                    recordNumber(words.filter { $0.stage == .mastered }.count.formatted(), "Mastered")
                    recordNumber(accuracyText, "Accuracy · 7 days")
                }

                if !words.isEmpty {
                    Text("Your colours").font(.caption).foregroundStyle(.secondary)
                    // One bar split into the five colours, like a progress bar for the whole vocabulary.
                    Chart(stageCounts.filter { $0.count > 0 }, id: \.stage) { item in
                        BarMark(x: .value("Words", item.count))
                            .foregroundStyle(item.stage.colour)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 14)
                    .clipShape(Capsule())
                    .accessibilityLabel(colourSummary)

                    Text(colourSummary).font(.caption).foregroundStyle(.secondary)
                }
            }
            .homeCard()
        }
    }

    // E.g. "7 red · 5 orange · 4 blue", skipping colours with no words.
    private var colourSummary: String {
        stageCounts.filter { $0.count > 0 }
            .map { "\($0.count) \($0.stage.colourName)" }
            .joined(separator: " · ")
    }

    private func recordNumber(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension LearningStage {
    var colourName: String {
        switch self {
        case .unfamiliar: "red"
        case .learning: "orange"
        case .improving: "yellow"
        case .familiar: "green"
        case .mastered: "blue"
        }
    }
}

private extension View {
    // The white rounded card used by every Home section.
    func homeCard() -> some View {
        self.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
