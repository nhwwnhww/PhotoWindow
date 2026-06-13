import Foundation

struct SkippedNotificationRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var windowTitle: String
    var reason: String
    var createdAt: Date
}

struct NotificationQualityDecision: Hashable {
    var shouldSchedule: Bool
    var reason: String?

    static let allowed = NotificationQualityDecision(shouldSchedule: true, reason: nil)

    static func skipped(_ reason: String) -> NotificationQualityDecision {
        NotificationQualityDecision(shouldSchedule: false, reason: reason)
    }
}

struct NotificationQualityRulesSnapshot: Hashable {
    var dailyMaxNotifications: Int
    var quietHoursDescription: String
    var minScoreForNotification: Int
    var allowMustShootOverride: Bool
    var mergeNearbyNotifications: Bool
}

final class NotificationQualityService {
    private let calendar: Calendar
    private let userDefaults: UserDefaults
    private let preferenceKey: String
    private(set) var recentSkippedNotifications: [SkippedNotificationRecord] = []

    init(
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard,
        preferenceKey: String = "PhotoWindow.userPreference.v3"
    ) {
        self.calendar = calendar
        self.userDefaults = userDefaults
        self.preferenceKey = preferenceKey
    }

    var currentPreference: NotificationPreference {
        loadStoredPreference() ?? .defaultValue
    }

    var rulesSnapshot: NotificationQualityRulesSnapshot {
        let preference = currentPreference
        return NotificationQualityRulesSnapshot(
            dailyMaxNotifications: preference.dailyMaxNotifications,
            quietHoursDescription: preference.quietHoursDescription,
            minScoreForNotification: preference.minScoreForNotification,
            allowMustShootOverride: preference.allowMustShootOverride,
            mergeNearbyNotifications: preference.mergeNearbyNotifications
        )
    }

    func filter(
        notifications: [NotificationItem],
        pendingNotifications: [PendingNotification],
        preference: NotificationPreference? = nil
    ) -> [NotificationItem] {
        let preference = preference ?? currentPreference
        let pendingIDs = Set(pendingNotifications.map(\.id))
        var seenIDs = Set<String>()
        var accepted: [NotificationItem] = []
        var scheduledByDay = pendingNotifications.reduce(into: [Date: Int]()) { partialResult, notification in
            guard let date = notification.nextTriggerDate else { return }
            let day = calendar.startOfDay(for: date)
            partialResult[day, default: 0] += 1
        }

        for notification in notifications.sorted(by: prioritySort) {
            let id = notification.id.uuidString
            let window = notification.relatedWindow

            if pendingIDs.contains(id) || !seenIDs.insert(id).inserted {
                recordSkip(notification, reason: "已存在同一拍摄窗口的提醒，避免重复创建。")
                continue
            }

            let day = calendar.startOfDay(for: notification.triggerTime)
            if scheduledByDay[day, default: 0] >= preference.dailyMaxNotifications &&
                !isOverrideAllowed(for: window, preference: preference) {
                recordSkip(notification, reason: "已达到每日最大提醒数量 \(preference.dailyMaxNotifications)。")
                continue
            }

            let decision = evaluate(
                notification: notification,
                accepted: accepted,
                preference: preference
            )

            guard decision.shouldSchedule else {
                recordSkip(notification, reason: decision.reason ?? "提醒质量规则跳过。")
                continue
            }

            accepted.append(notification)
            scheduledByDay[day, default: 0] += 1
        }

        if preference.mergeNearbyNotifications {
            accepted = mergeSameLocationAndCategory(notifications: accepted)
        }

        return accepted.sorted { $0.triggerTime < $1.triggerTime }
    }

    func evaluate(
        notification: NotificationItem,
        accepted: [NotificationItem] = [],
        preference: NotificationPreference? = nil
    ) -> NotificationQualityDecision {
        let preference = preference ?? currentPreference

        guard let window = notification.relatedWindow else {
            return .allowed
        }

        let highValueEvent = isOverrideAllowed(for: window, preference: preference)

        if isInQuietHours(notification.triggerTime, preference: preference) && !highValueEvent {
            return .skipped("触发时间处于勿扰时段 \(preference.quietHoursDescription)。")
        }

        if window.score < preference.minScoreForNotification && !highValueEvent {
            return .skipped("评分 \(window.score) 低于提醒阈值 \(preference.minScoreForNotification)。")
        }

        if window.effectiveRecommendationResult.confidenceLevel == .low && !highValueEvent {
            return .skipped("可信度低，默认不创建提醒。")
        }

        if !window.shouldNotifyByDefault && !highValueEvent {
            return .skipped("推荐结果不建议默认提醒。")
        }

        if preference.mergeNearbyNotifications,
           accepted.contains(where: { isSameLocationCategoryDay($0, notification) }) {
            return .skipped("同地点同类别已有相近提醒，将由合并提醒覆盖。")
        }

        return .allowed
    }

    private func prioritySort(_ lhs: NotificationItem, _ rhs: NotificationItem) -> Bool {
        if priority(for: lhs) == priority(for: rhs) {
            return lhs.triggerTime < rhs.triggerTime
        }
        return priority(for: lhs) > priority(for: rhs)
    }

    private func priority(for notification: NotificationItem) -> Int {
        guard let window = notification.relatedWindow else { return 0 }
        let importance = window.primaryEvent?.importanceLevel.scoreWeight ?? 0
        return window.score + Int(importance) + (window.primaryEvent?.importanceLevel == .mustShoot ? 30 : 0)
    }

    private func isOverrideAllowed(
        for window: ShootingWindow?,
        preference: NotificationPreference
    ) -> Bool {
        guard preference.allowMustShootOverride, let window else { return false }
        return window.primaryEvent?.importanceLevel == .mustShoot
    }

    private func isInQuietHours(_ date: Date, preference: NotificationPreference) -> Bool {
        let start = min(max(preference.quietHoursStart, 0), 23)
        let end = min(max(preference.quietHoursEnd, 0), 23)
        guard start != end else { return false }

        let hour = calendar.component(.hour, from: date)
        if start < end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }

    private func mergeSameLocationAndCategory(notifications: [NotificationItem]) -> [NotificationItem] {
        var grouped: [String: NotificationItem] = [:]
        for notification in notifications {
            guard let window = notification.relatedWindow else {
                grouped[notification.id.uuidString] = notification
                continue
            }

            let key = [
                calendar.startOfDay(for: notification.triggerTime).timeIntervalSince1970.description,
                window.location.id.uuidString,
                window.category.rawValue
            ].joined(separator: "-")

            if let existing = grouped[key] {
                grouped[key] = priority(for: notification) > priority(for: existing) ? notification : existing
            } else {
                grouped[key] = notification
            }
        }

        return Array(grouped.values)
    }

    private func isSameLocationCategoryDay(_ lhs: NotificationItem, _ rhs: NotificationItem) -> Bool {
        guard let lhsWindow = lhs.relatedWindow,
              let rhsWindow = rhs.relatedWindow else {
            return false
        }

        return lhsWindow.location.id == rhsWindow.location.id &&
            lhsWindow.category == rhsWindow.category &&
            calendar.isDate(lhs.triggerTime, inSameDayAs: rhs.triggerTime)
    }

    private func recordSkip(_ notification: NotificationItem, reason: String) {
        let record = SkippedNotificationRecord(
            id: UUID(),
            windowTitle: notification.relatedWindow?.windowTitle ?? notification.title,
            reason: reason,
            createdAt: Date()
        )
        recentSkippedNotifications.insert(record, at: 0)
        recentSkippedNotifications = Array(recentSkippedNotifications.prefix(20))
    }

    private func loadStoredPreference() -> NotificationPreference? {
        guard let data = userDefaults.data(forKey: preferenceKey),
              let preference = try? JSONDecoder().decode(UserPreference.self, from: data) else {
            return nil
        }

        return preference.effectiveNotificationPreference
    }
}
