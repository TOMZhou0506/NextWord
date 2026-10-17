import Foundation
import Observation
import UserNotifications

// Names shared by the manager and the AppDelegate, kept in one place (as in the Week 10 lab).
enum NotificationConstants {
    // A fixed identifier, so scheduling again replaces the old reminder instead of adding a second one.
    static let dailyReminderIdentifier = "nextword.dailyStudyReminder"
    static let reminderCategoryIdentifier = "nextword.studyReminder"
}

// Asks for notification permission and schedules the daily study reminder.
// Based on the Week 10 lab's NotificationManager.
@MainActor
@Observable
final class NotificationManager {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored
    private let notificationCenter = UNUserNotificationCenter.current()

    var canScheduleNotifications: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }

    // Read the current permission; the user may have changed it in the iOS Settings app.
    func refresh() async {
        authorizationStatus = await notificationCenter.notificationSettings().authorizationStatus
    }

    // Shows the system permission alert (only the first time). Returns true if allowed.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
        await refresh()
        return granted
    }

    // Plan A: one notification that repeats at the same time every day.
    func scheduleDailyReminder(hour: Int, minute: Int) async {
        await refresh()
        guard canScheduleNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for your English"
        content.body = "A few minutes today keeps your words growing. Tap to start your review."
        content.sound = .default
        content.categoryIdentifier = NotificationConstants.reminderCategoryIdentifier

        // Only hour and minute are set, so the trigger matches that time on every day.
        var time = DateComponents()
        time.hour = hour
        time.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

        let request = UNNotificationRequest(
            identifier: NotificationConstants.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Could not schedule the daily reminder: \(error.localizedDescription)")
        }
    }

    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [NotificationConstants.dailyReminderIdentifier]
        )
    }

    // The survey's study time becomes a starting reminder time, which Settings can change.
    static func defaultReminderTime(for studyTime: String) -> (hour: Int, minute: Int) {
        switch studyTime {
        case "morning": (8, 0)
        case "afternoon": (14, 0)
        case "evening": (20, 0)
        default: (19, 0)
        }
    }
}
