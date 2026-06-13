import Foundation

struct NotificationItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var triggerTime: Date
    var relatedWindow: ShootingWindow?
    var isRead: Bool
    var createdAt: Date
}

struct PendingNotification: Identifiable, Hashable {
    let id: String
    var title: String
    var body: String
    var nextTriggerDate: Date?

    var triggerDescription: String {
        guard let nextTriggerDate else {
            return "触发时间未知"
        }
        return nextTriggerDate.formatted(date: .abbreviated, time: .standard)
    }
}

struct ReminderMergeService {
    let mergeWindowSeconds: TimeInterval
    private let calendar: Calendar

    init(mergeWindowSeconds: TimeInterval = 7_200, calendar: Calendar = .current) {
        self.mergeWindowSeconds = mergeWindowSeconds
        self.calendar = calendar
    }

    func merge(notifications: [NotificationItem]) -> [NotificationItem] {
        let sorted = notifications.sorted { $0.triggerTime < $1.triggerTime }
        var groups: [[NotificationItem]] = []

        for notification in sorted {
            guard var currentGroup = groups.popLast(), let last = currentGroup.last else {
                groups.append([notification])
                continue
            }

            if calendar.isDate(last.triggerTime, inSameDayAs: notification.triggerTime) &&
                notification.triggerTime.timeIntervalSince(last.triggerTime) < mergeWindowSeconds {
                currentGroup.append(notification)
                groups.append(currentGroup)
            } else {
                groups.append(currentGroup)
                groups.append([notification])
            }
        }

        return groups.map { group in
            guard group.count > 1 else { return group[0] }
            return makeSummaryNotification(for: group)
        }
    }

    func notifications(
        for windows: [ShootingWindow],
        remindBeforeMinutes: Int
    ) -> [NotificationItem] {
        windows.map { window in
            NotificationItem(
                id: window.id,
                title: notificationTitle(for: window),
                body: notificationBody(for: window, remindBeforeMinutes: remindBeforeMinutes),
                triggerTime: window.startTime.addingTimeInterval(-Double(60 * remindBeforeMinutes)),
                relatedWindow: window,
                isRead: false,
                createdAt: Date()
            )
        }
    }

    func nearbyMergeCount(
        for target: ShootingWindow,
        in windows: [ShootingWindow],
        remindBeforeMinutes: Int
    ) -> Int {
        let targetTriggerTime = target.startTime.addingTimeInterval(-Double(60 * remindBeforeMinutes))
        return windows.filter { window in
            guard window.id != target.id else { return false }
            let triggerTime = window.startTime.addingTimeInterval(-Double(60 * window.defaultReminderLeadMinutes))
            return calendar.isDate(targetTriggerTime, inSameDayAs: triggerTime) &&
                abs(triggerTime.timeIntervalSince(targetTriggerTime)) < mergeWindowSeconds
        }.count
    }

    private func makeSummaryNotification(for notifications: [NotificationItem]) -> NotificationItem {
        let windows = notifications.compactMap(\.relatedWindow)
        let containsMustShoot = windows.contains { $0.primaryEvent?.importanceLevel == .mustShoot }
        let title = containsMustShoot
            ? "今天有 \(notifications.count) 个拍摄机会，含必拍事件"
            : "今天下午有 \(notifications.count) 个值得拍摄的机会"
        let body = windows.isEmpty
            ? notifications.map(\.body).joined(separator: "、")
            : windows.map { "\($0.location.name) \($0.windowTitle)" }.joined(separator: "、") + "。"

        return NotificationItem(
            id: notifications.first?.id ?? UUID(),
            title: title,
            body: body,
            triggerTime: notifications.map(\.triggerTime).min() ?? Date(),
            relatedWindow: notifications.first?.relatedWindow,
            isRead: false,
            createdAt: Date()
        )
    }

    private func notificationTitle(for window: ShootingWindow) -> String {
        guard let event = window.primaryEvent else {
            return "拍摄窗口提醒"
        }

        if event.importanceLevel == .mustShoot {
            return "必拍事件：\(event.title)"
        }

        if event.importanceLevel == .rare {
            return "稀有事件：\(event.title)"
        }

        return "特殊事件：\(event.title)"
    }

    private func notificationBody(for window: ShootingWindow, remindBeforeMinutes: Int) -> String {
        let lead = formatReminderLead(minutes: remindBeforeMinutes)
        guard let event = window.primaryEvent else {
            return "\(window.windowTitle) 将在 \(lead) 后开始。"
        }

        let time = "\(window.startTime.formatted(date: .omitted, time: .shortened))-\(window.endTime.formatted(date: .omitted, time: .shortened))"
        let weather = window.weatherSnapshot
        return "\(time)，云量 \(Int(weather.cloudCover))%，降雨 \(Int(weather.precipitationProbability))%，能见度 \(Int(weather.visibility)) km，\(event.title)。建议提前 \(lead) 到场。"
    }

    private func formatReminderLead(minutes: Int) -> String {
        if minutes == 1_500 {
            return "1 天 + 1 小时"
        }

        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440) 天"
        }

        if minutes % 60 == 0 {
            return "\(minutes / 60) 小时"
        }

        return "\(minutes) 分钟"
    }
}
