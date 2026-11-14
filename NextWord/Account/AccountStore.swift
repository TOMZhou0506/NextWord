import Foundation
import SwiftData

// Gives every signed-in account its own SwiftData file, so accounts on the same phone never mix.
// Signing out only closes the file; the data stays on the phone for the next sign-in.
enum AccountStore {
    // Each account keeps its own settings (theme, text size, survey answers, review limit)
    // in a separate UserDefaults suite. RootView hands it to every @AppStorage in the app.
    static func preferences(for uid: String) -> UserDefaults {
        UserDefaults(suiteName: "account.\(uid)") ?? .standard
    }

    // Used after the account is deleted: remove its database files and its settings from this phone.
    static func deleteLocalData(for uid: String) {
        let storePath = URL.applicationSupportDirectory
            .appending(path: "Accounts", directoryHint: .isDirectory)
            .appending(path: "\(uid).store")
            .path(percentEncoded: false)
        // SQLite keeps -wal and -shm files beside the main file, so remove all three.
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: storePath + suffix)
        }
        UserDefaults.standard.removePersistentDomain(forName: "account.\(uid)")
    }

    // Open (or create) this account's SwiftData store at Application Support/Accounts/<uid>.store.
    static func container(for uid: String) throws -> ModelContainer {
        let folder = URL.applicationSupportDirectory.appending(path: "Accounts", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let storeURL = folder.appending(path: "\(uid).store")

        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: SavedWord.self, StudyEvent.self, configurations: configuration)
    }
}
