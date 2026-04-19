import Foundation
import UserNotifications

// MARK: - Notification Service
/// Manages local notifications for certificate and profile expiration alerts
class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("⚠️ Notification authorization error: \(error)")
            }
            completion(granted)
        }
    }

    // MARK: - Schedule Notifications

    func scheduleExpirationAlerts(
        certificates: [Certificate],
        profiles: [ProvisioningProfile],
        brokenProfiles: [ProvisioningProfile] = []
    ) {
        center.removeAllPendingNotificationRequests()

        for cert in certificates where cert.status != .expired {
            scheduleAlerts(
                identifier: "cert-\(cert.id)",
                title: "Certificate Expiring",
                itemName: cert.name,
                expirationDate: cert.expirationDate
            )
        }

        for profile in profiles where profile.status != .expired {
            scheduleAlerts(
                identifier: "profile-\(profile.id)",
                title: "Profile Expiring",
                itemName: profile.name,
                expirationDate: profile.expirationDate
            )
        }

        // Immediate notification for broken profiles
        for profile in brokenProfiles {
            sendImmediate(
                identifier: "broken-\(profile.id)",
                title: "Broken Profile Detected",
                body: "\"\(profile.name)\" references an expired certificate. Builds using this profile will fail."
            )
        }
    }

    /// Schedules alerts at 30 days, 7 days, and 1 day before expiration
    private func scheduleAlerts(
        identifier: String,
        title: String,
        itemName: String,
        expirationDate: Date
    ) {
        let alertIntervals: [(days: Int, urgency: String)] = [
            (30, "expires in 30 days"),
            (7, "expires in 7 days"),
            (1, "expires TOMORROW")
        ]

        for alert in alertIntervals {
            guard let triggerDate = Calendar.current.date(
                byAdding: .day,
                value: -alert.days,
                to: expirationDate
            ) else { continue }

            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "CertWatch — \(title)"
            content.body = "\"\(itemName)\" \(alert.urgency). Renew it to avoid build failures."
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(identifier)-\(alert.days)d",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    print("⚠️ Failed to schedule notification: \(error)")
                }
            }
        }
    }

    /// Sends an immediate notification
    private func sendImmediate(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "CertWatch — \(title)"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "CertWatch"
        content.body = "Notifications are working! You'll be alerted before certificates expire."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
        center.add(request)
    }

    func removeAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
