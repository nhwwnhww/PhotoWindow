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
        try require(seed.locations.count >= 4, "Expected MVP locations including South Bank.")
        try require(seed.windows.count >= 4, "Expected mock windows across MVP scenarios.")
        try require(seed.events.contains { $0.eventType == .specialAircraft }, "Expected a mock aviation event.")
        try require(seed.events.contains { $0.importanceLevel == .rare }, "Expected at least one rare event.")
        try require(seed.events.contains { $0.importanceLevel == .mustShoot }, "Expected at least one must-shoot event.")
        try require(seed.windows.contains { $0.category == .astro }, "Expected an astro window.")
        try require(seed.windows.contains { $0.category == .aviation }, "Expected an aviation window.")
        try require(seed.windows.contains { $0.category == .graduation }, "Expected a graduation window.")
        try require(!seed.userPreference.selectedCategories.isEmpty, "Expected default selected categories.")
        try require(!seed.userPreference.favoriteLocationIds.isEmpty, "Expected default favorite locations.")
        try require((0...100).contains(seed.userPreference.defaultMinScore), "Default min score should stay in 0...100.")
        try require(seed.watchlistItems.contains { $0.keyword == "A380" }, "Expected A380 watchlist item.")
        try require(seed.watchlistItems.contains { $0.keyword == "Meteor Shower" }, "Expected meteor shower watchlist item.")
        try require(seed.windows.allSatisfy { !$0.reasonTags.isEmpty }, "Every mock window should explain its score with reason tags.")
        try require(seed.windows.allSatisfy { !$0.scoreBreakdown.isEmpty }, "Every mock window should include a score breakdown.")
        try require(
            seed.windows.allSatisfy { window in
                window.scoreBreakdown.reduce(0) { $0 + $1.score } == window.score
            },
            "Score breakdown items should add up to the window score."
        )
        try require(
            seed.windows.contains { $0.score < 70 && $0.notRecommendedReason != nil },
            "Expected at least one low-score window with a not-recommended reason."
        )
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
        let weatherRepository = MockWeatherRepository(store: store)
        let astronomyRepository = MockAstronomyRepository()
        let alertRepository = MockAlertRuleRepository(store: store)
        let watchlistRepository = MockEventWatchlistRepository(store: store)
        let userPreferenceRepository = MockUserPreferenceRepository(store: store)
        let notificationRepository = MockNotificationItemRepository(store: store)
        let specialEventRepository = LocalJSONSpecialEventRepository()
        let suiteName = "PhotoWindow.VerifyCore.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let feedbackRepository = UserDefaultsFeedbackRepository(
            userDefaults: userDefaults,
            key: "feedback"
        )
        let savedLocationRepository = UserDefaultsSavedLocationRepository(
            seedLocations: seed.locations,
            userDefaults: userDefaults,
            key: "locations"
        )
        let analyticsService = AnalyticsService(
            userDefaults: userDefaults,
            key: "analytics"
        )

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

        var firstWatchlistItem = try await watchlistRepository.fetchWatchlistItems().first!
        firstWatchlistItem.isEnabled.toggle()
        try await watchlistRepository.updateWatchlistItem(firstWatchlistItem)
        let updatedWatchlist = try await watchlistRepository.fetchWatchlistItems()
        try require(
            updatedWatchlist.first(where: { $0.id == firstWatchlistItem.id })?.isEnabled == firstWatchlistItem.isEnabled,
            "Watchlist item updates should persist in mock repository."
        )

        try await userPreferenceRepository.updateSelectedCategories([.aviation, .landscape])
        let updatedPreference = try await userPreferenceRepository.fetchPreference()
        try require(
            updatedPreference.selectedCategories == [.aviation, .landscape],
            "User preference category updates should persist."
        )

        let mergeService = ReminderMergeService()
        let windows = Array(try await windowRepository.fetchWindows().prefix(2))
        let baseTriggerTime = Calendar.current.date(
            byAdding: .hour,
            value: 10,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
        let notifications = windows.enumerated().map { index, window in
            NotificationItem(
                id: UUID(),
                title: "Test",
                body: window.windowTitle,
                triggerTime: baseTriggerTime.addingTimeInterval(Double(index) * 1_800),
                relatedWindow: window,
                isRead: false,
                createdAt: Date()
            )
        }
        try require(
            mergeService.merge(notifications: notifications).count == 1,
            "Nearby reminders should merge into one summary notification."
        )

        let matchingService = AlertMatchingService()
        let generatedNotifications = matchingService.match(
            windows: try await windowRepository.fetchWindows(),
            alertRules: try await alertRepository.fetchAlertRules(),
            now: Date().addingTimeInterval(-86_400)
        )
        try require(!generatedNotifications.isEmpty, "Alert rules should match at least one notification.")
        let uniqueWindowIds = Set(generatedNotifications.compactMap { $0.relatedWindow?.id })
        try require(
            uniqueWindowIds.count == generatedNotifications.count,
            "Alert matching should avoid duplicate notifications for one window."
        )

        try await notificationRepository.replaceNotifications(generatedNotifications)
        let persistedNotifications = try await notificationRepository.fetchNotifications()
        try require(
            persistedNotifications.count == generatedNotifications.count,
            "Notification repository should persist upcoming notifications."
        )

        let feedback = Feedback(
            id: UUID(),
            windowId: updatedWindow.id,
            userId: store.user.id,
            rating: .useful,
            comment: "Trusted the window timing.",
            createdAt: Date()
        )
        try await feedbackRepository.submitFeedback(feedback)
        let persistedFeedback = try await feedbackRepository.fetchFeedback()
        try require(
            persistedFeedback.first?.rating == .useful,
            "Feedback repository should persist a useful rating."
        )

        await analyticsService.record(.feedbackSubmitted, window: updatedWindow)
        let analyticsEvents = await analyticsService.fetchEvents()
        try require(
            analyticsEvents.contains { $0.name == .feedbackSubmitted && $0.windowId == updatedWindow.id },
            "Analytics service should persist feedback_submitted events locally."
        )

        let savedLocations = try await savedLocationRepository.fetchSavedLocations()
        try require(savedLocations.count == seed.locations.count, "Saved location repository should seed mock locations.")
        try await savedLocationRepository.toggleFavorite(locationId: savedLocations[0].id)
        let toggledLocation = try await savedLocationRepository.fetchSavedLocations()
            .first { $0.id == savedLocations[0].id }
        try require(
            toggledLocation?.isFavorite != savedLocations[0].isFavorite,
            "Saved location favorite toggles should persist."
        )

        let darkSkyLocation = seed.locations.first { $0.locationType == .darkSky }!
        let weatherSnapshots = try await weatherRepository.fetchWeather(for: darkSkyLocation)
        try require(weatherSnapshots.count == 7, "Weather repository should return a 7-day local forecast array.")

        let astronomySnapshot = try await astronomyRepository.fetchAstronomy(
            for: darkSkyLocation,
            date: weatherSnapshots[0].sunriseTime
        )
        try require(
            astronomySnapshot.sunriseTime < astronomySnapshot.sunsetTime,
            "Astronomy repository should return valid sunrise and sunset times."
        )

        let specialEvents = try await specialEventRepository.fetchSpecialEvents()
        try require(specialEvents.count >= 8, "Local JSON special event repository should load at least 8 seed events.")
        try require(
            specialEvents.contains { $0.title.contains("A380") },
            "Special event seed should include Brisbane Airport A380 arrival."
        )
        try require(
            specialEvents.contains { $0.eventType == .meteorShower && $0.importanceLevel == .mustShoot },
            "Special event seed should include a must-shoot meteor shower window."
        )

        let specialEventIngestion = SpecialEventIngestionService(repository: specialEventRepository)
        let specialEventLocations = specialEventIngestion.eventLocations(
            from: specialEvents,
            knownLocations: seed.locations
        )
        try require(
            specialEventLocations.contains { $0.name == "Kangaroo Point Cliffs" },
            "Ingestion should surface event-derived locations."
        )

        let airportLocation = seed.locations.first { $0.locationType == .airport }!
        let airportShootingEvents = specialEventIngestion.shootingEvents(
            from: specialEvents,
            knownLocations: seed.locations,
            location: airportLocation,
            category: .aviation
        )
        try require(
            airportShootingEvents.contains { $0.tags.contains("A380") || $0.tags.contains("特殊涂装") },
            "Ingestion should convert aviation special events into ShootingEvent values."
        )

        let generatedWindows = ShootingWindowGenerationService().generateWindows(
            location: darkSkyLocation,
            weatherSnapshots: weatherSnapshots,
            astronomySnapshots: [astronomySnapshot],
            category: .astro,
            events: seed.events
        )
        try require(!generatedWindows.isEmpty, "Generation service should create astro windows from weather and astronomy.")
        try require(
            generatedWindows.allSatisfy { !$0.reasonTags.isEmpty },
            "Generated windows should include reason tags."
        )

        let meteorEvent = specialEvents.first { $0.eventType == .meteorShower }!
        let meteorLocation = meteorEvent.resolvedLocation(knownLocations: seed.locations)
        let meteorWeather = try await weatherRepository.fetchWeather(for: meteorLocation)
        let meteorAstronomy = try await astronomyRepository.fetchAstronomy(
            for: meteorLocation,
            date: meteorEvent.startTime
        )
        let specialEventWindows = ShootingWindowGenerationService().generateWindows(
            location: meteorLocation,
            weatherSnapshots: meteorWeather,
            astronomySnapshots: [meteorAstronomy],
            category: meteorEvent.category,
            specialEvents: [meteorEvent]
        )
        try require(
            specialEventWindows.contains { $0.eventRefs.contains { $0.id == meteorEvent.id } },
            "Generation service should create special-event-driven ShootingWindow values."
        )
        try require(
            specialEventWindows.contains { $0.reasonTags.contains(meteorEvent.eventReasonTag) },
            "Special-event-driven windows should include event reason tags."
        )

        let campusLocation = seed.locations.first { $0.locationType == .campus }!
        let campusCategories = ShootingWindowGenerationService().categories(for: campusLocation)
        try require(
            campusCategories.contains(.graduation) && campusCategories.contains(.portrait),
            "Campus locations should default to graduation and portrait windows."
        )
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
