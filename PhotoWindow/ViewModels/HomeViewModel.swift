import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var user: UserProfile?
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let shootingWindowRepository: any ShootingWindowRepository
    private let userRepository: any UserRepository

    init(
        shootingWindowRepository: any ShootingWindowRepository,
        userRepository: any UserRepository
    ) {
        self.shootingWindowRepository = shootingWindowRepository
        self.userRepository = userRepository
    }

    var todayRecommendations: [ShootingWindow] {
        windows
            .filter { Calendar.current.isDateInToday($0.startTime) || $0.startTime > Date() }
            .sorted { $0.score > $1.score }
    }

    var topWindows: [ShootingWindow] {
        Array(windows.sorted { $0.score > $1.score }.prefix(3))
    }

    var specialEvents: [ShootingWindow] {
        windows
            .filter { window in
                window.eventRefs.contains { $0.eventType == .specialAircraft || $0.eventType == .meteorShower || $0.eventType == .graduationSeason }
            }
            .sorted { $0.startTime < $1.startTime }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            user = try await userRepository.fetchCurrentUser()
            windows = try await shootingWindowRepository.fetchWindows()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
