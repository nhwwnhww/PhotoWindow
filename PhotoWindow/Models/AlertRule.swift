import Foundation

struct AlertRule: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var category: PhotographyCategory
    var location: ShootingLocation
    var locationId: UUID
    var eventType: ShootingEventType?
    var minScore: Int
    var remindBeforeMinutes: Int
    var isEnabled: Bool
    var keywords: [String]
    var createdAt: Date

    init(
        id: UUID,
        userId: UUID,
        category: PhotographyCategory,
        location: ShootingLocation,
        locationId: UUID? = nil,
        eventType: ShootingEventType? = nil,
        minScore: Int,
        remindBeforeMinutes: Int,
        isEnabled: Bool,
        keywords: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.category = category
        self.location = location
        self.locationId = locationId ?? location.id
        self.eventType = eventType
        self.minScore = minScore
        self.remindBeforeMinutes = remindBeforeMinutes
        self.isEnabled = isEnabled
        self.keywords = keywords
        self.createdAt = createdAt
    }
}
