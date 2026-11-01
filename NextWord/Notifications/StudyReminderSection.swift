import FirebaseAuth
import SwiftUI
import UIKit

// The "Study reminders" : turn the daily reminder on or off and pick its time.
struct StudyReminderSection: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("reminderEnabled_v1") private var reminderEnabled = false
    // Reminder time as minutes after midnight, e.g. 1200 is 20:00.
    @AppStorage("reminderMinutes_v1") private var reminderMinutes = 19 * 60

    var body: some View {
        Section {
            HStack(spacing: 14) {
                BirdMascot(pose: .alarm, size: 64)
                Text("I'll remind you to study at the same time every day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Toggle(isOn: Binding(get: { reminderEnabled }, set: { isOn in Task { await setReminder(isOn) } })) {
                Label("Daily reminder", systemImage: "bell")
            }
            if reminderEnabled {
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    Label("Time", systemImage: "clock")
                }
            }
            // Same idea as the Week 10 lab: if permission was denied, only iOS Settings can change it.
            if notificationManager.authorizationStatus == .denied {
                Text("Notifications are turned off for NextWord in iOS Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Open Notification Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        } header: {
            Text("Study reminders")
        }
        .task { await notificationManager.refresh() }
        // The user may come back from iOS Settings with a different permission.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notificationManager.refresh() } }
        }
        .onChange(of: reminderMinutes) { _, _ in
            Task { await rescheduleAndSync() }
        }
    }

    // DatePicker works with a Date; we store only the hour and minute.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // setReminder asks for permission and only turns the switch on if it’s allowed.
    private func setReminder(_ isOn: Bool) async {
        if isOn {
            // Asks the first time; afterwards iOS returns the saved answer without an alert.
            await notificationManager.requestAuthorization()
            reminderEnabled = notificationManager.canScheduleNotifications
        } else {
            reminderEnabled = false
        }
        await rescheduleAndSync()
    }

    // it schedules or cancels the notification on this phone and uploads the setting to Firestore.
    private func rescheduleAndSync() async {
        if reminderEnabled {
            await notificationManager.scheduleDailyReminder(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
        } else {
            notificationManager.cancelDailyReminder()
        }
        if let uid = authService.user?.uid { PreferencesSync.upload(uid: uid) }
    }
}
