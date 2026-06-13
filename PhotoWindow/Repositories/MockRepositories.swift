import Foundation

@MainActor
final class MockRepositoryStore {
    var user: UserProfile
    var userPreference: UserPreference
    var locations: [ShootingLocation]
    var events: [ShootingEvent]
    var windows: [ShootingWindow]
    var alertRules: [AlertRule]
    var watchlistItems: [EventWatchlistItem]
    var notifications: [NotificationItem]

    init(seedData: MockSeedData = MockDataService().makeSeedData()) {
        user = seedData.user
        userPreference = seedData.userPreference
        locations = seedData.locations
        events = seedData.events
        windows = seedData.windows
        alertRules = seedData.alertRules
        watchlistItems = seedData.watchlistItems
        notifications = []
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

    func replaceWindows(_ windows: [ShootingWindow]) async throws {
        store.windows = windows.sorted { $0.startTime < $1.startTime }
    }
}

@MainActor
final class UserDefaultsSavedLocationRepository: SavedLocationRepository {
    private let userDefaults: UserDefaults
    private let key: String
    private let seedLocations: [ShootingLocation]

    init(
        seedLocations: [ShootingLocation],
        userDefaults: UserDefaults = .standard,
        key: String = "PhotoWindow.savedLocations.v5"
    ) {
        self.seedLocations = seedLocations
        self.userDefaults = userDefaults
        self.key = key
    }

    func fetchSavedLocations() async throws -> [ShootingLocation] {
        loadLocations().sorted {
            if $0.isFavorite == $1.isFavorite {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.isFavorite && !$1.isFavorite
        }
    }

    func saveLocation(_ location: ShootingLocation) async throws {
        var locations = loadLocations()
        guard !locations.contains(where: { $0.id == location.id }) else {
            try await updateLocation(location)
            return
        }
        locations.append(location)
        try saveLocations(locations)
    }

    func updateLocation(_ location: ShootingLocation) async throws {
        var locations = loadLocations()
        guard let index = locations.firstIndex(where: { $0.id == location.id }) else {
            throw RepositoryError.notFound
        }
        locations[index] = location
        try saveLocations(locations)
    }

    func deleteLocation(id: UUID) async throws {
        var locations = loadLocations()
        locations.removeAll { $0.id == id }
        try saveLocations(locations)
    }

    func toggleFavorite(locationId: UUID) async throws {
        var locations = loadLocations()
        guard let index = locations.firstIndex(where: { $0.id == locationId }) else {
            throw RepositoryError.notFound
        }
        locations[index].isFavorite.toggle()
        locations[index].updatedAt = Date()
        try saveLocations(locations)
    }

    func fetchFavoriteLocations() async throws -> [ShootingLocation] {
        try await fetchSavedLocations().filter(\.isFavorite)
    }

    private func loadLocations() -> [ShootingLocation] {
        guard let data = userDefaults.data(forKey: key) else {
            try? saveLocations(seedLocations)
            return seedLocations
        }

        guard let decoded = try? JSONDecoder().decode([ShootingLocation].self, from: data) else {
            try? saveLocations(seedLocations)
            return seedLocations
        }

        return decoded
    }

    private func saveLocations(_ locations: [ShootingLocation]) throws {
        let data = try JSONEncoder().encode(locations)
        userDefaults.set(data, forKey: key)
    }
}

@MainActor
final class MockWeatherRepository: WeatherRepository {
    private struct WeatherCacheEntry {
        var snapshots: [WeatherSnapshot]
        var fetchedAt: Date
    }

    private let store: MockRepositoryStore
    private let calendar = Calendar.current
    private var cache: [UUID: WeatherCacheEntry] = [:]
    private let cacheDuration: TimeInterval = 30 * 60

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchWeather(for location: ShootingLocation) async throws -> [WeatherSnapshot] {
        if let cached = cache[location.id], Date().timeIntervalSince(cached.fetchedAt) < cacheDuration {
            return cached.snapshots
        }

        let snapshots = makeForecast(for: location)
        cache[location.id] = WeatherCacheEntry(snapshots: snapshots, fetchedAt: Date())
        return snapshots
    }

    private func makeForecast(for location: ShootingLocation) -> [WeatherSnapshot] {
        (0..<7).map { dayOffset in
            let values = weatherValues(for: location, dayOffset: dayOffset)
            return weather(
                dayOffset: dayOffset,
                temperature: values.temperature,
                cloudCover: values.cloudCover,
                precipitation: values.precipitation,
                windSpeed: values.windSpeed,
                visibility: values.visibility,
                humidity: values.humidity,
                moonPhase: values.moonPhase,
                moonIllumination: values.moonIllumination
            )
        }
    }

    private func weatherValues(
        for location: ShootingLocation,
        dayOffset: Int
    ) -> (
        temperature: Double,
        cloudCover: Double,
        precipitation: Double,
        windSpeed: Double,
        visibility: Double,
        humidity: Double,
        moonPhase: String,
        moonIllumination: Double
    ) {
        let dailyCloudAdjustment = [6.0, -8.0, 12.0, -14.0, 4.0, -6.0, 10.0][min(dayOffset, 6)]
        let dailyRainAdjustment = [4.0, -3.0, 6.0, -4.0, 2.0, -2.0, 5.0][min(dayOffset, 6)]

        switch location.locationType {
        case .airport:
            return (
                24,
                clamp(38 + dailyCloudAdjustment),
                clamp(12 + dailyRainAdjustment),
                18,
                18,
                62,
                "Waxing Crescent",
                18
            )
        case .campus:
            return (
                23,
                clamp(58 + dailyCloudAdjustment),
                clamp(8 + dailyRainAdjustment),
                10,
                16,
                66,
                "First Quarter",
                48
            )
        case .darkSky:
            let cloudPattern = [42.0, 18.0, 32.0, 12.0]
            let rainPattern = [18.0, 6.0, 12.0, 5.0]
            return (
                17,
                cloudPattern[min(dayOffset, 3)],
                rainPattern[min(dayOffset, 3)],
                9,
                21,
                52,
                dayOffset == 3 ? "New Moon" : "Waxing Crescent",
                dayOffset == 3 ? 6 : 18
            )
        case .urban, .custom:
            return (
                22,
                clamp(54 + dailyCloudAdjustment),
                clamp(12 + dailyRainAdjustment),
                11,
                18,
                58,
                "Waxing Crescent",
                22
            )
        case .scenic, .portraitSpot:
            return (
                20,
                clamp(46 + dailyCloudAdjustment),
                clamp(10 + dailyRainAdjustment),
                12,
                19,
                60,
                "Waxing Crescent",
                22
            )
        case .wildlifeArea:
            return (
                21,
                clamp(48 + dailyCloudAdjustment),
                clamp(18 + dailyRainAdjustment),
                9,
                15,
                70,
                "Waxing Crescent",
                24
            )
        }
    }

    private func weather(
        dayOffset: Int,
        temperature: Double,
        cloudCover: Double,
        precipitation: Double,
        windSpeed: Double,
        visibility: Double,
        humidity: Double,
        moonPhase: String,
        moonIllumination: Double
    ) -> WeatherSnapshot {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) ?? Date()
        return WeatherSnapshot(
            temperature: temperature,
            cloudCover: cloudCover,
            precipitationProbability: precipitation,
            windSpeed: windSpeed,
            visibility: visibility,
            humidity: humidity,
            moonPhase: moonPhase,
            moonIllumination: moonIllumination,
            sunriseTime: time(on: date, hour: 5, minute: 52),
            sunsetTime: time(on: date, hour: 17, minute: 22),
            goldenHourStart: time(on: date, hour: 16, minute: 35),
            goldenHourEnd: time(on: date, hour: 17, minute: 35),
            blueHourStart: time(on: date, hour: 17, minute: 45),
            blueHourEnd: time(on: date, hour: 18, minute: 16)
        )
    }

    private func time(on date: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}

@MainActor
final class MockAstronomyRepository: AstronomyRepository {
    private struct AstronomyCacheEntry {
        var snapshot: AstronomySnapshot
        var fetchedAt: Date
    }

    private let calendar = Calendar.current
    private var cache: [String: AstronomyCacheEntry] = [:]
    private let cacheDuration: TimeInterval = 24 * 60 * 60

    func fetchAstronomy(for location: ShootingLocation, date: Date) async throws -> AstronomySnapshot {
        let key = cacheKey(location: location, date: date)
        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < cacheDuration {
            return cached.snapshot
        }

        let snapshot = makeAstronomy(for: location, date: date)
        cache[key] = AstronomyCacheEntry(snapshot: snapshot, fetchedAt: Date())
        return snapshot
    }

    private func makeAstronomy(for location: ShootingLocation, date: Date) -> AstronomySnapshot {
        let day = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: day).day ?? 0
        let moon = moonValues(dayOffset: dayOffset)
        let sunrise = time(on: day, hour: 5, minute: 52)
        let sunset = time(on: day, hour: 17, minute: 22)
        let goldenStart = calendar.date(byAdding: .minute, value: -47, to: sunset) ?? sunset
        let goldenEnd = calendar.date(byAdding: .minute, value: 13, to: sunset) ?? sunset
        let blueStart = calendar.date(byAdding: .minute, value: 23, to: sunset) ?? sunset
        let blueEnd = calendar.date(byAdding: .minute, value: 54, to: sunset) ?? sunset

        return AstronomySnapshot(
            date: day,
            sunriseTime: sunrise,
            sunsetTime: sunset,
            goldenHourStart: goldenStart,
            goldenHourEnd: goldenEnd,
            blueHourStart: blueStart,
            blueHourEnd: blueEnd,
            moonPhase: moon.phase,
            moonIllumination: moon.illumination
        )
    }

    private func moonValues(dayOffset: Int) -> (phase: String, illumination: Double) {
        switch ((dayOffset % 4) + 4) % 4 {
        case 0:
            return ("Waxing Crescent", 22)
        case 1:
            return ("New Moon", 8)
        case 2:
            return ("First Quarter", 48)
        default:
            return ("New Moon", 6)
        }
    }

    private func cacheKey(location: ShootingLocation, date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(location.id.uuidString)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func time(on date: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
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

    func upsertAlertRule(_ rule: AlertRule) async throws {
        if let index = store.alertRules.firstIndex(where: { $0.id == rule.id }) {
            store.alertRules[index] = rule
        } else {
            store.alertRules.append(rule)
        }
    }

    func deleteAlertRule(id: UUID) async throws {
        store.alertRules.removeAll { $0.id == id }
    }
}

@MainActor
final class UserDefaultsAlertRuleRepository: AlertRuleRepository {
    private let userDefaults: UserDefaults
    private let key = "PhotoWindow.alertRules.v3"
    private let seedRules: [AlertRule]

    init(seedRules: [AlertRule], userDefaults: UserDefaults = .standard) {
        self.seedRules = seedRules
        self.userDefaults = userDefaults
    }

    func fetchAlertRules() async throws -> [AlertRule] {
        let rules = loadRules()
        return rules.sorted {
            if $0.category.displayName == $1.category.displayName {
                return $0.location.name < $1.location.name
            }
            return $0.category.displayName < $1.category.displayName
        }
    }

    func updateAlertRule(_ rule: AlertRule) async throws {
        var rules = loadRules()
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            throw RepositoryError.notFound
        }
        rules[index] = rule
        try saveRules(rules)
    }

    func upsertAlertRule(_ rule: AlertRule) async throws {
        var rules = loadRules()
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
        try saveRules(rules)
    }

    func deleteAlertRule(id: UUID) async throws {
        var rules = loadRules()
        rules.removeAll { $0.id == id }
        try saveRules(rules)
    }

    private func loadRules() -> [AlertRule] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AlertRule].self, from: data) else {
            try? saveRules(seedRules)
            return seedRules
        }
        return decoded
    }

    private func saveRules(_ rules: [AlertRule]) throws {
        let data = try JSONEncoder().encode(rules)
        userDefaults.set(data, forKey: key)
    }
}

@MainActor
final class MockUserPreferenceRepository: UserPreferenceRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchPreference() async throws -> UserPreference {
        store.userPreference
    }

    func savePreference(_ preference: UserPreference) async throws {
        store.userPreference = preference
    }

    func updateFavoriteLocations(_ locationIds: [UUID]) async throws {
        store.userPreference.favoriteLocationIds = locationIds
    }

    func updateSelectedCategories(_ categories: [PhotographyCategory]) async throws {
        store.userPreference.selectedCategories = categories
    }
}

@MainActor
final class UserDefaultsUserPreferenceRepository: UserPreferenceRepository {
    private let userDefaults: UserDefaults
    private let key = "PhotoWindow.userPreference.v3"
    private let seedPreference: UserPreference

    init(seedPreference: UserPreference, userDefaults: UserDefaults = .standard) {
        self.seedPreference = seedPreference
        self.userDefaults = userDefaults
    }

    func fetchPreference() async throws -> UserPreference {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(UserPreference.self, from: data) else {
            try? await savePreference(seedPreference)
            return seedPreference
        }
        return decoded
    }

    func savePreference(_ preference: UserPreference) async throws {
        let data = try JSONEncoder().encode(preference)
        userDefaults.set(data, forKey: key)
    }

    func updateFavoriteLocations(_ locationIds: [UUID]) async throws {
        var preference = try await fetchPreference()
        preference.favoriteLocationIds = locationIds
        try await savePreference(preference)
    }

    func updateSelectedCategories(_ categories: [PhotographyCategory]) async throws {
        var preference = try await fetchPreference()
        preference.selectedCategories = categories
        try await savePreference(preference)
    }
}

@MainActor
final class MockNotificationItemRepository: NotificationItemRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchNotifications() async throws -> [NotificationItem] {
        store.notifications.sorted { $0.triggerTime < $1.triggerTime }
    }

    func replaceNotifications(_ notifications: [NotificationItem]) async throws {
        store.notifications = notifications.sorted { $0.triggerTime < $1.triggerTime }
    }

    func deleteNotification(id: UUID) async throws {
        store.notifications.removeAll { $0.id == id }
    }

    func deleteAllNotifications() async throws {
        store.notifications.removeAll()
    }
}

@MainActor
final class UserDefaultsNotificationItemRepository: NotificationItemRepository {
    private let userDefaults: UserDefaults
    private let key = "PhotoWindow.notifications.v3"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func fetchNotifications() async throws -> [NotificationItem] {
        loadNotifications()
            .filter { $0.triggerTime > Date() }
            .sorted { $0.triggerTime < $1.triggerTime }
    }

    func replaceNotifications(_ notifications: [NotificationItem]) async throws {
        try saveNotifications(notifications.sorted { $0.triggerTime < $1.triggerTime })
    }

    func deleteNotification(id: UUID) async throws {
        var notifications = loadNotifications()
        notifications.removeAll { $0.id == id }
        try saveNotifications(notifications)
    }

    func deleteAllNotifications() async throws {
        try saveNotifications([])
    }

    private func loadNotifications() -> [NotificationItem] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveNotifications(_ notifications: [NotificationItem]) throws {
        let data = try JSONEncoder().encode(notifications)
        userDefaults.set(data, forKey: key)
    }
}

@MainActor
final class UserDefaultsFeedbackRepository: FeedbackRepository {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "PhotoWindow.feedback.v4") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func submitFeedback(_ feedback: Feedback) async throws {
        var feedbackItems = loadFeedback()
        feedbackItems.removeAll {
            $0.windowId == feedback.windowId && $0.userId == feedback.userId
        }
        feedbackItems.append(feedback)
        try saveFeedback(feedbackItems.sorted { $0.createdAt > $1.createdAt })
    }

    func fetchFeedback() async throws -> [Feedback] {
        loadFeedback().sorted { $0.createdAt > $1.createdAt }
    }

    private func loadFeedback() -> [Feedback] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Feedback].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveFeedback(_ feedback: [Feedback]) throws {
        let data = try JSONEncoder().encode(feedback)
        userDefaults.set(data, forKey: key)
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

@MainActor
final class MockEventWatchlistRepository: EventWatchlistRepository {
    private let store: MockRepositoryStore

    init(store: MockRepositoryStore) {
        self.store = store
    }

    func fetchWatchlistItems() async throws -> [EventWatchlistItem] {
        store.watchlistItems.sorted {
            if $0.category.displayName == $1.category.displayName {
                return $0.displayName < $1.displayName
            }
            return $0.category.displayName < $1.category.displayName
        }
    }

    func updateWatchlistItem(_ item: EventWatchlistItem) async throws {
        guard let index = store.watchlistItems.firstIndex(where: { $0.id == item.id }) else {
            throw RepositoryError.notFound
        }
        store.watchlistItems[index] = item
    }
}
