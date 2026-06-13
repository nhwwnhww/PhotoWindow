import Foundation

enum RepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Requested item was not found in the mock repository."
        }
    }
}

@MainActor
protocol ShootingWindowRepository {
    func fetchWindows() async throws -> [ShootingWindow]
    func fetchWindows(for category: PhotographyCategory) async throws -> [ShootingWindow]
    func fetchWindow(id: UUID) async throws -> ShootingWindow
    func fetchLocations() async throws -> [ShootingLocation]
    func updateWindow(_ window: ShootingWindow) async throws
    func replaceWindows(_ windows: [ShootingWindow]) async throws
}

@MainActor
protocol SavedLocationRepository {
    func fetchSavedLocations() async throws -> [ShootingLocation]
    func saveLocation(_ location: ShootingLocation) async throws
    func updateLocation(_ location: ShootingLocation) async throws
    func deleteLocation(id: UUID) async throws
    func toggleFavorite(locationId: UUID) async throws
    func fetchFavoriteLocations() async throws -> [ShootingLocation]
}

@MainActor
protocol WeatherRepository {
    func fetchWeather(for location: ShootingLocation) async throws -> [WeatherSnapshot]
}

@MainActor
protocol AstronomyRepository {
    func fetchAstronomy(for location: ShootingLocation, date: Date) async throws -> AstronomySnapshot
}

@MainActor
protocol AviationEventRepository {
    func fetchAviationEvents(for location: ShootingLocation) async throws -> [ShootingEvent]
}

@MainActor
protocol SpecialEventRepository {
    func fetchSpecialEvents() async throws -> [SpecialEvent]
    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent]
    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent]
}

@MainActor
protocol AlertRuleRepository {
    func fetchAlertRules() async throws -> [AlertRule]
    func updateAlertRule(_ rule: AlertRule) async throws
    func upsertAlertRule(_ rule: AlertRule) async throws
    func deleteAlertRule(id: UUID) async throws
}

@MainActor
protocol UserPreferenceRepository {
    func fetchPreference() async throws -> UserPreference
    func savePreference(_ preference: UserPreference) async throws
    func updateFavoriteLocations(_ locationIds: [UUID]) async throws
    func updateSelectedCategories(_ categories: [PhotographyCategory]) async throws
}

@MainActor
protocol NotificationItemRepository {
    func fetchNotifications() async throws -> [NotificationItem]
    func replaceNotifications(_ notifications: [NotificationItem]) async throws
    func deleteNotification(id: UUID) async throws
    func deleteAllNotifications() async throws
}

@MainActor
protocol FeedbackRepository {
    func submitFeedback(_ feedback: Feedback) async throws
    func fetchFeedback() async throws -> [Feedback]
}

@MainActor
protocol EventWatchlistRepository {
    func fetchWatchlistItems() async throws -> [EventWatchlistItem]
    func updateWatchlistItem(_ item: EventWatchlistItem) async throws
}

@MainActor
protocol UserRepository {
    func fetchCurrentUser() async throws -> UserProfile
}
