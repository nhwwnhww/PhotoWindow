import Foundation

enum ShootingEventType: String, CaseIterable, Identifiable, Codable, Hashable {
    case milkyWayWindow
    case sunrise
    case sunset
    case goldenHour
    case blueHour
    case specialAircraft
    case lowCloud
    case clearSky
    case meteorShower
    case graduationSeason

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .milkyWayWindow:
            return "银河窗口"
        case .sunrise:
            return "日出"
        case .sunset:
            return "日落"
        case .goldenHour:
            return "黄金时刻"
        case .blueHour:
            return "蓝调时刻"
        case .specialAircraft:
            return "特殊飞机"
        case .lowCloud:
            return "低云"
        case .clearSky:
            return "晴空"
        case .meteorShower:
            return "流星雨"
        case .graduationSeason:
            return "毕业季"
        }
    }
}

enum ShootingEventSourceType: String, CaseIterable, Identifiable, Codable, Hashable {
    case mock
    case weatherAPI
    case aviationAPI
    case astronomyAPI
    case userGenerated

    var id: String { rawValue }
}

enum EventImportanceLevel: String, CaseIterable, Identifiable, Codable, Hashable {
    case normal
    case worthWatching
    case rare
    case mustShoot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:
            return "普通"
        case .worthWatching:
            return "值得关注"
        case .rare:
            return "稀有"
        case .mustShoot:
            return "必拍"
        }
    }

    var scoreWeight: Double {
        switch self {
        case .normal:
            return 0
        case .worthWatching:
            return 8
        case .rare:
            return 16
        case .mustShoot:
            return 24
        }
    }

    var badgeText: String {
        switch self {
        case .normal:
            return "普通事件"
        case .worthWatching:
            return "值得关注"
        case .rare:
            return "稀有事件"
        case .mustShoot:
            return "必拍事件"
        }
    }
}

struct ShootingEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: PhotographyCategory
    var eventType: ShootingEventType
    var location: ShootingLocation
    var startTime: Date
    var endTime: Date
    var importanceScore: Int
    var importanceLevel: EventImportanceLevel
    var description: String
    var tags: [String]
    var sourceType: ShootingEventSourceType

    var importanceExplanation: String {
        switch importanceLevel {
        case .normal:
            return "该事件为普通提醒，适合在时间和地点方便时顺手拍摄。"
        case .worthWatching:
            return "该事件值得关注，条件合适时建议预留到场时间。"
        case .rare:
            return "该事件出现频率较低，建议提前到场并开启提醒。"
        case .mustShoot:
            return "该事件为必拍级别，建议开启提醒并提前完成踩点。"
        }
    }
}

struct EventWatchlistItem: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var category: PhotographyCategory
    var keyword: String
    var displayName: String
    var isEnabled: Bool
    var createdAt: Date
}

struct EventWatchlistMatch: Identifiable, Hashable {
    var id: UUID { item.id }
    var item: EventWatchlistItem
    var event: ShootingEvent
}

struct EventWatchlistMatchingService {
    func matchedItems(
        for event: ShootingEvent,
        watchlist: [EventWatchlistItem]
    ) -> [EventWatchlistItem] {
        watchlist.filter { item in
            item.isEnabled &&
            item.category == event.category &&
            event.matchesWatchlistKeyword(item.keyword)
        }
    }

    func matchedItems(
        for events: [ShootingEvent],
        watchlist: [EventWatchlistItem]
    ) -> [EventWatchlistMatch] {
        events.flatMap { event in
            matchedItems(for: event, watchlist: watchlist).map { item in
                EventWatchlistMatch(item: item, event: event)
            }
        }
    }

    func priorityBoost(for window: ShootingWindow, watchlist: [EventWatchlistItem]) -> Int {
        let matches = matchedItems(for: window.eventRefs, watchlist: watchlist)
        let importance = window.eventRefs.map { Int($0.importanceLevel.scoreWeight) }.max() ?? 0
        return matches.count * 20 + importance
    }
}

private extension ShootingEvent {
    func matchesWatchlistKeyword(_ keyword: String) -> Bool {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKeyword.isEmpty else { return false }

        let searchableText = ([title, description] + tags)
            .joined(separator: " ")
            .lowercased()
        return searchableText.contains(normalizedKeyword)
    }
}
