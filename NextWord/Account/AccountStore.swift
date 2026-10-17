import Foundation
import SwiftData

// Gives every signed-in account its own SwiftData file, so accounts on the same phone never mix.
// Signing out only closes the file; the data stays on the phone for the next sign-in.
enum AccountStore {
    private static let legacyClaimedKey = "legacyStoreClaimed_v1"

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
