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
    var shouldMergeNearbyReminders: Bool
    var quietHoursStart: Int
    var quietHoursEnd: Int
    var dailyMaxNotifications: Int
    var minScoreForNotification: Int
    var allowMustShootOverride: Bool
    var mergeNearbyNotifications: Bool

    static let defaultValue = NotificationPreference()

    var quietHoursDescription: String {
        "\(String(format: "%02d:00", quietHoursStart))-\(String(format: "%02d:00", quietHoursEnd))"
    }

    init(
        isEnabled: Bool = true,
        defaultRemindBeforeMinutes: Int = 60,
        shouldMergeNearbyReminders: Bool = true,
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 7,
        dailyMaxNotifications: Int = 5,
        minScoreForNotification: Int = 75,
        allowMustShootOverride: Bool = true,
        mergeNearbyNotifications: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.defaultRemindBeforeMinutes = defaultRemindBeforeMinutes
        self.shouldMergeNearbyReminders = shouldMergeNearbyReminders
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.dailyMaxNotifications = dailyMaxNotifications
        self.minScoreForNotification = minScoreForNotification
        self.allowMustShootOverride = allowMustShootOverride
        self.mergeNearbyNotifications = mergeNearbyNotifications
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case defaultRemindBeforeMinutes
        case shouldMergeNearbyReminders
        case quietHoursStart
        case quietHoursEnd
        case dailyMaxNotifications
        case minScoreForNotification
        case allowMustShootOverride
        case mergeNearbyNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        defaultRemindBeforeMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultRemindBeforeMinutes) ?? 60
        shouldMergeNearbyReminders = try container.decodeIfPresent(Bool.self, forKey: .shouldMergeNearbyReminders) ?? true
        quietHoursStart = try container.decodeIfPresent(Int.self, forKey: .quietHoursStart) ?? 22
        quietHoursEnd = try container.decodeIfPresent(Int.self, forKey: .quietHoursEnd) ?? 7
        dailyMaxNotifications = try container.decodeIfPresent(Int.self, forKey: .dailyMaxNotifications) ?? 5
        minScoreForNotification = try container.decodeIfPresent(Int.self, forKey: .minScoreForNotification) ?? 75
        allowMustShootOverride = try container.decodeIfPresent(Bool.self, forKey: .allowMustShootOverride) ?? true
        mergeNearbyNotifications = try container.decodeIfPresent(Bool.self, forKey: .mergeNearbyNotifications) ??
            shouldMergeNearbyReminders
    }
}
