import Foundation

struct AlertRule: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var category: PhotographyCategory
    var location: ShootingLocation
    var eventType: ShootingEventType?
    var minScore: Int
    var remindBeforeMinutes: Int
    var isEnabled: Bool
    var keywords: [String]
}
