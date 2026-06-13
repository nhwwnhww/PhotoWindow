import Foundation
import Combine

@MainActor
final class AppDependencyContainer: ObservableObject {
    let shootingWindowRepository: any ShootingWindowRepository
    let savedLocationRepository: any SavedLocationRepository
    let weatherRepository: any WeatherRepository
    let astronomyRepository: any AstronomyRepository
    let aviationEventRepository: any AviationEventRepository
    let specialEventRepository: any SpecialEventRepository
    let specialEventDataService: SpecialEventDataService
    let alertRuleRepository: any AlertRuleRepository
    let userPreferenceRepository: any UserPreferenceRepository
    let notificationItemRepository: any NotificationItemRepository
    let feedbackRepository: any FeedbackRepository
    let eventWatchlistRepository: any EventWatchlistRepository
    let userRepository: any UserRepository
    let notificationService: any NotificationServicing
    let analyticsService: any AnalyticsServicing
    let locationSearchService: any LocationSearchServicing

    init(
        shootingWindowRepository: any ShootingWindowRepository,
        savedLocationRepository: any SavedLocationRepository,
        weatherRepository: any WeatherRepository,
        astronomyRepository: any AstronomyRepository,
        aviationEventRepository: any AviationEventRepository,
        specialEventRepository: any SpecialEventRepository,
        specialEventDataService: SpecialEventDataService,
        alertRuleRepository: any AlertRuleRepository,
        userPreferenceRepository: any UserPreferenceRepository,
        notificationItemRepository: any NotificationItemRepository,
        feedbackRepository: any FeedbackRepository,
        eventWatchlistRepository: any EventWatchlistRepository,
        userRepository: any UserRepository,
        notificationService: any NotificationServicing,
        analyticsService: any AnalyticsServicing,
        locationSearchService: any LocationSearchServicing
    ) {
        self.shootingWindowRepository = shootingWindowRepository
        self.savedLocationRepository = savedLocationRepository
        self.weatherRepository = weatherRepository
        self.astronomyRepository = astronomyRepository
        self.aviationEventRepository = aviationEventRepository
        self.specialEventRepository = specialEventRepository
        self.specialEventDataService = specialEventDataService
        self.alertRuleRepository = alertRuleRepository
        self.userPreferenceRepository = userPreferenceRepository
        self.notificationItemRepository = notificationItemRepository
        self.feedbackRepository = feedbackRepository
        self.eventWatchlistRepository = eventWatchlistRepository
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.analyticsService = analyticsService
        self.locationSearchService = locationSearchService
    }

    static func mock() -> AppDependencyContainer {
        let environment = AppEnvironment.development
        let store = MockRepositoryStore()
        let alertRuleRepository = UserDefaultsAlertRuleRepository(seedRules: store.alertRules)
        let userPreferenceRepository = UserDefaultsUserPreferenceRepository(seedPreference: store.userPreference)
        let notificationItemRepository = UserDefaultsNotificationItemRepository()
        let bundledSpecialEventRepository = LocalJSONSpecialEventRepository()
        let remoteSpecialEventRepository = RemoteSpecialEventRepository(
            baseURL: environment.apiConfig.baseURL
        )
        let mockSpecialEventRepository = MockSpecialEventRepository()
        let specialEventCacheService = SpecialEventCacheService()
        let specialEventDataService = SpecialEventDataService(
            config: environment.apiConfig,
            remoteRepository: remoteSpecialEventRepository,
            bundledRepository: bundledSpecialEventRepository,
            mockRepository: mockSpecialEventRepository,
            cacheService: specialEventCacheService
        )

        return AppDependencyContainer(
            shootingWindowRepository: MockShootingWindowRepository(store: store),
            savedLocationRepository: UserDefaultsSavedLocationRepository(seedLocations: store.locations),
            weatherRepository: MockWeatherRepository(store: store),
            astronomyRepository: MockAstronomyRepository(),
            aviationEventRepository: MockAviationEventRepository(store: store),
            specialEventRepository: bundledSpecialEventRepository,
            specialEventDataService: specialEventDataService,
            alertRuleRepository: alertRuleRepository,
            userPreferenceRepository: userPreferenceRepository,
            notificationItemRepository: notificationItemRepository,
            feedbackRepository: UserDefaultsFeedbackRepository(),
            eventWatchlistRepository: MockEventWatchlistRepository(store: store),
            userRepository: MockUserRepository(store: store),
            notificationService: NotificationService(),
            analyticsService: AnalyticsService(),
            locationSearchService: RemoteLocationSearchService(
                fallbackService: LocationSearchService()
            )
        )
    }
}
