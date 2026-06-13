import Foundation

enum AnalyticsEventName: String, CaseIterable, Codable, Hashable {
    case appOpened = "app_opened"
    case homeWindowViewed = "home_window_viewed"
    case categoryOpened = "category_opened"
    case windowDetailOpened = "window_detail_opened"
    case alertEnabled = "alert_enabled"
    case alertDisabled = "alert_disabled"
    case notificationClicked = "notification_clicked"
    case windowBookmarked = "window_bookmarked"
    case feedbackSubmitted = "feedback_submitted"
}

struct AnalyticsEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var name: AnalyticsEventName
    var category: PhotographyCategory?
    var locationId: UUID?
    var windowId: UUID?
    var score: Int?
    var scoreLevel: ShootingWindowScoreLevel?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        name: AnalyticsEventName,
        category: PhotographyCategory? = nil,
        locationId: UUID? = nil,
        windowId: UUID? = nil,
        score: Int? = nil,
        scoreLevel: ShootingWindowScoreLevel? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.locationId = locationId
        self.windowId = windowId
        self.score = score
        self.scoreLevel = scoreLevel
        self.timestamp = timestamp
    }
}
