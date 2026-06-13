import Foundation

protocol AnalyticsServicing {
    func record(_ event: AnalyticsEvent) async
    func fetchEvents() async -> [AnalyticsEvent]
}

extension AnalyticsServicing {
    func record(
        _ name: AnalyticsEventName,
        category: PhotographyCategory? = nil,
        locationId: UUID? = nil,
        windowId: UUID? = nil,
        score: Int? = nil,
        scoreLevel: ShootingWindowScoreLevel? = nil
    ) async {
        await record(
            AnalyticsEvent(
                name: name,
                category: category,
                locationId: locationId,
                windowId: windowId,
                score: score,
                scoreLevel: scoreLevel
            )
        )
    }

    func record(_ name: AnalyticsEventName, window: ShootingWindow) async {
        await record(
            name,
            category: window.category,
            locationId: window.location.id,
            windowId: window.id,
            score: window.score,
            scoreLevel: window.scoreLevel
        )
    }

    func record(_ name: AnalyticsEventName, rule: AlertRule) async {
        await record(
            name,
            category: rule.category,
            locationId: rule.locationId,
            windowId: nil,
            score: rule.minScore,
            scoreLevel: ShootingWindowScoreLevel.from(score: rule.minScore)
        )
    }
}

final class AnalyticsService: AnalyticsServicing {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "PhotoWindow.analyticsEvents.v4") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func record(_ event: AnalyticsEvent) async {
        var events = loadEvents()
        events.append(event)
        saveEvents(events)
        printLog(for: event)
    }

    func fetchEvents() async -> [AnalyticsEvent] {
        loadEvents().sorted { $0.timestamp > $1.timestamp }
    }

    private func loadEvents() -> [AnalyticsEvent] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveEvents(_ events: [AnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func printLog(for event: AnalyticsEvent) {
        let parts = [
            "name=\(event.name.rawValue)",
            "category=\(event.category?.rawValue ?? "-")",
            "locationId=\(event.locationId?.uuidString ?? "-")",
            "windowId=\(event.windowId?.uuidString ?? "-")",
            "score=\(event.score.map(String.init) ?? "-")",
            "scoreLevel=\(event.scoreLevel?.rawValue ?? "-")"
        ]
        print("[photochaser Analytics] \(parts.joined(separator: " "))")
    }
}
