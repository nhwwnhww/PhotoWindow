import Foundation
import Combine

enum OnboardingPreferenceStep: Int, CaseIterable, Identifiable {
    case categories
    case locations
    case threshold
    case notifications
    case authorization

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .categories:
            return "摄影类别"
        case .locations:
            return "常用地点"
        case .threshold:
            return "推荐阈值"
        case .notifications:
            return "提醒偏好"
        case .authorization:
            return "通知权限"
        }
    }

    var stepNumber: Int {
        rawValue + 1
    }
}

@MainActor
final class OnboardingPreferenceViewModel: ObservableObject {
    @Published private(set) var locations: [ShootingLocation] = []
    @Published private(set) var isLoading = false
    @Published var currentStep: OnboardingPreferenceStep = .categories
    @Published var selectedCategories: Set<PhotographyCategory> = []
    @Published var favoriteLocationIds: Set<UUID> = []
    @Published var defaultMinScore = 75
    @Published var defaultReminderMinutes = 180
    @Published var dailySummaryEnabled = true
    @Published var dailyMaxNotifications = NotificationPreference.defaultValue.dailyMaxNotifications
    @Published var quietHoursStart = NotificationPreference.defaultValue.quietHoursStart
    @Published var quietHoursEnd = NotificationPreference.defaultValue.quietHoursEnd
    @Published var allowMustShootOverride = NotificationPreference.defaultValue.allowMustShootOverride
    @Published var mergeNearbyNotifications = NotificationPreference.defaultValue.mergeNearbyNotifications
    @Published private(set) var notificationPermissionGranted: Bool?
    @Published var savedMessage: String?
    @Published var errorMessage: String?

    private let userPreferenceRepository: any UserPreferenceRepository
    private let shootingWindowRepository: any ShootingWindowRepository
    private let alertRuleRepository: any AlertRuleRepository
    private let userRepository: any UserRepository
    private let notificationService: any NotificationServicing
    private var preferenceId = UUID()

    init(
        userPreferenceRepository: any UserPreferenceRepository,
        shootingWindowRepository: any ShootingWindowRepository,
        alertRuleRepository: any AlertRuleRepository,
        userRepository: any UserRepository,
        notificationService: any NotificationServicing
    ) {
        self.userPreferenceRepository = userPreferenceRepository
        self.shootingWindowRepository = shootingWindowRepository
        self.alertRuleRepository = alertRuleRepository
        self.userRepository = userRepository
        self.notificationService = notificationService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            locations = try await shootingWindowRepository.fetchLocations()
            let preference = try await userPreferenceRepository.fetchPreference()
            preferenceId = preference.id
            selectedCategories = Set(preference.selectedCategories)
            favoriteLocationIds = Set(preference.favoriteLocationIds)
            defaultMinScore = preference.defaultMinScore
            defaultReminderMinutes = preference.defaultReminderMinutes
            dailySummaryEnabled = preference.dailySummaryEnabled
            let notificationPreference = preference.effectiveNotificationPreference
            dailyMaxNotifications = notificationPreference.dailyMaxNotifications
            quietHoursStart = notificationPreference.quietHoursStart
            quietHoursEnd = notificationPreference.quietHoursEnd
            allowMustShootOverride = notificationPreference.allowMustShootOverride
            mergeNearbyNotifications = notificationPreference.mergeNearbyNotifications
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCategory(_ category: PhotographyCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func toggleLocation(_ location: ShootingLocation) {
        if favoriteLocationIds.contains(location.id) {
            favoriteLocationIds.remove(location.id)
        } else {
            favoriteLocationIds.insert(location.id)
        }
    }

    func nextStep() {
        let steps = OnboardingPreferenceStep.allCases
        guard let index = steps.firstIndex(of: currentStep), index < steps.count - 1 else { return }
        currentStep = steps[index + 1]
    }

    func previousStep() {
        let steps = OnboardingPreferenceStep.allCases
        guard let index = steps.firstIndex(of: currentStep), index > 0 else { return }
        currentStep = steps[index - 1]
    }

    func skipStep() {
        if currentStep == .authorization {
            Task { await save() }
        } else {
            nextStep()
        }
    }

    func requestNotificationPermission() async {
        let granted = await notificationService.requestAuthorization()
        notificationPermissionGranted = granted
        savedMessage = granted ? "通知权限已开启。" : "未开启通知权限，仍可保存偏好。"
    }

    func save() async {
        do {
            let notificationPreference = NotificationPreference(
                quietHoursStart: min(max(quietHoursStart, 0), 23),
                quietHoursEnd: min(max(quietHoursEnd, 0), 23),
                dailyMaxNotifications: max(dailyMaxNotifications, 1),
                minScoreForNotification: min(max(defaultMinScore, 0), 100),
                allowMustShootOverride: allowMustShootOverride,
                mergeNearbyNotifications: mergeNearbyNotifications
            )
            let preference = UserPreference(
                id: preferenceId,
                selectedCategories: sortedCategories(Array(selectedCategories)),
                favoriteLocationIds: locations.map(\.id).filter { favoriteLocationIds.contains($0) },
                defaultMinScore: min(max(defaultMinScore, 0), 100),
                defaultReminderMinutes: max(defaultReminderMinutes, 5),
                dailySummaryEnabled: dailySummaryEnabled,
                notificationPreference: notificationPreference,
                onboardingCompletedAt: Date()
            )

            try await userPreferenceRepository.savePreference(preference)
            try await syncAlertRules(preference: preference)
            savedMessage = "偏好已保存，系统会按这些规则自动匹配提醒。"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncAlertRules(preference: UserPreference) async throws {
        let user = try await userRepository.fetchCurrentUser()
        let existingRules = try await alertRuleRepository.fetchAlertRules()

        for category in preference.selectedCategories {
            for locationId in preference.favoriteLocationIds {
                guard let location = locations.first(where: { $0.id == locationId }) else { continue }
                let existingRule = existingRules.first {
                    $0.category == category &&
                    $0.locationId == locationId &&
                    $0.eventType == nil &&
                    $0.keywords.isEmpty
                }
                let rule = AlertRule(
                    id: existingRule?.id ?? UUID(),
                    userId: user.id,
                    category: category,
                    location: location,
                    eventType: nil,
                    minScore: preference.defaultMinScore,
                    remindBeforeMinutes: preference.defaultReminderMinutes,
                    isEnabled: true,
                    keywords: [],
                    createdAt: existingRule?.createdAt ?? Date()
                )
                try await alertRuleRepository.upsertAlertRule(rule)
            }
        }
    }

    private func sortedCategories(_ categories: [PhotographyCategory]) -> [PhotographyCategory] {
        PhotographyCategory.mvpCases.filter { categories.contains($0) }
    }
}
