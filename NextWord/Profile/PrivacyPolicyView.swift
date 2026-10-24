import SwiftUI

// NextWord's privacy policy, shown inside the app as App Store guideline 5.1.1(i) requires.
// It describes what the code really stores; keep it in step with PrivacyInfo.xcprivacy.
struct PrivacyPolicyView: View {
    // The developer's contact email for privacy questions. Fill in before submitting.
    private let contactEmail = "xzho0159@student.moanshi.edu"

    var body: some View {
        List {
            Section {
                Text("NextWord only collects what it needs to run your account and your learning. There are no ads, and you are never tracked across other apps or websites.")
            } footer: {
                Text("Last updated October 2026")
            }

            Section("What we collect and where it's stored") {
                PolicyRow(title: "Your account",
                          detail: "Email address, display name and a Firebase user ID. Stored with Google Firebase on servers in Melbourne, Australia.",
                          symbol: "person.crop.circle")
                PolicyRow(title: "Your learning profile",
                          detail: "Learning survey answers, review session size and reminder settings. Stored with Firebase so they come back when you sign in on a new phone.",
                          symbol: "slider.horizontal.3")
                PolicyRow(title: "Your words and learning history",
                          detail: "Saved words, review results, the learning calendar and display settings. Stored only on this phone, separately for each account.",
                          symbol: "iphone")
                PolicyRow(title: "Your password",
                          detail: "Handled by Firebase Authentication. NextWord never sees or stores it.",
                          symbol: "lock")
            }

            Section("Services we share data with") {
                PolicyRow(title: "DeepL",
                          detail: "When you look up or review a word, that word is sent to DeepL for translation. Your account details are not sent.",
                          symbol: "character.bubble")
                PolicyRow(title: "YouTube",
                          detail: "Playing a video connects to YouTube, and YouTube's own privacy policy applies.",
                          symbol: "play.rectangle")
                PolicyRow(title: "Google Firebase",
                          detail: "Provides sign-in and stores your account and learning profile.",
                          symbol: "server.rack")
            }

            Section("What we don't collect") {
                Text("Location, contacts, photos, advertising identifiers or usage analytics.")
            }

            Section("Permissions") {
                PolicyRow(title: "Notifications",
                          detail: "Optional. Used only for your daily study reminder, which you can turn off in Profile at any time.",
                          symbol: "bell")
            }

            Section("Your choices") {
                Text("You can change your name, retake the learning survey and turn reminders on or off in Profile.")
                Text("Signing out keeps your data on this phone for the next time you sign in.")
                Text("You can delete your account in Profile → Delete account. Your account, your online learning profile and this account's data on this phone are deleted straight away.")
            }

            Section("Contact") {
                if contactEmail.isEmpty {
                    Text("Contact email to be added.").foregroundStyle(.secondary)
                } else if let url = URL(string: "mailto:\(contactEmail)") {
                    Link(contactEmail, destination: url)
                }
            }
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// One topic: an icon, a short title and the details underneath.
private struct PolicyRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
    }
}
