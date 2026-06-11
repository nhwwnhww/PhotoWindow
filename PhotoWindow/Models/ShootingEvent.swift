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

struct ShootingEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: PhotographyCategory
    var eventType: ShootingEventType
    var location: ShootingLocation
    var startTime: Date
    var endTime: Date
    var importanceScore: Int
    var description: String
    var tags: [String]
    var sourceType: ShootingEventSourceType
}
