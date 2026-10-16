import SwiftUI

// Ask eight questions and save answers locally only after the final step.
struct LearningPreferencesIntroView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("learningGoals_v1") private var savedGoals = ""
    @AppStorage("englishLevel_v1") private var savedLevel = ""
    @AppStorage("dailyLearningTime_v1") private var savedDailyTime = ""
    @AppStorage("preferredLearningFormat_v1") private var savedFormat = ""
    @AppStorage("preferredStudyTime_v1") private var savedStudyTime = ""
    @AppStorage("videoInterests_v1") private var savedInterests = ""
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @AppStorage("learningQuestionnaireCompleted_v1") private var isCompleted = false

    @State private var step = 0
    @State private var goals: Set<String> = []
    @State private var level = ""
    @State private var dailyTime = ""
    @State private var format = ""
    @State private var studyTime = ""
    @State private var interests: Set<String> = []
    @State private var sessionSize = 20
    @State private var practiceStage: LearningStage?
    @State private var hasLoaded = false

    private struct Choice: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var detail: String? = nil
    }

    private let goalChoices = [
        Choice(id: "vocabulary", title: "Build vocabulary", symbol: "text.book.closed"),
        Choice(id: "articles", title: "Read articles", symbol: "doc.text"),
        Choice(id: "videos", title: "Understand videos", symbol: "play.rectangle"),
        Choice(id: "study", title: "Study or exams", symbol: "graduationcap"),
        Choice(id: "work", title: "Work", symbol: "briefcase"),
        Choice(id: "interest", title: "Personal interest", symbol: "heart")
    ]
    private let levelChoices = [
        Choice(id: "beginner", title: "Beginner", symbol: "1.circle", detail: "I understand common words and short sentences."),
        Choice(id: "intermediate", title: "Intermediate", symbol: "2.circle", detail: "I understand everyday content with some help."),
        Choice(id: "advanced", title: "Advanced", symbol: "3.circle", detail: "I understand most content but still meet unfamiliar words.")
    ]
    private let durationChoices = [
        Choice(id: "5", title: "About 5 minutes", symbol: "clock"),
        Choice(id: "10", title: "About 10 minutes", symbol: "clock"),
        Choice(id: "20", title: "About 20 minutes", symbol: "clock"),
        Choice(id: "more", title: "More than 20 minutes", symbol: "clock"),
        Choice(id: "varies", title: "It depends on the day", symbol: "calendar")
    ]
    private let formatChoices = [
        Choice(id: "articles", title: "Reading articles", symbol: "doc.text"),
        Choice(id: "videos", title: "Watching videos", symbol: "play.rectangle"),
        Choice(id: "both", title: "A mix of both", symbol: "square.stack")
    ]
    private let studyTimeChoices = [
        Choice(id: "morning", title: "Morning", symbol: "sunrise"),
        Choice(id: "afternoon", title: "Afternoon", symbol: "sun.max"),
        Choice(id: "evening", title: "Evening", symbol: "moon.stars"),
        Choice(id: "varies", title: "No regular time", symbol: "calendar")
    ]
    private let interestChoices = [
        Choice(id: "gaming", title: "Gaming", symbol: "gamecontroller"),
        Choice(id: "f1", title: "F1 Racing", symbol: "flag.checkered"),
        Choice(id: "basketball", title: "Basketball", symbol: "basketball"),
        Choice(id: "lifestyle", title: "Lifestyle", symbol: "person.2"),
        Choice(id: "none", title: "No preference", symbol: "sparkles")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Question \(step + 1) of 8")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(step + 1), total: 8).tint(.blue)
                    Text(questionTitle).font(.largeTitle.bold())
                    Text(questionDetail).font(.subheadline).foregroundStyle(.secondary)
                }
                questionContent
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .id(step)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                if step == 7 { savePreferences() }
                else { step += 1 }
            } label: {
                Text(step == 7 ? "Save preferences" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .navigationTitle("Learning Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if step == 0 { dismiss() }
                    else { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(step == 0 ? "Back to Profile" : "Previous question")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Later") { dismiss() }
            }
        }
        .onAppear(perform: loadSavedPreferences)
    }

    private var questionTitle: String {
        switch step {
        case 0: "What are your English learning goals?"
        case 1: "What is your current English level?"
        case 2: "How long would you like to learn each day?"
        case 3: "How do you prefer to learn English?"
        case 4: "When do you usually like to study?"
        case 5: "Which video topics interest you?"
        case 6: "How many words in a review session?"
        default: "How familiar are you with this word?"
        }
    }

    private var questionDetail: String {
        switch step {
        case 0, 5: "Select all that apply."
        case 1: "This is your own estimate, not a test result. You can change it later."
        case 2: "Choose a comfortable amount of time, not a target you must meet."
        case 3: "You can always access both articles and videos."
        case 4: "This will not set a reminder or send notifications."
        case 6: "This updates the session size in Settings."
        default: "Try the five-colour system. Your answer will not be saved as a vocabulary word."
        }
    }

    @ViewBuilder private var questionContent: some View {
        switch step {
        case 0: choices(goalChoices, selected: goals) { toggleGoal($0) }
        case 1: choices(levelChoices, selected: [level]) { level = $0 }
        case 2: choices(durationChoices, selected: [dailyTime]) { dailyTime = $0 }
        case 3: choices(formatChoices, selected: [format]) { format = $0 }
        case 4: choices(studyTimeChoices, selected: [studyTime]) { studyTime = $0 }
        case 5: choices(interestChoices, selected: interests) { toggleInterest($0) }
        case 6:
            choices([10, 20, 30].map { Choice(id: String($0), title: "\($0) words", symbol: "rectangle.stack") },
                    selected: [String(sessionSize)]) { sessionSize = Int($0) ?? 20 }
        default: colourPractice
        }
    }

    private var colourPractice: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("overwhelmed")
                .font(.title.bold())
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            ForEach(LearningStage.allCases, id: \.self) { stage in
                Button { practiceStage = stage } label: {
                    HStack(spacing: 12) {
                        Circle().fill(stage.colour).frame(width: 18, height: 18)
                        Text(stage.label).foregroundStyle(.primary)
                        Spacer()
                        if practiceStage == stage { Image(systemName: "checkmark").foregroundStyle(.blue) }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(practiceStage == stage ? .blue : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            if practiceStage != nil {
                Text("There is no wrong answer. Choose the colour that honestly describes your familiarity. During review, a word can move up or down as you learn.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func choices(_ options: [Choice], selected: Set<String>, action: @escaping (String) -> Void) -> some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                Button { action(option.id) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: option.symbol).font(.title3).frame(width: 30).foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title).font(.headline).foregroundStyle(.primary)
                            if let detail = option.detail {
                                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                        if selected.contains(option.id) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected.contains(option.id) ? .blue : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: !goals.isEmpty
        case 1: !level.isEmpty
        case 2: !dailyTime.isEmpty
        case 3: !format.isEmpty
        case 4: !studyTime.isEmpty
        case 5: !interests.isEmpty
        case 6: [10, 20, 30].contains(sessionSize)
        default: practiceStage != nil
        }
    }

    private func toggleGoal(_ id: String) {
        if goals.contains(id) { goals.remove(id) }
        else { goals.insert(id) }
    }

    private func toggleInterest(_ id: String) {
        if id == "none" { interests = interests.contains("none") ? [] : ["none"] }
        else {
            interests.remove("none")
            if interests.contains(id) { interests.remove(id) }
            else { interests.insert(id) }
        }
    }

    // Returning learners see their previously saved choices.
    private func loadSavedPreferences() {
        guard !hasLoaded else { return }
        hasLoaded = true
        goals = Set(savedGoals.split(separator: ",").map(String.init))
        level = savedLevel
        dailyTime = savedDailyTime
        format = savedFormat
        studyTime = savedStudyTime
        interests = Set(savedInterests.split(separator: ",").map(String.init))
        sessionSize = reviewLimit
    }

    // Later leaves saved answers unchanged; the practice word is never inserted.
    private func savePreferences() {
        savedGoals = goals.sorted().joined(separator: ",")
        savedLevel = level
        savedDailyTime = dailyTime
        savedFormat = format
        savedStudyTime = studyTime
        savedInterests = interests.sorted().joined(separator: ",")
        reviewLimit = sessionSize
        isCompleted = true
        dismiss()
    }
}
