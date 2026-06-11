import Foundation

@main
struct VerifyCore {
    static func main() async throws {
        let scoringService = ShootingWindowScoringService()
        let seed = MockDataService().makeSeedData()

        try verifySeedData(seed)
        try verifyScoring(scoringService: scoringService, seed: seed)
        try await verifyRepositories(seed: seed)

        print("PhotoWindow core verification passed.")
    }

    private static func verifySeedData(_ seed: MockSeedData) throws {
        try require(seed.locations.count == 3, "Expected exactly 3 MVP locations.")
        try require(seed.windows.count >= 4, "Expected mock windows across MVP scenarios.")
        try require(seed.events.contains { $0.eventType == .specialAircraft }, "Expected a mock aviation event.")
        try require(seed.windows.contains { $0.category == .astro }, "Expected an astro window.")
        try require(seed.windows.contains { $0.category == .aviation }, "Expected an aviation window.")
        try require(seed.windows.contains { $0.category == .graduation }, "Expected a graduation window.")
    }

    private static func verifyScoring(
        scoringService: ShootingWindowScoringService,
        seed: MockSeedData
    ) throws {
        let location = seed.locations.first { $0.locationType == .darkSky }!
        let now = Date()
        let excellentAstroWeather = WeatherSnapshot(
            temperature: 17,
            cloudCover: 8,
            precipitationProbability: 3,
            windSpeed: 8,
            visibility: 22,
            humidity: 50,
            moonPhase: "New Moon",
            moonIllumination: 4,
            sunriseTime: now,
            sunsetTime: now,
            goldenHourStart: now,
            goldenHourEnd: now.addingTimeInterval(3_600),
            blueHourStart: now,
            blueHourEnd: now.addingTimeInterval(3_600)
        )
        var poorAstroWeather = excellentAstroWeather
        poorAstroWeather.cloudCover = 92
        poorAstroWeather.precipitationProbability = 85
        poorAstroWeather.moonIllumination = 95
        poorAstroWeather.visibility = 4

        let range = now...now.addingTimeInterval(7_200)
        let excellentScore = scoringService.scoreAstroWindow(
            weather: excellentAstroWeather,
            location: location,
            timeRange: range
        )
        let poorScore = scoringService.scoreAstroWindow(
            weather: poorAstroWeather,
            location: location,
            timeRange: range
        )

        try require(excellentScore > poorScore, "Astro scoring should reward clearer, darker conditions.")
        try require((0...100).contains(excellentScore), "Score should stay in 0...100.")
        try require(seed.windows.allSatisfy { (0...100).contains($0.score) }, "All mock window scores should stay in 0...100.")
    }

    @MainActor
    private static func verifyRepositories(seed: MockSeedData) async throws {
        let store = MockRepositoryStore(seedData: seed)
        let windowRepository = MockShootingWindowRepository(store: store)
        let alertRepository = MockAlertRuleRepository(store: store)

        let astroWindows = try await windowRepository.fetchWindows(for: .astro)
        try require(!astroWindows.isEmpty, "Astro repository query should return mock windows.")
        try require(astroWindows.allSatisfy { $0.category == .astro }, "Category query should only return matching windows.")

        var firstWindow = try await windowRepository.fetchWindows().first!
        let originalBookmark = firstWindow.isBookmarked
        firstWindow.isBookmarked.toggle()
        try await windowRepository.updateWindow(firstWindow)
        let updatedWindow = try await windowRepository.fetchWindow(id: firstWindow.id)
        try require(updatedWindow.isBookmarked != originalBookmark, "Window updates should persist in mock repository.")

        var firstRule = try await alertRepository.fetchAlertRules().first!
        firstRule.isEnabled.toggle()
        try await alertRepository.updateAlertRule(firstRule)
        let updatedRules = try await alertRepository.fetchAlertRules()
        try require(
            updatedRules.first(where: { $0.id == firstRule.id })?.isEnabled == firstRule.isEnabled,
            "Alert rule updates should persist in mock repository."
        )

        try await alertRepository.deleteAlertRule(id: firstRule.id)
        let remainingRules = try await alertRepository.fetchAlertRules()
        try require(!remainingRules.contains { $0.id == firstRule.id }, "Alert rule deletion should persist in mock repository.")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw VerificationError(message)
        }
    }
}

struct VerificationError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
