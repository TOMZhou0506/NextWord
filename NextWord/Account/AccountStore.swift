import Foundation
import SwiftData

// Gives every signed-in account its own SwiftData file, so accounts on the same phone never mix.
// Signing out only closes the file; the data stays on the phone for the next sign-in.
enum AccountStore {
    private static let legacyClaimedKey = "legacyStoreClaimed_v1"
    private static let legacyPreferencesClaimedKey = "legacyPreferencesClaimed_v1"

    // Settings and survey answers saved in UserDefaults.standard before accounts existed.
    private static let legacyPreferenceKeys = [
        "appearance", "readingSize", "highlightSavedWords", "reviewLimit",
        "learningQuestionnaireCompleted_v1", "learningGoals_v1", "englishLevel_v1",
        "dailyLearningTime_v1", "preferredLearningFormat_v1", "preferredStudyTime_v1", "videoInterests_v1"
    ]

    // Each account keeps its own settings (theme, text size, survey answers, review limit)
    // in a separate UserDefaults suite. RootView hands it to every @AppStorage in the app.
    static func preferences(for uid: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "account.\(uid)") ?? .standard
        claimLegacyPreferencesIfNeeded(into: defaults)
        return defaults
    }

    // Like the database: the first account to sign in keeps the settings already on this phone.
    private static func claimLegacyPreferencesIfNeeded(into defaults: UserDefaults) {
        let standard = UserDefaults.standard
        guard !standard.bool(forKey: legacyPreferencesClaimedKey) else { return }
        standard.set(true, forKey: legacyPreferencesClaimedKey)
        for key in legacyPreferenceKeys {
            if let value = standard.object(forKey: key) { defaults.set(value, forKey: key) }
        }
    }

    // Open (or create) Application Support/Accounts/<uid>.store for this account.
    static func container(for uid: String) throws -> ModelContainer {
        let folder = URL.applicationSupportDirectory.appending(path: "Accounts", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let storeURL = folder.appending(path: "\(uid).store")

        claimLegacyStoreIfNeeded(into: storeURL)

        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: SavedWord.self, StudyEvent.self, configurations: configuration)
    }

    // Before accounts existed, everything was saved in one shared default.store.
    // The first account to sign in takes a copy of it; later accounts start empty.
    // The original file is left in place as a backup.
    private static func claimLegacyStoreIfNeeded(into storeURL: URL) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: legacyClaimedKey) else { return }
        defaults.set(true, forKey: legacyClaimedKey)

        let fileManager = FileManager.default
        let legacyPath = URL.applicationSupportDirectory.appending(path: "default.store").path(percentEncoded: false)
        let targetPath = storeURL.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: legacyPath), !fileManager.fileExists(atPath: targetPath) else { return }

        // SQLite keeps recent changes in -wal and -shm files beside the main file, so copy all three.
        let suffixes = ["", "-wal", "-shm"].filter { fileManager.fileExists(atPath: legacyPath + $0) }
        do {
            for suffix in suffixes {
                try fileManager.copyItem(atPath: legacyPath + suffix, toPath: targetPath + suffix)
            }
        } catch {
            // Never leave a half-copied database behind; the account then simply starts empty.
            for suffix in suffixes {
                try? fileManager.removeItem(atPath: targetPath + suffix)
            }
            print("Could not copy existing data to the account: \(error.localizedDescription)")
        }
    }
}
