import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var avatarURL: URL?
    var preferredCategories: [PhotographyCategory]
    var homeLocation: ShootingLocation
    var cameraTags: [String]
    var skillTags: [String]
    var notificationPreference: NotificationPreference
}

struct NotificationPreference: Codable, Hashable {
    var isEnabled: Bool
    var defaultRemindBeforeMinutes: Int
    var quietHoursStart: Int?
    var quietHoursEnd: Int?
}
