import Foundation

struct RecommendationResult: Codable, Hashable {
    var score: Int
    var scoreLevel: ShootingWindowScoreLevel
    var confidenceLevel: SpecialEventConfidenceLevel
    var reasonTags: [String]
    var penaltyTags: [String]
    var reasonSummary: String
    var penaltySummary: String?
    var recommendationText: String
    var arrivalSuggestionMinutes: Int
    var riskNotes: [String]
    var suitableFor: [String]
    var shouldNotifyByDefault: Bool

    static func fallback(
        score: Int,
        scoreLevel: ShootingWindowScoreLevel,
        reasonTags: [String],
        reasonSummary: String,
        notRecommendedReason: String?,
        recommendationText: String,
        arrivalSuggestionMinutes: Int,
        category: PhotographyCategory,
        hasHighValueEvent: Bool
    ) -> RecommendationResult {
        RecommendationResult(
            score: score,
            scoreLevel: scoreLevel,
            confidenceLevel: score >= 80 ? .high : (score >= 65 ? .medium : .low),
            reasonTags: reasonTags,
            penaltyTags: notRecommendedReason == nil ? [] : ["条件不稳定"],
            reasonSummary: reasonSummary,
            penaltySummary: notRecommendedReason,
            recommendationText: recommendationText,
            arrivalSuggestionMinutes: arrivalSuggestionMinutes,
            riskNotes: notRecommendedReason.map { [$0] } ?? [],
            suitableFor: Self.defaultSuitableFor(category: category),
            shouldNotifyByDefault: score >= 75 || hasHighValueEvent
        )
    }

    static func defaultSuitableFor(category: PhotographyCategory) -> [String] {
        switch category {
        case .astro:
            return ["星空摄影", "银河计划", "愿意提前踩点的摄影师"]
        case .aviation:
            return ["航空摄影", "特殊机型追踪", "长焦拍摄"]
        case .landscape:
            return ["风光摄影", "日出日落", "三脚架慢门"]
        case .graduation:
            return ["毕业照", "校园人像", "小团队拍摄"]
        case .portrait:
            return ["人像摄影", "柔光拍摄", "轻量外拍"]
        case .cityscape:
            return ["城市风光", "蓝调夜景", "建筑摄影"]
        case .wildlife:
            return ["野生动物", "长焦观察", "清晨拍摄"]
        }
    }
}
