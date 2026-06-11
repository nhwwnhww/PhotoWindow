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
}

@MainActor
protocol WeatherRepository {
    func fetchWeather(for location: ShootingLocation, around date: Date) async throws -> WeatherSnapshot
}

@MainActor
protocol AviationEventRepository {
    func fetchAviationEvents(for location: ShootingLocation) async throws -> [ShootingEvent]
}

@MainActor
protocol AlertRuleRepository {
    func fetchAlertRules() async throws -> [AlertRule]
    func updateAlertRule(_ rule: AlertRule) async throws
    func deleteAlertRule(id: UUID) async throws
}

@MainActor
protocol UserRepository {
    func fetchCurrentUser() async throws -> UserProfile
}
