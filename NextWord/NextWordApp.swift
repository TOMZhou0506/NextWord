//
//  NextWordApp.swift
//  NextWord
//
//  Created by Tom on 15/9/2026.
//

import SwiftUI
import SwiftData

@main
// The app entry point creates the first window and shows ContentView.
struct NextWordApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Keep saved vocabulary and learning history available across tabs and app launches.
        .modelContainer(for: [SavedWord.self, StudyEvent.self])
    }
}
