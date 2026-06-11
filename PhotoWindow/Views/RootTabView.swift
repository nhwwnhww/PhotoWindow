import SwiftUI

struct RootTabView: View {
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
                AlertSettingsScreen()
            }
            .tabItem {
                Label("提醒", systemImage: "bell")
            }
        }
        .tint(Color.photoAccent)
    }
}

private struct HomeScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        HomeView(
            viewModel: HomeViewModel(
                shootingWindowRepository: container.shootingWindowRepository,
                userRepository: container.userRepository
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
                shootingWindowRepository: container.shootingWindowRepository
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
                notificationService: container.notificationService
            )
        )
    }
}

private struct ExploreLocationsScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        ExploreLocationsView(
            viewModel: LocationViewModel(
                shootingWindowRepository: container.shootingWindowRepository
            )
        )
    }
}

private struct AlertSettingsScreen: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        AlertSettingsView(
            viewModel: AlertSettingsViewModel(
                alertRuleRepository: container.alertRuleRepository
            )
        )
    }
}
