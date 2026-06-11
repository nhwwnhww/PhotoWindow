import Foundation

struct NotificationItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var triggerTime: Date
    var relatedWindow: ShootingWindow?
    var isRead: Bool
    var createdAt: Date
}
