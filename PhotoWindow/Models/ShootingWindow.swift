import Foundation

enum ShootingWindowScoreLevel: String, CaseIterable, Identifiable, Codable, Hashable {
    case poor
    case okay
    case good
    case excellent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .poor:
            return "较差"
        case .okay:
            return "可尝试"
        case .good:
            return "不错"
        case .excellent:
            return "极佳"
        }
    }

    static func from(score: Int) -> ShootingWindowScoreLevel {
        switch score {
        case 85...100:
            return .excellent
        case 70..<85:
            return .good
        case 45..<70:
            return .okay
        default:
            return .poor
        }
    }
}

struct ShootingWindow: Identifiable, Codable, Hashable {
    let id: UUID
    var category: PhotographyCategory
    var location: ShootingLocation
    var startTime: Date
    var endTime: Date
    var windowTitle: String
    var score: Int
    var scoreLevel: ShootingWindowScoreLevel
    var reasonSummary: String
    var weatherSnapshot: WeatherSnapshot
    var eventRefs: [ShootingEvent]
    var recommendationText: String
    var isBookmarked: Bool
    var alertEnabled: Bool
}
