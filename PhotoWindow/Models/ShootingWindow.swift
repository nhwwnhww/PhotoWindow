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
            return "不推荐"
        case .okay:
            return "一般"
        case .good:
            return "适合"
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
        case 50..<70:
            return .okay
        default:
            return .poor
        }
    }
}

struct ScoreBreakdownItem: Identifiable, Codable, Hashable {
    var id: String { title }
    var title: String
    var score: Int
    var maxScore: Int
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
    var reasonTags: [String]
    var scoreBreakdown: [ScoreBreakdownItem]
    var notRecommendedReason: String?
    var weatherSnapshot: WeatherSnapshot
    var eventRefs: [ShootingEvent]
    var recommendationText: String
    var recommendationResult: RecommendationResult? = nil
    var isBookmarked: Bool
    var alertEnabled: Bool

    var primaryEvent: ShootingEvent? {
        eventRefs.max {
            if $0.importanceLevel.scoreWeight == $1.importanceLevel.scoreWeight {
                return $0.importanceScore < $1.importanceScore
            }
            return $0.importanceLevel.scoreWeight < $1.importanceLevel.scoreWeight
        }
    }

    var suggestedArrivalTime: Date {
        Calendar.current.date(
            byAdding: .minute,
            value: -effectiveRecommendationResult.arrivalSuggestionMinutes,
            to: startTime
        ) ?? startTime
    }

    var effectiveRecommendationResult: RecommendationResult {
        recommendationResult ?? RecommendationResult.fallback(
            score: score,
            scoreLevel: scoreLevel,
            reasonTags: reasonTags,
            reasonSummary: reasonSummary,
            notRecommendedReason: notRecommendedReason,
            recommendationText: recommendationText,
            arrivalSuggestionMinutes: category.defaultArrivalLeadMinutes,
            category: category,
            hasHighValueEvent: primaryEvent.map { $0.importanceLevel == .mustShoot || $0.importanceLevel == .rare } ?? false
        )
    }

    var penaltyTags: [String] {
        effectiveRecommendationResult.penaltyTags
    }

    var riskNotes: [String] {
        effectiveRecommendationResult.riskNotes
    }

    var suitableFor: [String] {
        effectiveRecommendationResult.suitableFor
    }

    var shouldNotifyByDefault: Bool {
        effectiveRecommendationResult.shouldNotifyByDefault
    }

    var defaultReminderLeadMinutes: Int {
        if eventRefs.contains(where: { $0.eventType == .specialAircraft }) {
            return 60
        }

        if category == .landscape && Calendar.current.component(.hour, from: startTime) < 8 {
            return 1_440
        }

        switch category {
        case .astro:
            return 1_500
        case .graduation, .portrait:
            return 180
        case .landscape, .cityscape:
            return 60
        case .aviation:
            return 60
        case .wildlife:
            return 60
        }
    }
}
