import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @State private var didRecordAppOpen = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeScreen()
            }
            .tabItem {
                Label("首页", systemImage: "radar")
            }

            NavigationStack {
                ExploreLocationsScreen()
            }
            .tabItem {
                Label("地点", systemImage: "mappin.and.ellipse")
            }

            NavigationStack {
                SpecialEventsScreen()
            }
            .tabItem {
                Label("事件", systemImage: "sparkles")
            }

            NavigationStack {
                AlertSettingsScreen()
            }
            .tabItem {
                Label("提醒", systemImage: "bell")
            }

            NavigationStack {
                OnboardingPreferenceScreen()
            }
            .tabItem {
                Label("偏好", systemImage: "slider.horizontal.3")
            }
        }
        .tint(Color.photoAccent)
        .task {
            guard !didRecordAppOpen else { return }
            didRecordAppOpen = true
            await container.analyticsService.record(.appOpened)
        }
    }
}

private struct HomeScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        HomeView(
            viewModel: HomeViewModel(
                shootingWindowRepository: container.shootingWindowRepository,
                savedLocationRepository: container.savedLocationRepository,
                weatherRepository: container.weatherRepository,
                astronomyRepository: container.astronomyRepository,
                aviationEventRepository: container.aviationEventRepository,
                specialEventRepository: container.specialEventRepository,
                specialEventDataService: container.specialEventDataService,
                alertRuleRepository: container.alertRuleRepository,
                userPreferenceRepository: container.userPreferenceRepository,
                notificationItemRepository: container.notificationItemRepository,
                eventWatchlistRepository: container.eventWatchlistRepository,
                userRepository: container.userRepository,
                notificationService: container.notificationService,
                analyticsService: container.analyticsService
            )
        )
    }
}

struct SpecialEventsScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        SpecialEventsView(
            viewModel: SpecialEventsViewModel(
                specialEventRepository: container.specialEventRepository,
                specialEventDataService: container.specialEventDataService,
                eventWatchlistRepository: container.eventWatchlistRepository
            )
        )
    }
}

struct SpecialEventDetailScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer
    let eventID: UUID

    var body: some View {
        SpecialEventDetailView(
            viewModel: SpecialEventDetailViewModel(
                eventID: eventID,
                specialEventRepository: container.specialEventRepository,
                specialEventDataService: container.specialEventDataService,
                shootingWindowRepository: container.shootingWindowRepository,
                weatherRepository: container.weatherRepository,
                astronomyRepository: container.astronomyRepository,
                alertRuleRepository: container.alertRuleRepository,
                userRepository: container.userRepository,
                notificationService: container.notificationService
            )
        )
    }
}

struct CategoryScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer
    let category: PhotographyCategory

    var body: some View {
        CategoryView(
            viewModel: CategoryViewModel(
                category: category,
                shootingWindowRepository: container.shootingWindowRepository,
                analyticsService: container.analyticsService
            )
        )
    }
}

struct ShootingWindowDetailScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer
    let windowID: UUID

    var body: some View {
        ShootingWindowDetailView(
            viewModel: ShootingWindowDetailViewModel(
                windowID: windowID,
                shootingWindowRepository: container.shootingWindowRepository,
                alertRuleRepository: container.alertRuleRepository,
                feedbackRepository: container.feedbackRepository,
                eventWatchlistRepository: container.eventWatchlistRepository,
                userRepository: container.userRepository,
                notificationService: container.notificationService,
                analyticsService: container.analyticsService
            )
        )
    }
}

private struct ExploreLocationsScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        ExploreLocationsView(
            viewModel: ExploreLocationsViewModel(
                savedLocationRepository: container.savedLocationRepository,
                shootingWindowRepository: container.shootingWindowRepository
            )
        )
    }
}

struct AddLocationScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer
    let existingLocation: ShootingLocation?

    init(existingLocation: ShootingLocation? = nil) {
        self.existingLocation = existingLocation
    }

    var body: some View {
        AddLocationView(
            viewModel: AddLocationViewModel(
                savedLocationRepository: container.savedLocationRepository,
                locationSearchService: container.locationSearchService,
                existingLocation: existingLocation
            )
        )
    }
}

struct LocationDetailScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer
    let locationID: UUID

    var body: some View {
        LocationDetailView(
            viewModel: LocationDetailViewModel(
                locationID: locationID,
                savedLocationRepository: container.savedLocationRepository,
                shootingWindowRepository: container.shootingWindowRepository,
                weatherRepository: container.weatherRepository,
                astronomyRepository: container.astronomyRepository,
                aviationEventRepository: container.aviationEventRepository,
                alertRuleRepository: container.alertRuleRepository,
                userRepository: container.userRepository
            )
        )
    }
}

private struct AlertSettingsScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        AlertSettingsView(
            viewModel: AlertSettingsViewModel(
                alertRuleRepository: container.alertRuleRepository,
                eventWatchlistRepository: container.eventWatchlistRepository,
                userRepository: container.userRepository,
                analyticsService: container.analyticsService
            )
        )
    }
}

struct DebugNotificationScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        DebugNotificationView(
            viewModel: DebugNotificationViewModel(
                notificationService: container.notificationService
            )
        )
    }
}

struct DataDebugScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        DataDebugView(
            viewModel: DataDebugViewModel(
                specialEventDataService: container.specialEventDataService,
                notificationService: container.notificationService,
                userPreferenceRepository: container.userPreferenceRepository
            )
        )
    }
}

struct UpcomingNotificationsScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        UpcomingNotificationsView(
            viewModel: UpcomingNotificationsViewModel(
                notificationItemRepository: container.notificationItemRepository,
                shootingWindowRepository: container.shootingWindowRepository,
                alertRuleRepository: container.alertRuleRepository,
                notificationService: container.notificationService
            )
        )
    }
}

private struct OnboardingPreferenceScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        OnboardingPreferenceView(
            viewModel: OnboardingPreferenceViewModel(
                userPreferenceRepository: container.userPreferenceRepository,
                shootingWindowRepository: container.shootingWindowRepository,
                alertRuleRepository: container.alertRuleRepository,
                userRepository: container.userRepository,
                notificationService: container.notificationService
            )
        )
    }
}
