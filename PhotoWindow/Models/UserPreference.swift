import Foundation

struct UserPreference: Identifiable, Codable, Hashable {
    let id: UUID
    var selectedCategories: [PhotographyCategory]
    var favoriteLocationIds: [UUID]
    var defaultMinScore: Int
    var defaultReminderMinutes: Int
    var dailySummaryEnabled: Bool
    var notificationPreference: NotificationPreference? = nil
    var onboardingCompletedAt: Date? = nil

    var effectiveNotificationPreference: NotificationPreference {
        notificationPreference ?? NotificationPreference.defaultValue
    }
}
