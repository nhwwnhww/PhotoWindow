import Foundation
import Combine

@MainActor
final class DataDebugViewModel: ObservableObject {
    @Published var selectedEnvironment: APIEnvironment
    @Published var customBaseURL: String
    @Published private(set) var dataSource: SpecialEventDataSource = .bundledJSON
    @Published private(set) var syncState: SpecialEventSyncState = .loading
    @Published private(set) var dataVersion: String?
    @Published private(set) var cacheInfo: SpecialEventCacheInfo?
    @Published private(set) var lastRemoteFetchTime: Date?
    @Published private(set) var lastSuccessfulFetchTime: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var skippedInvalidEventCount = 0
    @Published private(set) var eventCount = 0
    @Published private(set) var scoringConfigLoaded = false
    @Published private(set) var scoringConfigError: String?
    @Published private(set) var notificationQualityRules: NotificationQualityRulesSnapshot?
    @Published private(set) var skippedNotificationRecords: [SkippedNotificationRecord] = []
    @Published private(set) var onboardingPreferenceSummary = "-"
    @Published private(set) var minScoreForNotification = NotificationPreference.defaultValue.minScoreForNotification
    @Published private(set) var message: String?
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let specialEventDataService: SpecialEventDataService
    private let notificationService: any NotificationServicing
    private let userPreferenceRepository: any UserPreferenceRepository
    private let scoringRuleConfigService: ScoringRuleConfigService

    init(
        specialEventDataService: SpecialEventDataService,
        notificationService: any NotificationServicing,
        userPreferenceRepository: any UserPreferenceRepository,
        scoringRuleConfigService: ScoringRuleConfigService = ScoringRuleConfigService()
    ) {
        self.specialEventDataService = specialEventDataService
        self.notificationService = notificationService
        self.userPreferenceRepository = userPreferenceRepository
        self.scoringRuleConfigService = scoringRuleConfigService
        let config = specialEventDataService.apiConfig
        self.selectedEnvironment = config.environment
        self.customBaseURL = config.environment == .custom ? config.baseURL.absoluteString : ""
        updateDiagnostics()
    }

    var currentBaseURL: String {
        APIConfig.config(for: selectedEnvironment).baseURL.absoluteString
    }

    var activeBaseURL: String {
        specialEventDataService.apiConfig.baseURL.absoluteString
    }

    func load() {
        if let cached = specialEventDataService.cachedEvents() {
            apply(cached, message: "Loaded cached events.")
        } else {
            updateDiagnostics()
        }
        Task { await loadPreferenceDiagnostics() }
    }

    func saveAPISettings() {
        APIConfig.save(environment: selectedEnvironment, customBaseURL: customBaseURL)
        let defaultConfig = APIConfig.config(for: selectedEnvironment)
        let baseURLString = selectedEnvironment == .custom ? customBaseURL : defaultConfig.baseURL.absoluteString
        let nextConfig = APIConfig(
            environment: selectedEnvironment,
            baseURL: URL(string: baseURLString) ?? defaultConfig.baseURL,
            useRemoteSpecialEvents: true
        )
        specialEventDataService.updateAPIConfig(nextConfig)
        message = "API environment saved."
        updateDiagnostics()
    }

    func refresh() async {
        isLoading = true
        apply(await specialEventDataService.refreshEvents(), message: "Refresh finished.")
        isLoading = false
    }

    func clearCache() {
        specialEventDataService.clearCache()
        message = "Cache cleared."
        updateDiagnostics()
    }

    func reloadBundledJSON() async {
        isLoading = true
        apply(await specialEventDataService.loadBundledJSON(), message: "Loaded bundled JSON.")
        isLoading = false
    }

    private func apply(_ result: SpecialEventLoadResult, message: String?) {
        dataSource = result.dataSource
        syncState = result.status
        dataVersion = result.dataVersion
        cacheInfo = result.cacheInfo
        lastError = result.errorMessage ?? specialEventDataService.lastError
        skippedInvalidEventCount = result.skippedInvalidEventCount
        eventCount = result.events.count
        self.message = message ?? result.warningMessage
        errorMessage = result.errorMessage
        updateDiagnostics()
    }

    private func updateDiagnostics() {
        cacheInfo = specialEventDataService.cacheInfo()
        lastRemoteFetchTime = specialEventDataService.lastRemoteFetchTime
        lastSuccessfulFetchTime = specialEventDataService.lastSuccessfulFetchTime
        lastError = specialEventDataService.lastError ?? lastError
        skippedInvalidEventCount = specialEventDataService.skippedInvalidEventCount
        _ = scoringRuleConfigService.loadConfig()
        scoringConfigLoaded = scoringRuleConfigService.lastLoadSucceeded
        scoringConfigError = scoringRuleConfigService.lastLoadError
        notificationQualityRules = notificationService.notificationQualityRules()
        skippedNotificationRecords = notificationService.recentSkippedNotifications()
    }

    private func loadPreferenceDiagnostics() async {
        do {
            let preference = try await userPreferenceRepository.fetchPreference()
            let notificationPreference = preference.effectiveNotificationPreference
            onboardingPreferenceSummary = [
                "类别 \(preference.selectedCategories.count)",
                "地点 \(preference.favoriteLocationIds.count)",
                "最低评分 \(preference.defaultMinScore)",
                preference.onboardingCompletedAt == nil ? "未完成 onboarding" : "已完成 onboarding"
            ].joined(separator: " / ")
            minScoreForNotification = notificationPreference.minScoreForNotification
            notificationQualityRules = notificationService.notificationQualityRules()
        } catch {
            onboardingPreferenceSummary = "偏好读取失败：\(error.localizedDescription)"
        }
    }
}
