import Foundation
import Combine

@MainActor
final class LocationViewModel: ObservableObject {
    @Published private(set) var locations: [ShootingLocation] = []
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let shootingWindowRepository: any ShootingWindowRepository

    init(shootingWindowRepository: any ShootingWindowRepository) {
        self.shootingWindowRepository = shootingWindowRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            locations = try await shootingWindowRepository.fetchLocations()
            windows = try await shootingWindowRepository.fetchWindows()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func windowCount(for location: ShootingLocation) -> Int {
        windows.filter { $0.location.id == location.id }.count
    }
}
