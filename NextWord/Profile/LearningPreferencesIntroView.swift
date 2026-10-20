import FirebaseAuth
import SwiftUI

// A seven-page learning survey. Answers are saved only on the last page,
// to this account's settings, and copied to Firestore.
struct LearningPreferencesIntroView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("heardFrom_v1") private var savedHeardFrom = ""
    @AppStorage("englishLevel_v2") private var savedLevel = 0
    @AppStorage("englishLevel_v1") private var oldLevel = ""
    @AppStorage("learningGoals_v1") private var savedGoals = ""
    @AppStorage("videoInterests_v1") private var savedInterests = ""
    @AppStorage("dailyMinutes_v1") private var savedMinutes = 15
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @AppStorage("preferredStudyTime_v1") private var savedStudyTime = ""
    @AppStorage("learningQuestionnaireCompleted_v1") private var isCompleted = false
    // Set by "Later", so the survey doesn't pop up again after sign-in.
    @AppStorage("learningQuestionnaireSkipped_v1") private var isSkipped = false
    @AppStorage("reminderEnabled_v1") private var reminderEnabled = false
    // Reminder time as minutes after midnight, e.g. 1200 is 20:00.
    @AppStorage("reminderMinutes_v1") private var reminderMinutes = 19 * 60
    @Environment(NotificationManager.self) private var notificationManager
    @State private var isFinishing = false

    private let pageCount = 7
    @State private var step = 0
    @State private var heardFrom = ""
    @State private var level = 0
    @State private var goals: Set<String> = []
    @State private var interests: Set<String> = []
    @State private var minutes = 15
    @State private var reviewWords = 20
    @State private var studyTime = ""
    @State private var demoStage = LearningStage.unfamiliar
    @State private var hasTriedDemo = false
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProgressView(value: Double(step + 1), total: Double(pageCount)).tint(.blue)
                BirdPrompt(text: question)
                if let hint {
                    Text(hint).font(.subheadline).foregroundStyle(.secondary)
                }
                pageContent
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .id(step)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                if step == pageCount - 1 { Task { await savePreferences() } }
                else { step += 1 }
            } label: {
                Text(step == pageCount - 1 ? "Start learning" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue || isFinishing)
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
                    if step == 0 { skipForNow() }
                    else { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(step == 0 ? "Close survey" : "Previous question")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Later") { skipForNow() }
            }
        }
        .onAppear(perform: loadSavedPreferences)
    }

    private var question: String {
        switch step {
        case 0: "Where did you hear about NextWord?"
        case 1: "How much English do you know?"
        case 2: "Why are you learning English?"
        case 3: "Which video topics interest you?"
        case 4: "What's your daily goal?"
        case 5: "When do you usually like to study?"
        default: "Meet the five colours!"
        }
    }

    private var hint: String? {
        switch step {
        case 1: "This is your own estimate. You can change it later in Settings."
        case 2, 3: "Select all that apply."
        case 4: "You can change both of these later in Settings."
        case 5: "We'll use this for your study reminders."
        case 6: "Every saved word has a colour. Keep remembering until the word turns blue."
        default: nil
        }
    }

    @ViewBuilder private var pageContent: some View {
        switch step {
        case 0: choices(SurveyOptions.sources, selected: [heardFrom]) { heardFrom = $0 }
        case 1: levelPage
        case 2: choices(SurveyOptions.goals, selected: goals) { toggle($0, in: &goals) }
        case 3: choices(SurveyOptions.interests, selected: interests) { toggleInterest($0) }
        case 4: dailyGoalPage
        case 5: choices(SurveyOptions.studyTimes, selected: [studyTime]) { studyTime = $0 }
        default: colourDemoPage
        }
    }

    // Signal bars fill up with each level, like a phone signal.
    private var levelPage: some View {
        VStack(spacing: 12) {
            ForEach(SurveyOptions.levels, id: \.0) { value, title in
                Button { level = value } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "cellularbars", variableValue: Double(value - 1) / 4)
                            .font(.title3).frame(width: 30).foregroundStyle(.blue)
                        Text(title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .choiceCard(isSelected: level == value)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dailyGoalPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(minutes) min / day").font(.headline).monospacedDigit()
                    Spacer()
                    Text(effortLabel).foregroundStyle(.secondary)
                }
                Slider(value: $minutes.asDouble, in: 10...60, step: 5)
                Text("Time spent reading, watching and reviewing.").font(.caption).foregroundStyle(.secondary)
            }
            .choiceCard(isSelected: false)

            VStack(alignment: .leading, spacing: 10) {
                Text("\(reviewWords) words per review").font(.headline).monospacedDigit()
                Slider(value: $reviewWords.asDouble, in: 10...100, step: 5)
                Text("The most words one review session will include.").font(.caption).foregroundStyle(.secondary)
            }
            .choiceCard(isSelected: false)
        }
    }

    private var effortLabel: String {
        switch minutes {
        case ..<15: "Casual"
        case ..<30: "Regular"
        case ..<45: "Serious"
        default: "Intense"
        }
    }

    // A small review practice: the word moves up when remembered and down when forgotten.
    private var colourDemoPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 14) {
                // The bird celebrates when the word reaches blue.
                if demoStage == .mastered {
                    BirdMascot(pose: .celebrate, size: 100, popsIn: true)
                }
                Text("overwhelmed")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(demoStage.colour, in: Capsule())
                Text(demoMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 40)
                // Side by side when they fit; stacked when the text size is very large.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { demoButtons }
                    VStack(spacing: 10) { demoButtons }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .choiceCard(isSelected: false)

            ForEach(LearningStage.allCases, id: \.self) { stage in
                HStack(spacing: 12) {
                    Circle().fill(stage.colour).frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.label).font(.subheadline.weight(.semibold))
                        Text(stage.demoMeaning).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if stage == demoStage {
                        Image(systemName: "arrow.left").foregroundStyle(stage.colour)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: demoStage)
    }

    // Short labels kept on one line, so the two buttons stay the same shape.
    @ViewBuilder private var demoButtons: some View {
        Button { moveDemo(by: -1) } label: {
            Label("Forgot", systemImage: "arrow.down")
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .tint(.red)
        .disabled(demoStage == .unfamiliar)
        Button { moveDemo(by: 1) } label: {
            Label("Remembered", systemImage: "arrow.up")
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .tint(.green)
        .disabled(demoStage == .mastered)
    }

    private var demoMessage: String {
        if !hasTriedDemo { return "Pretend this is a review. Did you remember the word?" }
        return demoStage == .mastered
            ? "Mastered! Blue words leave your review list."
            : "Remembered words move up a colour; forgotten words move down. Reach blue to finish."
    }

    private func moveDemo(by change: Int) {
        let stages = LearningStage.allCases
        guard let index = stages.firstIndex(of: demoStage) else { return }
        demoStage = stages[min(max(index + change, 0), stages.count - 1)]
        hasTriedDemo = true
    }

    private func choices(_ options: [SurveyOptions.Choice], selected: Set<String>, action: @escaping (String) -> Void) -> some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                Button { action(option.id) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: option.symbol).font(.title3).frame(width: 30).foregroundStyle(.blue)
                        Text(option.title).font(.headline).foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        if selected.contains(option.id) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        }
                    }
                    .choiceCard(isSelected: selected.contains(option.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: !heardFrom.isEmpty
        case 1: level != 0
        case 2: !goals.isEmpty
        case 3: !interests.isEmpty
        case 4: true
        case 5: !studyTime.isEmpty
        // The survey ends once the learner has walked the word all the way to blue.
        default: demoStage == .mastered
        }
    }

    private func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    // "No preference" can't be combined with real topics.
    private func toggleInterest(_ id: String) {
        if id == "none" { interests = interests.contains("none") ? [] : ["none"] }
        else {
            interests.remove("none")
            toggle(id, in: &interests)
        }
    }

    // Returning learners see their previously saved choices.
    private func loadSavedPreferences() {
        guard !hasLoaded else { return }
        hasLoaded = true
        heardFrom = savedHeardFrom
        level = savedLevel
        // Answers from the old three-level survey become the closest new level.
        if level == 0 {
            level = ["beginner": 1, "intermediate": 3, "advanced": 5][oldLevel] ?? 0
        }
        goals = Set(savedGoals.split(separator: ",").map(String.init))
        interests = Set(savedInterests.split(separator: ",").map(String.init))
        minutes = min(max(savedMinutes, 10), 60)
        reviewWords = min(max(reviewLimit, 10), 100)
        studyTime = savedStudyTime
    }

    // "Later" leaves saved answers unchanged; nothing is written until this point.
    private func savePreferences() async {
        isFinishing = true
        let studyTimeChanged = studyTime != savedStudyTime
        savedHeardFrom = heardFrom
        savedLevel = level
        savedGoals = goals.sorted().joined(separator: ",")
        savedInterests = interests.sorted().joined(separator: ",")
        savedMinutes = minutes
        reviewLimit = reviewWords
        savedStudyTime = studyTime
        isCompleted = true

        await setUpReminder(studyTimeChanged: studyTimeChanged)

        if let uid = authService.user?.uid {
            PreferencesSync.upload(uid: uid)
        }
        dismiss()
    }

    // Ask for notification permission right after the learner picks a study time,
    // when the reason for asking is easy to understand.
    private func setUpReminder(studyTimeChanged: Bool) async {
        // Keep a time the learner already chose in Settings, unless they picked a new study time.
        if studyTimeChanged || !reminderEnabled {
            let time = NotificationManager.defaultReminderTime(for: studyTime)
            reminderMinutes = time.hour * 60 + time.minute
        }
        // iOS only shows the permission alert once; later calls return the saved answer.
        let allowed = await notificationManager.requestAuthorization()
        reminderEnabled = allowed
        if allowed {
            await notificationManager.scheduleDailyReminder(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
        }
    }

    // Leave without changing any answers, and remember not to pop up again.
    private func skipForNow() {
        isSkipped = true
        if let uid = authService.user?.uid {
            PreferencesSync.upload(uid: uid)
        }
        dismiss()
    }
}

private extension LearningStage {
    var demoMeaning: String {
        switch self {
        case .unfamiliar: "New to you — you've just met this word."
        case .learning: "You've seen it, but it's still slippery."
        case .improving: "You usually remember it."
        case .familiar: "You know it well."
        case .mastered: "Mastered — it no longer appears in reviews."
        }
    }
}

private extension View {
    // The rounded card used for every answer, outlined in blue when selected.
    func choiceCard(isSelected: Bool) -> some View {
        self.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? .blue : .clear, lineWidth: 2))
    }
}
