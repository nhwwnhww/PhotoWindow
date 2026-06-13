import XCTest
@testable import PhotoWindow

@MainActor
final class MockRepositoryTests: XCTestCase {
    func testFetchWindowsByCategoryFiltersResults() async throws {
        let store = MockRepositoryStore()
        let repository = MockShootingWindowRepository(store: store)

        let astroWindows = try await repository.fetchWindows(for: .astro)

        XCTAssertFalse(astroWindows.isEmpty)
        XCTAssertTrue(astroWindows.allSatisfy { $0.category == .astro })
    }

    func testUpdateWindowPersistsBookmarkChange() async throws {
        let store = MockRepositoryStore()
        let repository = MockShootingWindowRepository(store: store)
        var window = try await repository.fetchWindows().first!
        let originalValue = window.isBookmarked

        window.isBookmarked.toggle()
        try await repository.updateWindow(window)
        let updated = try await repository.fetchWindow(id: window.id)

        XCTAssertNotEqual(originalValue, updated.isBookmarked)
    }

    func testAlertRuleToggleAndDeletePersist() async throws {
        let store = MockRepositoryStore()
        let repository = MockAlertRuleRepository(store: store)
        var rule = try await repository.fetchAlertRules().first!

        rule.isEnabled.toggle()
        try await repository.updateAlertRule(rule)
        let updatedRules = try await repository.fetchAlertRules()

        XCTAssertEqual(updatedRules.first(where: { $0.id == rule.id })?.isEnabled, rule.isEnabled)

        try await repository.deleteAlertRule(id: rule.id)
        let remainingRules = try await repository.fetchAlertRules()

        XCTAssertFalse(remainingRules.contains { $0.id == rule.id })
    }

    func testAlertRuleUpsertCreatesRuleForWindowReminder() async throws {
        let store = MockRepositoryStore()
        let ruleRepository = MockAlertRuleRepository(store: store)
        let windowRepository = MockShootingWindowRepository(store: store)
        let user = store.user
        let window = try await windowRepository.fetchWindows(for: .landscape).first!
        let rule = AlertRule(
            id: window.id,
            userId: user.id,
            category: window.category,
            location: window.location,
            eventType: window.eventRefs.first?.eventType,
            minScore: 75,
            remindBeforeMinutes: 180,
            isEnabled: true,
            keywords: [window.category.displayName]
        )

        try await ruleRepository.upsertAlertRule(rule)
        let rules = try await ruleRepository.fetchAlertRules()

        XCTAssertEqual(rules.first(where: { $0.id == window.id })?.isEnabled, true)
    }

    func testWatchlistTogglePersists() async throws {
        let store = MockRepositoryStore()
        let repository = MockEventWatchlistRepository(store: store)
        var item = try await repository.fetchWatchlistItems().first!

        item.isEnabled.toggle()
        try await repository.updateWatchlistItem(item)
        let updatedItems = try await repository.fetchWatchlistItems()

        XCTAssertEqual(updatedItems.first(where: { $0.id == item.id })?.isEnabled, item.isEnabled)
    }

    func testUserPreferenceUpdatesPersist() async throws {
        let store = MockRepositoryStore()
        let repository = MockUserPreferenceRepository(store: store)

        try await repository.updateSelectedCategories([.aviation, .landscape])
        try await repository.updateFavoriteLocations([store.locations[0].id])
        let preference = try await repository.fetchPreference()

        XCTAssertEqual(preference.selectedCategories, [.aviation, .landscape])
        XCTAssertEqual(preference.favoriteLocationIds, [store.locations[0].id])
    }

    func testAlertMatchingServiceCreatesDedupedNotifications() async throws {
        let store = MockRepositoryStore()
        let window = store.windows.first { $0.category == .aviation && !$0.eventRefs.isEmpty }!
        let duplicateRule = AlertRule(
            id: UUID(),
            userId: store.user.id,
            category: window.category,
            location: window.location,
            eventType: nil,
            minScore: 10,
            remindBeforeMinutes: 60,
            isEnabled: true,
            keywords: []
        )
        let keywordRule = AlertRule(
            id: UUID(),
            userId: store.user.id,
            category: window.category,
            location: window.location,
            eventType: nil,
            minScore: 10,
            remindBeforeMinutes: 45,
            isEnabled: true,
            keywords: ["Qantas"]
        )

        let notifications = AlertMatchingService().match(
            windows: [window],
            alertRules: [duplicateRule, keywordRule],
            now: Date().addingTimeInterval(-86_400)
        )

        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications[0].relatedWindow?.id, window.id)
    }

    func testNotificationRepositoryPersistsUpcomingItems() async throws {
        let store = MockRepositoryStore()
        let repository = MockNotificationItemRepository(store: store)
        let window = store.windows.first!
        let notification = NotificationItem(
            id: window.id,
            title: "Test",
            body: "Body",
            triggerTime: Date().addingTimeInterval(3_600),
            relatedWindow: window,
            isRead: false,
            createdAt: Date()
        )

        try await repository.replaceNotifications([notification])
        var fetched = try await repository.fetchNotifications()
        XCTAssertEqual(fetched.count, 1)

        try await repository.deleteNotification(id: notification.id)
        fetched = try await repository.fetchNotifications()
        XCTAssertTrue(fetched.isEmpty)
    }

    func testFeedbackRepositoryPersistsRating() async throws {
        let store = MockRepositoryStore()
        let suiteName = "PhotoWindowTests.feedback.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let repository = UserDefaultsFeedbackRepository(userDefaults: userDefaults, key: "feedback")
        let window = store.windows.first!
        let feedback = Feedback(
            id: UUID(),
            windowId: window.id,
            userId: store.user.id,
            rating: .notUseful,
            comment: "Clouds arrived earlier than expected.",
            createdAt: Date()
        )

        try await repository.submitFeedback(feedback)
        let fetched = try await repository.fetchFeedback()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.rating, .notUseful)
        XCTAssertEqual(fetched.first?.windowId, window.id)
    }

    func testSavedLocationRepositoryPersistsCustomLocationAndFavorite() async throws {
        let store = MockRepositoryStore()
        let suiteName = "PhotoWindowTests.locations.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let repository = UserDefaultsSavedLocationRepository(
            seedLocations: store.locations,
            userDefaults: userDefaults,
            key: "locations"
        )
        let location = ShootingLocation(
            id: UUID(),
            name: "Custom Ridge",
            latitude: -27.4,
            longitude: 153.0,
            city: "Brisbane",
            country: "Australia",
            lightPollutionLevel: 4,
            locationType: .custom,
            notes: "Manual test location",
            supportedCategories: [.landscape, .portrait]
        )

        try await repository.saveLocation(location)
        var saved = try await repository.fetchSavedLocations()
        XCTAssertTrue(saved.contains { $0.id == location.id })

        try await repository.toggleFavorite(locationId: location.id)
        saved = try await repository.fetchSavedLocations()
        XCTAssertEqual(saved.first(where: { $0.id == location.id })?.isFavorite, true)

        try await repository.deleteLocation(id: location.id)
        saved = try await repository.fetchSavedLocations()
        XCTAssertFalse(saved.contains { $0.id == location.id })
    }

    func testAnalyticsServicePersistsLocalEvents() async throws {
        let store = MockRepositoryStore()
        let suiteName = "PhotoWindowTests.analytics.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let service = AnalyticsService(userDefaults: userDefaults, key: "analytics")
        let window = store.windows.first!

        await service.record(.windowDetailOpened, window: window)
        let events = await service.fetchEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, .windowDetailOpened)
        XCTAssertEqual(events.first?.windowId, window.id)
        XCTAssertEqual(events.first?.score, window.score)
    }

    func testReminderMergeServiceCombinesNearbyNotifications() async throws {
        let store = MockRepositoryStore()
        let windows = Array(store.windows.prefix(3))
        let service = ReminderMergeService()
        let baseTime = Date().addingTimeInterval(3_600)
        let notifications = windows.enumerated().map { index, window in
            NotificationItem(
                id: UUID(),
                title: "提醒 \(index)",
                body: window.windowTitle,
                triggerTime: baseTime.addingTimeInterval(Double(index) * 1_800),
                relatedWindow: window,
                isRead: false,
                createdAt: Date()
            )
        }

        let merged = service.merge(notifications: notifications)

        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].title.contains("3 个"))
        XCTAssertTrue(merged[0].title.contains("机会"))
    }

    func testMockWeatherRepositoryReturnsForecastSnapshots() async throws {
        let store = MockRepositoryStore()
        let repository = MockWeatherRepository(store: store)
        let location = store.locations.first { $0.locationType == .darkSky }!

        let snapshots = try await repository.fetchWeather(for: location)

        XCTAssertEqual(snapshots.count, 7)
        XCTAssertTrue(snapshots.allSatisfy { (0...100).contains($0.cloudCover) })
    }

    func testMockAstronomyRepositoryReturnsDailySnapshot() async throws {
        let store = MockRepositoryStore()
        let repository = MockAstronomyRepository()
        let location = store.locations.first { $0.locationType == .darkSky }!

        let snapshot = try await repository.fetchAstronomy(for: location, date: Date())

        XCTAssertLessThan(snapshot.sunriseTime, snapshot.sunsetTime)
        XCTAssertLessThan(snapshot.goldenHourStart, snapshot.goldenHourEnd)
        XCTAssertLessThanOrEqual(snapshot.moonIllumination, 100)
    }

    func testShootingWindowGenerationUsesWeatherAndAstronomy() async throws {
        let store = MockRepositoryStore()
        let location = store.locations.first { $0.locationType == .darkSky }!
        let weatherRepository = MockWeatherRepository(store: store)
        let astronomyRepository = MockAstronomyRepository()
        let weather = try await weatherRepository.fetchWeather(for: location)
        let astronomy = try await weather.asyncMap {
            try await astronomyRepository.fetchAstronomy(for: location, date: $0.sunriseTime)
        }
        let service = ShootingWindowGenerationService()

        let windows = service.generateWindows(
            location: location,
            weatherSnapshots: weather,
            astronomySnapshots: astronomy,
            category: .astro,
            events: store.events
        )

        XCTAssertFalse(windows.isEmpty)
        XCTAssertTrue(windows.allSatisfy { $0.category == .astro })
        XCTAssertTrue(windows.allSatisfy { !$0.reasonTags.isEmpty })
        XCTAssertTrue(windows.allSatisfy { !$0.scoreBreakdown.isEmpty })
    }

    func testGenerationServiceUsesLocationTypeDefaultCategories() {
        let campus = ShootingLocation(
            id: UUID(),
            name: "Campus",
            latitude: -27.0,
            longitude: 153.0,
            city: "Brisbane",
            country: "Australia",
            lightPollutionLevel: 6,
            locationType: .campus,
            notes: ""
        )
        let wildlifeArea = ShootingLocation(
            id: UUID(),
            name: "Wetlands",
            latitude: -27.1,
            longitude: 153.1,
            city: "Brisbane",
            country: "Australia",
            lightPollutionLevel: 4,
            locationType: .wildlifeArea,
            notes: ""
        )
        let service = ShootingWindowGenerationService()

        XCTAssertEqual(Set(service.categories(for: campus)), Set([.graduation, .portrait]))
        XCTAssertEqual(service.categories(for: wildlifeArea), [.wildlife])
    }

    func testLocalJSONSpecialEventRepositoryReadsSeedEvents() async throws {
        let repository = LocalJSONSpecialEventRepository(fallbackURL: specialEventsSeedURL())

        let events = try await repository.fetchSpecialEvents()
        let aviationEvents = try await repository.fetchSpecialEvents(for: .aviation)

        XCTAssertGreaterThanOrEqual(events.count, 8)
        XCTAssertTrue(events.contains { $0.title.contains("A380") })
        XCTAssertTrue(events.contains { $0.eventType == .meteorShower && $0.importanceLevel == .mustShoot })
        XCTAssertTrue(events.allSatisfy(\.isFuture))
        XCTAssertTrue(aviationEvents.allSatisfy { $0.category == .aviation })
    }

    func testSpecialEventIngestionConvertsEventsToShootingEvents() async throws {
        let store = MockRepositoryStore()
        let repository = LocalJSONSpecialEventRepository(fallbackURL: specialEventsSeedURL())
        let service = SpecialEventIngestionService(repository: repository)
        let events = try await service.fetchSpecialEvents()
        let location = store.locations.first { $0.name == "Brisbane Airport" }!

        let shootingEvents = service.shootingEvents(
            from: events,
            knownLocations: store.locations,
            location: location,
            category: .aviation
        )

        XCTAssertFalse(shootingEvents.isEmpty)
        XCTAssertTrue(shootingEvents.allSatisfy { $0.location.id == location.id })
        XCTAssertTrue(shootingEvents.contains { $0.tags.contains("A380") || $0.tags.contains("特殊涂装") })
    }

    func testSpecialEventDeduplicationKeepsStrongerEvent() {
        let locationId = UUID()
        let now = Date().addingTimeInterval(3_600)
        let weaker = SpecialEvent(
            id: UUID(),
            title: "Lake Moogerah Meteor Shower",
            category: .astro,
            eventType: .meteorShower,
            locationId: locationId,
            locationName: "Lake Moogerah",
            latitude: -28.0295,
            longitude: 152.5436,
            startTime: now,
            endTime: now.addingTimeInterval(7_200),
            importanceLevel: .worthWatching,
            confidenceLevel: .low,
            description: "Older duplicate",
            tags: ["Meteor Shower"],
            sourceType: .mock,
            sourceName: "Test",
            sourceURL: nil,
            lastUpdated: now,
            createdAt: now
        )
        var stronger = weaker
        stronger.importanceLevel = .mustShoot
        stronger.confidenceLevel = .high
        stronger.lastUpdated = now.addingTimeInterval(600)

        let deduped = SpecialEventDeduplicationService().deduplicated([weaker, stronger])

        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped[0].importanceLevel, .mustShoot)
        XCTAssertEqual(deduped[0].confidenceLevel, .high)
    }

    private func specialEventsSeedURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PhotoWindow")
            .appendingPathComponent("Resources")
            .appendingPathComponent("special_events_seed.json")
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            values.append(try await transform(element))
        }
        return values
    }
}
