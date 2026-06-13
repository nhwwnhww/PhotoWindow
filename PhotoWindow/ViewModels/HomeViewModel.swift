import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var user: UserProfile?
    @Published private(set) var preference: UserPreference?
    @Published private(set) var savedLocations: [ShootingLocation] = []
    @Published private(set) var favoriteLocations: [ShootingLocation] = []
    @Published private(set) var windows: [ShootingWindow] = []
    @Published private(set) var upcomingSpecialEvents: [SpecialEvent] = []
    @Published private(set) var specialEventDataSource: SpecialEventDataSource = .bundledJSON
    @Published private(set) var specialEventSyncState: SpecialEventSyncState = .loading
    @Published private(set) var specialEventLastUpdated: Date?
    @Published private(set) var specialEventDataVersion: String?
    @Published private(set) var specialEventCacheInfo: SpecialEventCacheInfo?
    @Published private(set) var specialEventLastError: String?
    @Published private(set) var skippedInvalidEventCount = 0
    @Published private(set) var specialEventWarningMessage: String?
    @Published private(set) var watchlistItems: [EventWatchlistItem] = []
    @Published private(set) var upcomingNotifications: [NotificationItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var fallbackMessage: String?
    @Published var errorMessage: String?

    private let shootingWindowRepository: any ShootingWindowRepository
    private let savedLocationRepository: any SavedLocationRepository
    private let weatherRepository: any WeatherRepository
    private let astronomyRepository: any AstronomyRepository
    private let aviationEventRepository: any AviationEventRepository
    private let specialEventDataService: SpecialEventDataService
    private let alertRuleRepository: any AlertRuleRepository
    private let userPreferenceRepository: any UserPreferenceRepository
    private let notificationItemRepository: any NotificationItemRepository
    private let eventWatchlistRepository: any EventWatchlistRepository
    private let userRepository: any UserRepository
    private let notificationService: any NotificationServicing
    private let analyticsService: any AnalyticsServicing
    private let watchlistMatchingService = EventWatchlistMatchingService()
    private let specialEventIngestionService: SpecialEventIngestionService
    private let generationService = ShootingWindowGenerationService()
    private let alertMatchingService = AlertMatchingService()
    private let calendar = Calendar.current
    private var recordedHomeWindowIds: Set<UUID> = []

    init(
        shootingWindowRepository: any ShootingWindowRepository,
        savedLocationRepository: any SavedLocationRepository,
        weatherRepository: any WeatherRepository,
        astronomyRepository: any AstronomyRepository,
        aviationEventRepository: any AviationEventRepository,
        specialEventRepository: any SpecialEventRepository,
        specialEventDataService: SpecialEventDataService,
        alertRuleRepository: any AlertRuleRepository,
        userPreferenceRepository: any UserPreferenceRepository,
        notificationItemRepository: any NotificationItemRepository,
        eventWatchlistRepository: any EventWatchlistRepository,
        userRepository: any UserRepository,
        notificationService: any NotificationServicing,
        analyticsService: any AnalyticsServicing
    ) {
        self.shootingWindowRepository = shootingWindowRepository
        self.savedLocationRepository = savedLocationRepository
        self.weatherRepository = weatherRepository
        self.astronomyRepository = astronomyRepository
        self.aviationEventRepository = aviationEventRepository
        self.specialEventDataService = specialEventDataService
        self.alertRuleRepository = alertRuleRepository
        self.userPreferenceRepository = userPreferenceRepository
        self.notificationItemRepository = notificationItemRepository
        self.eventWatchlistRepository = eventWatchlistRepository
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.analyticsService = analyticsService
        self.specialEventIngestionService = SpecialEventIngestionService(repository: specialEventRepository)
    }

    var todayRecommendations: [ShootingWindow] {
        windows
            .filter { Calendar.current.isDateInToday($0.startTime) || $0.startTime > Date() }
            .sorted { personalizedPriority(for: $0) > personalizedPriority(for: $1) }
    }

    var hasSavedLocations: Bool {
        !savedLocations.isEmpty
    }

    var favoriteTopWindows: [ShootingWindow] {
        let favoriteIds = Set(favoriteLocations.map(\.id))
        return Array(
            windows
                .filter { favoriteIds.contains($0.location.id) || $0.location.isFavorite }
                .sorted { personalizedPriority(for: $0) > personalizedPriority(for: $1) }
                .prefix(3)
        )
    }

    var topWindows: [ShootingWindow] {
        Array(windows.sorted { personalizedPriority(for: $0) > personalizedPriority(for: $1) }.prefix(3))
    }

    var dailySummaryText: String {
        guard preference?.dailySummaryEnabled != false else {
            return "每日摘要已关闭，可在偏好里重新开启。"
        }

        let minScore = preference?.defaultMinScore ?? 70
        let todayWindows = windows
            .filter { calendar.isDateInToday($0.startTime) && $0.score >= minScore }
            .sorted { personalizedPriority(for: $0) > personalizedPriority(for: $1) }

        if let best = todayWindows.first {
            return "今天有 \(todayWindows.count) 个值得拍摄的窗口\n最佳机会：\(best.location.name) \(best.startTime.formatted(date: .omitted, time: .shortened)) \(best.windowTitle)，评分 \(best.score)"
        }

        return "今天暂无特别推荐，建议关注未来几天窗口。"
    }

    var specialEvents: [ShootingWindow] {
        windowsWithEvents.sorted { lhs, rhs in
            let lhsPriority = specialEventPriority(for: lhs)
            let rhsPriority = specialEventPriority(for: rhs)
            if lhsPriority == rhsPriority {
                return lhs.score > rhs.score
            }
            return lhsPriority > rhsPriority
        }
    }

    var priorityUpcomingSpecialEvents: [SpecialEvent] {
        Array(
            upcomingSpecialEvents
                .sorted { priority(for: $0) > priority(for: $1) }
                .prefix(5)
        )
    }

    var specialEventDataSourceText: String {
        var text = "事件数据来自：\(specialEventDataSource.displayName)"

        if let specialEventDataVersion {
            text += " · 版本 \(specialEventDataVersion)"
        }

        if let specialEventLastUpdated {
            text += " · 更新于 \(specialEventLastUpdated.formatted(date: .abbreviated, time: .shortened))"
        }

        return text
    }

    var specialEventDebugText: String {
        [
            specialEventDataSourceText,
            "同步状态：\(specialEventSyncState.displayName)",
            skippedInvalidEventCount > 0 ? "已跳过 \(skippedInvalidEventCount) 条无效事件" : nil
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    func load() async {
        isLoading = true

        do {
            try await loadPrimaryData()

            if let cachedResult = specialEventDataService.cachedEvents() {
                applySpecialEventResult(cachedResult)
                try await rebuildGeneratedContent()
                isLoading = false
                await refreshSpecialEventsInBackground()
            } else {
                let result = await specialEventDataService.refreshEvents()
                applySpecialEventResult(result)
                try await rebuildGeneratedContent()
                isLoading = false
            }
        } catch {
            isLoading = false
            await loadFallbackWindows(error: error)
        }
    }

    func refresh() async {
        isLoading = true
        await refreshSpecialEventsInBackground()
        isLoading = false
    }

    func recordHomeWindowViewed(_ window: ShootingWindow) {
        guard recordedHomeWindowIds.insert(window.id).inserted else { return }
        Task {
            await analyticsService.record(.homeWindowViewed, window: window)
        }
    }

    func recordNotificationClicked(_ notification: NotificationItem) {
        Task {
            if let window = notification.relatedWindow {
                await analyticsService.record(.notificationClicked, window: window)
            } else {
                await analyticsService.record(.notificationClicked)
            }
        }
    }

    func watchlistHitText(for event: SpecialEvent) -> String? {
        let hits = watchlistItems
            .filter { $0.isEnabled && $0.category == event.category && event.matches(keyword: $0.keyword) }
            .map(\.displayName)
            .removingDuplicates()

        guard !hits.isEmpty else { return nil }
        return "命中关注：\(hits.joined(separator: "、"))"
    }

    private func generateShootingWindows() async throws -> [ShootingWindow] {
        let locations = savedLocations.isEmpty
            ? try await savedLocationRepository.fetchSavedLocations()
            : savedLocations
        let specialEvents = upcomingSpecialEvents
        let allLocations = specialEventIngestionService.eventLocations(
            from: specialEvents,
            knownLocations: locations
        )
        let existingWindows = try await shootingWindowRepository.fetchWindows()
        let existingEvents = uniqueEvents(from: existingWindows.flatMap(\.eventRefs))
        var generatedWindows: [ShootingWindow] = []

        for location in allLocations {
            let weatherSnapshots = try await weatherRepository.fetchWeather(for: location)
            let astronomySnapshots = try await fetchAstronomySnapshots(for: location, weatherSnapshots: weatherSnapshots)

            for category in categories(for: location, specialEvents: specialEvents) {
                let categoryEvents = try await events(
                    for: category,
                    location: location,
                    existingEvents: existingEvents
                )
                let locationSpecialEvents = specialEventIngestionService.specialEvents(
                    from: specialEvents,
                    for: location,
                    category: category
                )
                generatedWindows.append(
                    contentsOf: generationService.generateWindows(
                        location: location,
                        weatherSnapshots: weatherSnapshots,
                        astronomySnapshots: astronomySnapshots,
                        category: category,
                        events: categoryEvents,
                        specialEvents: locationSpecialEvents
                    )
                )
            }
        }

        guard !generatedWindows.isEmpty else {
            throw RepositoryError.notFound
        }

        return generatedWindows.sorted {
            if $0.score == $1.score {
                return $0.startTime < $1.startTime
            }
            return $0.score > $1.score
        }
    }

    private func fetchAstronomySnapshots(
        for location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot]
    ) async throws -> [AstronomySnapshot] {
        let dates = uniqueDates(from: weatherSnapshots.map(\.sunriseTime))
        var snapshots: [AstronomySnapshot] = []

        for date in dates {
            snapshots.append(try await astronomyRepository.fetchAstronomy(for: location, date: date))
        }

        return snapshots.sorted { $0.date < $1.date }
    }

    private func events(
        for category: PhotographyCategory,
        location: ShootingLocation,
        existingEvents: [ShootingEvent]
    ) async throws -> [ShootingEvent] {
        let localEvents = existingEvents.filter {
            $0.category == category && $0.location.id == location.id
        }

        guard category == .aviation else {
            return localEvents
        }

        let aviationEvents = try await aviationEventRepository.fetchAviationEvents(for: location)
        return uniqueEvents(from: localEvents + aviationEvents)
    }

    private func loadFallbackWindows(error: Error) async {
        do {
            windows = try await shootingWindowRepository.fetchWindows()
            if watchlistItems.isEmpty {
                watchlistItems = try await eventWatchlistRepository.fetchWatchlistItems()
            }
            if upcomingSpecialEvents.isEmpty {
                applySpecialEventResult(await specialEventDataService.eventsForDisplay())
            }
            if preference == nil {
                preference = try? await userPreferenceRepository.fetchPreference()
            }
            if savedLocations.isEmpty {
                savedLocations = (try? await savedLocationRepository.fetchSavedLocations()) ?? []
                favoriteLocations = (try? await savedLocationRepository.fetchFavoriteLocations()) ?? []
            }
            try? await refreshAutomaticNotifications(for: windows)
            fallbackMessage = "天气/天文数据加载失败，已显示本地 mock 推荐。"
            errorMessage = "数据源错误：\(error.localizedDescription)"
            lastUpdated = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPrimaryData() async throws {
        user = try await userRepository.fetchCurrentUser()
        preference = try await userPreferenceRepository.fetchPreference()
        savedLocations = try await savedLocationRepository.fetchSavedLocations()
        favoriteLocations = try await savedLocationRepository.fetchFavoriteLocations()
        watchlistItems = try await eventWatchlistRepository.fetchWatchlistItems()
    }

    private func rebuildGeneratedContent() async throws {
        if savedLocations.isEmpty {
            windows = []
            upcomingNotifications = []
            notificationService.cancelAll()
            try await notificationItemRepository.deleteAllNotifications()
        } else {
            windows = try await generateShootingWindows()
            try await shootingWindowRepository.replaceWindows(windows)
            try await refreshAutomaticNotifications(for: windows)
        }

        lastUpdated = Date()
        fallbackMessage = nil
        errorMessage = nil
    }

    private func refreshSpecialEventsInBackground() async {
        let result = await specialEventDataService.refreshEvents()
        applySpecialEventResult(result)

        do {
            try await rebuildGeneratedContent()
        } catch {
            errorMessage = "数据源错误：\(error.localizedDescription)"
        }
    }

    private func applySpecialEventResult(_ result: SpecialEventLoadResult) {
        upcomingSpecialEvents = result.events
        specialEventDataSource = result.dataSource
        specialEventSyncState = result.status
        specialEventLastUpdated = result.lastUpdated
        specialEventDataVersion = result.dataVersion
        specialEventCacheInfo = result.cacheInfo
        specialEventLastError = result.errorMessage
        skippedInvalidEventCount = result.skippedInvalidEventCount
        specialEventWarningMessage = result.warningMessage
    }

    private var windowsWithEvents: [ShootingWindow] {
        windows.filter { !$0.eventRefs.isEmpty }
    }

    private func specialEventPriority(for window: ShootingWindow) -> Int {
        watchlistMatchingService.priorityBoost(for: window, watchlist: watchlistItems) +
            (window.primaryEvent.map { Int($0.importanceLevel.scoreWeight) } ?? 0) +
            window.score
    }

    private func personalizedPriority(for window: ShootingWindow) -> Int {
        var priority = window.score

        if let preference {
            if preference.selectedCategories.contains(window.category) {
                priority += 18
            }
            if preference.favoriteLocationIds.contains(window.location.id) {
                priority += 14
            }
        }

        if window.location.isFavorite || favoriteLocations.contains(where: { $0.id == window.location.id }) {
            priority += 20
        }

        if !window.eventRefs.isEmpty {
            priority += specialEventPriority(for: window) / 10
        }

        return priority
    }

    private func priority(for event: SpecialEvent) -> Int {
        var priority = Int(event.importanceLevel.scoreWeight) * 4
        priority += event.confidenceLevel.rank * 12

        if watchlistItems.contains(where: { item in
            item.isEnabled && item.category == event.category && event.matches(keyword: item.keyword)
        }) {
            priority += 60
        }

        if event.importanceLevel == .mustShoot || event.importanceLevel == .rare {
            priority += 40
        }

        let hoursAway = max(0, event.startTime.timeIntervalSince(Date()) / 3_600)
        priority += max(0, 72 - Int(hoursAway))
        return priority
    }

    private func refreshAutomaticNotifications(for windows: [ShootingWindow]) async throws {
        let rules = try await alertRuleRepository.fetchAlertRules()
        let matchedNotifications = alertMatchingService.match(
            windows: windows,
            alertRules: rules,
            watchlist: watchlistItems
        )
        upcomingNotifications = Array(matchedNotifications.prefix(5))
        try await notificationItemRepository.replaceNotifications(matchedNotifications)

        guard !matchedNotifications.isEmpty else {
            notificationService.cancelAll()
            return
        }

        let granted = await notificationService.requestAuthorization()
        guard granted else { return }

        notificationService.cancelAll()
        try await notificationService.schedule(notifications: matchedNotifications)
    }

    private func uniqueEvents(from events: [ShootingEvent]) -> [ShootingEvent] {
        var seen = Set<UUID>()
        return events.filter { seen.insert($0.id).inserted }
    }

    private func categories(for location: ShootingLocation, specialEvents: [SpecialEvent]) -> [PhotographyCategory] {
        let eventCategories = specialEvents
            .filter { $0.locationId == location.id || $0.locationName == location.name }
            .map(\.category)
        return uniqueCategories(generationService.categories(for: location) + eventCategories)
    }

    private func uniqueCategories(_ categories: [PhotographyCategory]) -> [PhotographyCategory] {
        var seen = Set<PhotographyCategory>()
        return categories.filter { seen.insert($0).inserted }
    }

    private func uniqueDates(from dates: [Date]) -> [Date] {
        var seen = Set<Date>()
        return dates
            .map { calendar.startOfDay(for: $0) }
            .filter { seen.insert($0).inserted }
            .sorted()
    }
}

private extension SpecialEvent {
    func matches(keyword: String) -> Bool {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKeyword.isEmpty else { return false }

        let searchableText = ([title, description] + tags)
            .joined(separator: " ")
            .lowercased()
        return searchableText.contains(normalizedKeyword)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
