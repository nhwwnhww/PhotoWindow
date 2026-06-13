import Foundation
import UserNotifications

protocol NotificationServicing {
    func requestAuthorization() async -> Bool
    func schedule(notification: NotificationItem) async throws
    func schedule(notifications: [NotificationItem]) async throws
    func scheduleMatchedNotifications(windows: [ShootingWindow], alertRules: [AlertRule]) async throws -> [NotificationItem]
    func scheduleTestNotification(after seconds: TimeInterval) async throws
    func pendingNotifications() async -> [PendingNotification]
    func recentSkippedNotifications() -> [SkippedNotificationRecord]
    func notificationQualityRules() -> NotificationQualityRulesSnapshot
    func cancel(notificationId: UUID)
    func cancelAll()
}

final class NotificationService: NotificationServicing {
    private let center: UNUserNotificationCenter
    private let reminderMergeService: ReminderMergeService
    private let alertMatchingService: AlertMatchingService
    private let notificationQualityService: NotificationQualityService

    init(
        center: UNUserNotificationCenter = .current(),
        reminderMergeService: ReminderMergeService = ReminderMergeService(),
        alertMatchingService: AlertMatchingService = AlertMatchingService(),
        notificationQualityService: NotificationQualityService = NotificationQualityService()
    ) {
        self.center = center
        self.reminderMergeService = reminderMergeService
        self.alertMatchingService = alertMatchingService
        self.notificationQualityService = notificationQualityService
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func schedule(notification: NotificationItem) async throws {
        try await schedule(notifications: [notification])
    }

    func schedule(notifications: [NotificationItem]) async throws {
        let qualityFilteredNotifications = notificationQualityService.filter(
            notifications: notifications,
            pendingNotifications: await pendingNotifications()
        )
        let mergedNotifications = reminderMergeService.merge(notifications: qualityFilteredNotifications)
        for notification in mergedNotifications {
            try await scheduleLocalNotification(notification)
        }
    }

    func scheduleMatchedNotifications(
        windows: [ShootingWindow],
        alertRules: [AlertRule]
    ) async throws -> [NotificationItem] {
        let notifications = alertMatchingService.match(windows: windows, alertRules: alertRules)
        try await schedule(notifications: notifications)
        return notifications
    }

    func scheduleTestNotification(after seconds: TimeInterval) async throws {
        let granted = await requestAuthorization()
        guard granted else { return }

        let roundedSeconds = max(Int(seconds), 1)
        let notification = NotificationItem(
            id: UUID(),
            title: "PhotoWindow 测试提醒",
            body: "\(roundedSeconds) 秒后测试提醒已触发。",
            triggerTime: Date().addingTimeInterval(TimeInterval(roundedSeconds)),
            relatedWindow: nil,
            isRead: false,
            createdAt: Date()
        )
        try await scheduleLocalNotification(notification)
    }

    func pendingNotifications() async -> [PendingNotification] {
        let requests = await center.pendingNotificationRequests()
        return requests
            .map { request in
                PendingNotification(
                    id: request.identifier,
                    title: request.content.title,
                    body: request.content.body,
                    nextTriggerDate: nextTriggerDate(for: request.trigger)
                )
            }
            .sorted {
                switch ($0.nextTriggerDate, $1.nextTriggerDate) {
                case let (lhs?, rhs?):
                    return lhs < rhs
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return $0.id < $1.id
                }
            }
    }

    func recentSkippedNotifications() -> [SkippedNotificationRecord] {
        notificationQualityService.recentSkippedNotifications
    }

    func notificationQualityRules() -> NotificationQualityRulesSnapshot {
        notificationQualityService.rulesSnapshot
    }

    func scheduleRemotePushPlaceholder(notifications: [NotificationItem]) async throws {
        _ = notifications
    }

    private func scheduleLocalNotification(_ notification: NotificationItem) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let secondsUntilTrigger = max(notification.triggerTime.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilTrigger, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancel(notificationId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId.uuidString])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func nextTriggerDate(for trigger: UNNotificationTrigger?) -> Date? {
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(intervalTrigger.timeInterval)
        }

        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return Calendar.current.nextDate(
                after: Date(),
                matching: calendarTrigger.dateComponents,
                matchingPolicy: .nextTime
            )
        }

        return nil
    }
}
