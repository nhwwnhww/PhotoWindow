import Foundation
import Combine

@MainActor
final class AppDependencyContainer: ObservableObject {
    let shootingWindowRepository: any ShootingWindowRepository
    let weatherRepository: any WeatherRepository
    let aviationEventRepository: any AviationEventRepository
    let alertRuleRepository: any AlertRuleRepository
    let userRepository: any UserRepository
    let notificationService: any NotificationServicing

    init(
        shootingWindowRepository: any ShootingWindowRepository,
        weatherRepository: any WeatherRepository,
        aviationEventRepository: any AviationEventRepository,
        alertRuleRepository: any AlertRuleRepository,
        userRepository: any UserRepository,
        notificationService: any NotificationServicing
    ) {
        self.shootingWindowRepository = shootingWindowRepository
        self.weatherRepository = weatherRepository
        self.aviationEventRepository = aviationEventRepository
        self.alertRuleRepository = alertRuleRepository
        self.userRepository = userRepository
        self.notificationService = notificationService
    }

    static func mock() -> AppDependencyContainer {
        let store = MockRepositoryStore()
        return AppDependencyContainer(
            shootingWindowRepository: MockShootingWindowRepository(store: store),
            weatherRepository: MockWeatherRepository(store: store),
            aviationEventRepository: MockAviationEventRepository(store: store),
            alertRuleRepository: MockAlertRuleRepository(store: store),
            userRepository: MockUserRepository(store: store),
            notificationService: NotificationService()
        )
    }
}
