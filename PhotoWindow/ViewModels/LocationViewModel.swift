import Foundation
import Combine

@MainActor
final class ExploreLocationsViewModel: ObservableObject {
    @Published private(set) var savedLocations: [ShootingLocation] = []
    @Published private(set) var favoriteLocations: [ShootingLocation] = []
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var isLoading = false
    @Published var selectedType: ShootingLocationType?
    @Published var errorMessage: String?

    private let savedLocationRepository: any SavedLocationRepository
    private let shootingWindowRepository: any ShootingWindowRepository

    init(
        savedLocationRepository: any SavedLocationRepository,
        shootingWindowRepository: any ShootingWindowRepository
    ) {
        self.savedLocationRepository = savedLocationRepository
        self.shootingWindowRepository = shootingWindowRepository
    }

    var filteredSavedLocations: [ShootingLocation] {
        guard let selectedType else { return savedLocations }
        return savedLocations.filter { $0.locationType == selectedType }
    }

    var filteredFavoriteLocations: [ShootingLocation] {
        guard let selectedType else { return favoriteLocations }
        return favoriteLocations.filter { $0.locationType == selectedType }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            savedLocations = try await savedLocationRepository.fetchSavedLocations()
            favoriteLocations = try await savedLocationRepository.fetchFavoriteLocations()
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
