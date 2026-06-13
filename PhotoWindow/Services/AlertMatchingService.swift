import Foundation

struct AlertMatchingService {
    func match(
        windows: [ShootingWindow],
        alertRules: [AlertRule],
        watchlist: [EventWatchlistItem] = [],
        now: Date = Date()
    ) -> [NotificationItem] {
        var seenWindowIds = Set<UUID>()
        var seenEventIds = Set<UUID>()
        var notifications: [NotificationItem] = []

        let enabledRules = alertRules
            .filter(\.isEnabled)
            .sorted {
                if $0.minScore == $1.minScore {
                    return $0.remindBeforeMinutes > $1.remindBeforeMinutes
                }
                return $0.minScore > $1.minScore
            }

        for window in windows.sorted(by: { $0.startTime < $1.startTime }) {
            guard !seenWindowIds.contains(window.id) else { continue }
            let eventIds = Set(window.eventRefs.map(\.id))
            guard seenEventIds.intersection(eventIds).isEmpty else { continue }
            guard let matchingRule = matchingRules(for: window, rules: enabledRules, watchlist: watchlist).first else { continue }

            let triggerTime = window.startTime.addingTimeInterval(-Double(60 * matchingRule.remindBeforeMinutes))
            guard triggerTime > now else { continue }

            notifications.append(makeNotification(for: window, rule: matchingRule, triggerTime: triggerTime))
            seenWindowIds.insert(window.id)
            seenEventIds.formUnion(eventIds)
        }

        return notifications.sorted { $0.triggerTime < $1.triggerTime }
    }

    private func matchingRules(
        for window: ShootingWindow,
        rules: [AlertRule],
        watchlist: [EventWatchlistItem]
    ) -> [AlertRule] {
        rules
            .filter { matches(window: window, rule: $0) }
            .sorted {
                let lhsPriority = priority(for: window, rule: $0, watchlist: watchlist)
                let rhsPriority = priority(for: window, rule: $1, watchlist: watchlist)
                if lhsPriority == rhsPriority {
                    return $0.remindBeforeMinutes > $1.remindBeforeMinutes
                }
                return lhsPriority > rhsPriority
            }
    }

    private func matches(window: ShootingWindow, rule: AlertRule) -> Bool {
        guard window.category == rule.category else { return false }
        guard window.location.id == rule.locationId else { return false }
        guard window.score >= rule.minScore else { return false }

        guard !rule.keywords.isEmpty else { return true }
        return rule.keywords.contains { keyword in
            window.eventRefs.contains { event in
                event.matches(keyword: keyword)
            }
        }
    }

    private func priority(
        for window: ShootingWindow,
        rule: AlertRule,
        watchlist: [EventWatchlistItem]
    ) -> Int {
        var priority = window.score + rule.minScore
        if !rule.keywords.isEmpty {
            let keywordHit = rule.keywords.contains { keyword in
                window.eventRefs.contains { $0.matches(keyword: keyword) }
            }
            if keywordHit {
                priority += 50
            }
        }

        if let event = window.primaryEvent {
            priority += Int(event.importanceLevel.scoreWeight)
        }

        if watchlist.contains(where: { item in
            item.isEnabled &&
            item.category == window.category &&
            window.eventRefs.contains { $0.matches(keyword: item.keyword) }
        }) {
            priority += 60
        }

        return priority
    }

    private func makeNotification(
        for window: ShootingWindow,
        rule: AlertRule,
        triggerTime: Date
    ) -> NotificationItem {
        NotificationItem(
            id: window.id,
            title: notificationTitle(for: window),
            body: notificationBody(for: window, remindBeforeMinutes: rule.remindBeforeMinutes),
            triggerTime: triggerTime,
            relatedWindow: window,
            isRead: false,
            createdAt: Date()
        )
    }

    private func notificationTitle(for window: ShootingWindow) -> String {
        guard let event = window.primaryEvent else {
            return "\(window.category.displayName)提醒"
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
        let time = "\(window.startTime.formatted(date: .omitted, time: .shortened))-\(window.endTime.formatted(date: .omitted, time: .shortened))"
        let weather = window.weatherSnapshot

        if let event = window.primaryEvent {
            return "\(time)，\(weatherSummary(weather))，\(event.importanceLevel.displayName)级 \(event.title)。建议提前 \(formatReminderLead(minutes: remindBeforeMinutes)) 到场。"
        }

        return "\(window.location.name) \(window.windowTitle)，评分 \(window.score)/100，将在 \(formatReminderLead(minutes: remindBeforeMinutes)) 后开始。"
    }

    private func weatherSummary(_ weather: WeatherSnapshot) -> String {
        "云量 \(Int(weather.cloudCover))%，降雨 \(Int(weather.precipitationProbability))%，能见度 \(Int(weather.visibility)) km"
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

private extension ShootingEvent {
    func matches(keyword: String) -> Bool {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKeyword.isEmpty else { return false }

        let searchableText = ([title, description] + tags)
            .joined(separator: " ")
            .lowercased()
        return searchableText.contains(normalizedKeyword)
    }
}
