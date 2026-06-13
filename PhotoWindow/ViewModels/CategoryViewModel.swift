import Foundation
import Combine

@MainActor
final class CategoryViewModel: ObservableObject {
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let category: PhotographyCategory
    private let shootingWindowRepository: any ShootingWindowRepository
    private let analyticsService: any AnalyticsServicing

    init(
        category: PhotographyCategory,
        shootingWindowRepository: any ShootingWindowRepository,
        analyticsService: any AnalyticsServicing
    ) {
        self.category = category
        self.shootingWindowRepository = shootingWindowRepository
        self.analyticsService = analyticsService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            windows = try await shootingWindowRepository.fetchWindows(for: category)
            await analyticsService.record(.categoryOpened, category: category)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
