import Foundation

@MainActor
final class MockRepositoryStore {
    var user: UserProfile
    var locations: [ShootingLocation]
    var events: [ShootingEvent]
    var windows: [ShootingWindow]
    var alertRules: [AlertRule]

    init(seedData: MockSeedData = MockDataService().makeSeedData()) {
        user = seedData.user
        locations = seedData.locations
        events = seedData.events
        windows = seedData.windows
        alertRules = seedData.alertRules
    }
}

@MainActor
final class MockShootingWindowRepository: ShootingWindowRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchWindows() async throws -> [ShootingWindow] {
        store.windows.sorted { $0.startTime < $1.startTime }
    }

    func fetchWindows(for category: PhotographyCategory) async throws -> [ShootingWindow] {
        store.windows
            .filter { $0.category == category }
            .sorted { $0.startTime < $1.startTime }
    }

    func fetchWindow(id: UUID) async throws -> ShootingWindow {
        guard let window = store.windows.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return window
    }

    func fetchLocations() async throws -> [ShootingLocation] {
        store.locations
    }

    func updateWindow(_ window: ShootingWindow) async throws {
        guard let index = store.windows.firstIndex(where: { $0.id == window.id }) else {
            throw RepositoryError.notFound
        }
        store.windows[index] = window
    }
}

@MainActor
final class MockWeatherRepository: WeatherRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchWeather(for location: ShootingLocation, around date: Date) async throws -> WeatherSnapshot {
        if let window = store.windows.first(where: { $0.location.id == location.id }) {
            return window.weatherSnapshot
        }
        guard let fallback = store.windows.first?.weatherSnapshot else {
            throw RepositoryError.notFound
        }
        return fallback
    }
}

@MainActor
final class MockAviationEventRepository: AviationEventRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchAviationEvents(for location: ShootingLocation) async throws -> [ShootingEvent] {
        store.events
            .filter { $0.category == .aviation && $0.location.id == location.id }
            .sorted { $0.startTime < $1.startTime }
    }
}

@MainActor
final class MockAlertRuleRepository: AlertRuleRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchAlertRules() async throws -> [AlertRule] {
        store.alertRules.sorted { $0.category.displayName < $1.category.displayName }
    }

    func updateAlertRule(_ rule: AlertRule) async throws {
        guard let index = store.alertRules.firstIndex(where: { $0.id == rule.id }) else {
            throw RepositoryError.notFound
        }
        store.alertRules[index] = rule
    }

    func deleteAlertRule(id: UUID) async throws {
        store.alertRules.removeAll { $0.id == id }
    }
}

@MainActor
final class MockUserRepository: UserRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchCurrentUser() async throws -> UserProfile {
        store.user
    }
}
