import Foundation
import Combine

@MainActor
final class LocationDetailViewModel: ObservableObject {
    @Published private(set) var location: ShootingLocation?
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var alertRules: [AlertRule] = []
    @Published private(set) var isLoading = false
    @Published private(set) var didDelete = false
    @Published var errorMessage: String?

    private let locationID: UUID
    private let savedLocationRepository: any SavedLocationRepository
    private let shootingWindowRepository: any ShootingWindowRepository
    private let weatherRepository: any WeatherRepository
    private let astronomyRepository: any AstronomyRepository
    private let aviationEventRepository: any AviationEventRepository
    private let alertRuleRepository: any AlertRuleRepository
    private let userRepository: any UserRepository
    private let generationService = ShootingWindowGenerationService()
    private let calendar = Calendar.current

    init(
        locationID: UUID,
        savedLocationRepository: any SavedLocationRepository,
        shootingWindowRepository: any ShootingWindowRepository,
        weatherRepository: any WeatherRepository,
        astronomyRepository: any AstronomyRepository,
        aviationEventRepository: any AviationEventRepository,
        alertRuleRepository: any AlertRuleRepository,
        userRepository: any UserRepository
    ) {
        self.locationID = locationID
        self.savedLocationRepository = savedLocationRepository
        self.shootingWindowRepository = shootingWindowRepository
        self.weatherRepository = weatherRepository
        self.astronomyRepository = astronomyRepository
        self.aviationEventRepository = aviationEventRepository
        self.alertRuleRepository = alertRuleRepository
        self.userRepository = userRepository
    }

    var supportedCategories: [PhotographyCategory] {
        guard let location else { return [] }
        return generationService.categories(for: location)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let fetchedLocation = try await savedLocationRepository
                .fetchSavedLocations()
                .first(where: { $0.id == locationID }) else {
                throw RepositoryError.notFound
            }

            location = fetchedLocation
            alertRules = try await alertRuleRepository
                .fetchAlertRules()
                .filter { $0.locationId == fetchedLocation.id }
            windows = try await generateWindows(for: fetchedLocation)
            try await mergeGeneratedWindows(windows, locationID: fetchedLocation.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite() async {
        do {
            try await savedLocationRepository.toggleFavorite(locationId: locationID)
            location = try await savedLocationRepository
                .fetchSavedLocations()
                .first(where: { $0.id == locationID })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteLocation() async {
        do {
            try await savedLocationRepository.deleteLocation(id: locationID)
            let remainingWindows = try await shootingWindowRepository
                .fetchWindows()
                .filter { $0.location.id != locationID }
            try await shootingWindowRepository.replaceWindows(remainingWindows)
            didDelete = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAlertRule(for category: PhotographyCategory) async {
        guard let location else { return }

        do {
            let user = try await userRepository.fetchCurrentUser()
            let rules = try await alertRuleRepository.fetchAlertRules()
            if var existing = rules.first(where: { $0.locationId == location.id && $0.category == category }) {
                existing.isEnabled = true
                existing.minScore = min(existing.minScore, 75)
                existing.keywords = alertKeywords(for: location, category: category)
                try await alertRuleRepository.upsertAlertRule(existing)
            } else {
                let rule = AlertRule(
                    id: UUID(),
                    userId: user.id,
                    category: category,
                    location: location,
                    minScore: 75,
                    remindBeforeMinutes: defaultReminderMinutes(for: category),
                    isEnabled: true,
                    keywords: alertKeywords(for: location, category: category)
                )
                try await alertRuleRepository.upsertAlertRule(rule)
            }

            alertRules = try await alertRuleRepository
                .fetchAlertRules()
                .filter { $0.locationId == location.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateWindows(for location: ShootingLocation) async throws -> [ShootingWindow] {
        let weatherSnapshots = try await weatherRepository.fetchWeather(for: location)
        let astronomySnapshots = try await fetchAstronomySnapshots(for: location, weatherSnapshots: weatherSnapshots)
        let existingWindows = try await shootingWindowRepository.fetchWindows()
        let existingEvents = uniqueEvents(from: existingWindows.flatMap(\.eventRefs))
        var generated: [ShootingWindow] = []

        for category in generationService.categories(for: location) {
            let categoryEvents = try await events(for: category, location: location, existingEvents: existingEvents)
            generated.append(
                contentsOf: generationService.generateWindows(
                    location: location,
                    weatherSnapshots: weatherSnapshots,
                    astronomySnapshots: astronomySnapshots,
                    category: category,
                    events: categoryEvents
                )
            )
        }

        let sevenDaysOut = Date().addingTimeInterval(7 * 24 * 60 * 60)
        return generated
            .filter { $0.startTime >= Date() && $0.startTime <= sevenDaysOut }
            .sorted {
                if $0.score == $1.score {
                    return $0.startTime < $1.startTime
                }
                return $0.score > $1.score
            }
    }

    private func fetchAstronomySnapshots(
        for location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot]
    ) async throws -> [AstronomySnapshot] {
        let dates = uniqueDates(from: weatherSnapshots.map(\.sunriseTime))
        var snapshots: [AstronomySnapshot] = []

        for date in dates {
            snapshots.append(try await astronomyRepository.fetchAstronomy(for: location, date: date))
        }

        return snapshots.sorted { $0.date < $1.date }
    }

    private func events(
        for category: PhotographyCategory,
        location: ShootingLocation,
        existingEvents: [ShootingEvent]
    ) async throws -> [ShootingEvent] {
        let localEvents = existingEvents.filter {
            $0.category == category && $0.location.id == location.id
        }

        guard category == .aviation else {
            return localEvents
        }

        let aviationEvents = try await aviationEventRepository.fetchAviationEvents(for: location)
        return uniqueEvents(from: localEvents + aviationEvents)
    }

    private func mergeGeneratedWindows(_ generatedWindows: [ShootingWindow], locationID: UUID) async throws {
        let existing = try await shootingWindowRepository.fetchWindows()
        let merged = existing.filter { $0.location.id != locationID } + generatedWindows
        try await shootingWindowRepository.replaceWindows(merged)
    }

    private func defaultReminderMinutes(for category: PhotographyCategory) -> Int {
        switch category {
        case .astro:
            return 1_500
        case .aviation, .landscape, .cityscape, .wildlife:
            return 60
        case .portrait, .graduation:
            return 180
        }
    }

    private func alertKeywords(for location: ShootingLocation, category: PhotographyCategory) -> [String] {
        [location.name, location.locationType.displayName, category.displayName]
    }

    private func uniqueEvents(from events: [ShootingEvent]) -> [ShootingEvent] {
        var seen = Set<UUID>()
        return events.filter { seen.insert($0.id).inserted }
    }

    private func uniqueDates(from dates: [Date]) -> [Date] {
        var seen = Set<Date>()
        return dates
            .map { calendar.startOfDay(for: $0) }
            .filter { seen.insert($0).inserted }
            .sorted()
    }
}
