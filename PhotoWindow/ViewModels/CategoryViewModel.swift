import Foundation
import Combine

@MainActor
final class CategoryViewModel: ObservableObject {
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let category: PhotographyCategory
    private let shootingWindowRepository: any ShootingWindowRepository

    init(category: PhotographyCategory, shootingWindowRepository: any ShootingWindowRepository) {
        self.category = category
        self.shootingWindowRepository = shootingWindowRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            windows = try await shootingWindowRepository.fetchWindows(for: category)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
