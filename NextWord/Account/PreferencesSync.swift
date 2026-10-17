import FirebaseFirestore
import Foundation

// Copies the learning survey answers to Firestore at users/{uid}, field "preferences",
// so they come back when the user signs in on a new phone.
// Display settings (theme, text size) stay on each phone.
enum PreferencesSync {
    static let syncedKeys = [
        "learningQuestionnaireCompleted_v1", "learningQuestionnaireSkipped_v1", "heardFrom_v1", "englishLevel_v2",
        "learningGoals_v1", "videoInterests_v1", "dailyMinutes_v1",
        "preferredStudyTime_v1", "reviewLimit", "reminderEnabled_v1", "reminderMinutes_v1"
    ]

    // Called after the survey or a learning setting is saved. We don't wait for it,
    // so it also works offline; Firestore sends the write once the phone is back online.
    static func upload(uid: String) {
        let defaults = AccountStore.preferences(for: uid)
        var preferences: [String: Any] = [:]
        for key in syncedKeys {
            if let value = defaults.object(forKey: key) { preferences[key] = value }
        }
        // merge: true keeps displayName, email and createdAt in the same document.
        Firestore.firestore().collection("users").document(uid)
            .setData(["preferences": preferences], merge: true) { error in
                if let error { print("Could not save preferences: \(error.localizedDescription)") }
            }
    }

    // Called after sign-in. Only fills an empty phone (for example a new phone);
    // answers already on this phone are never overwritten.
    static func restoreIfNeeded(uid: String, into defaults: UserDefaults) async {
        guard !defaults.bool(forKey: "learningQuestionnaireCompleted_v1") else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard let preferences = snapshot.data()?["preferences"] as? [String: Any] else { return }
            for key in syncedKeys {
                if let value = preferences[key] { defaults.set(value, forKey: key) }
            }
        } catch {
            // Offline or no profile yet: keep using what is on this phone.
            print("Could not restore preferences: \(error.localizedDescription)")
        }
    }
}
