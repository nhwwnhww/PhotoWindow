import Foundation
import Combine

struct ReminderPresetOption: Identifiable, Hashable {
    let minutes: Int
    let title: String

    var id: Int { minutes }

    static let standardOptions: [ReminderPresetOption] = [
        ReminderPresetOption(minutes: 30, title: "提前 30 分钟"),
        ReminderPresetOption(minutes: 60, title: "提前 1 小时"),
        ReminderPresetOption(minutes: 180, title: "提前 3 小时"),
        ReminderPresetOption(minutes: 1_440, title: "提前 1 天"),
        ReminderPresetOption(minutes: 1_500, title: "提前 1 天 + 1 小时")
    ]
}

@MainActor
final class ShootingWindowDetailViewModel: ObservableObject {
    @Published private(set) var window: ShootingWindow?
    @Published private(set) var alternativeWindow: ShootingWindow?
    @Published private(set) var matchedWatchlistKeywords: [String] = []
    @Published private(set) var reminderMergeSummary = "提醒合并：将单独提醒"
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmittingFeedback = false
    @Published private(set) var feedbackSubmitted = false
    @Published var selectedReminderMinutes = 180
    @Published var usesCustomReminder = false
    @Published var selectedFeedbackRating: FeedbackRating?
    @Published var feedbackComment = ""
    @Published var errorMessage: String?

    let reminderPresetOptions = ReminderPresetOption.standardOptions

    private let windowID: UUID
    private let shootingWindowRepository: any ShootingWindowRepository
    private let alertRuleRepository: any AlertRuleRepository
    private let feedbackRepository: any FeedbackRepository
    private let eventWatchlistRepository: any EventWatchlistRepository
    private let userRepository: any UserRepository
    private let notificationService: any NotificationServicing
    private let analyticsService: any AnalyticsServicing
    private let watchlistMatchingService = EventWatchlistMatchingService()
    private let reminderMergeService = ReminderMergeService()
    private var allWindows: [ShootingWindow] = []

    init(
        windowID: UUID,
        shootingWindowRepository: any ShootingWindowRepository,
        alertRuleRepository: any AlertRuleRepository,
        feedbackRepository: any FeedbackRepository,
        eventWatchlistRepository: any EventWatchlistRepository,
        userRepository: any UserRepository,
        notificationService: any NotificationServicing,
        analyticsService: any AnalyticsServicing
    ) {
        self.windowID = windowID
        self.shootingWindowRepository = shootingWindowRepository
        self.alertRuleRepository = alertRuleRepository
        self.feedbackRepository = feedbackRepository
        self.eventWatchlistRepository = eventWatchlistRepository
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.analyticsService = analyticsService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedWindow = try await shootingWindowRepository.fetchWindow(id: windowID)
            window = fetchedWindow
            allWindows = try await shootingWindowRepository.fetchWindows()
            alternativeWindow = findAlternative(for: fetchedWindow, in: allWindows)
            let watchlistItems = try await eventWatchlistRepository.fetchWatchlistItems()
            matchedWatchlistKeywords = watchlistMatchingService
                .matchedItems(for: fetchedWindow.eventRefs, watchlist: watchlistItems)
                .map { $0.item.displayName }
                .removingDuplicates()
            await loadReminderPreference(for: fetchedWindow)
            await loadExistingFeedback(for: fetchedWindow)
            refreshReminderMergeSummary()
            await analyticsService.record(.windowDetailOpened, window: fetchedWindow)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectReminderPreset(_ option: ReminderPresetOption) {
        selectedReminderMinutes = option.minutes
        usesCustomReminder = false
        refreshReminderMergeSummary()
    }

    func setCustomReminderMinutes(_ minutes: Int) {
        selectedReminderMinutes = min(max(minutes, 5), 4_320)
        usesCustomReminder = true
        refreshReminderMergeSummary()
    }

    func toggleBookmark() async {
        guard var updated = window else { return }
        updated.isBookmarked.toggle()
        let didBookmark = updated.isBookmarked
        let didPersist = await persist(updated)
        if didPersist && didBookmark {
            await analyticsService.record(.windowBookmarked, window: updated)
        }
    }

    func toggleAlert() async {
        guard var updated = window else { return }
        var permissionWarning: String?
        let analyticsName: AnalyticsEventName

        if updated.alertEnabled {
            updated.alertEnabled = false
            notificationService.cancel(notificationId: updated.id)
            analyticsName = .alertDisabled
        } else {
            let granted = await notificationService.requestAuthorization()
            updated.alertEnabled = true
            analyticsName = .alertEnabled
            if granted {
                let triggerTime = updated.startTime.addingTimeInterval(-Double(60 * selectedReminderMinutes))
                let item = NotificationItem(
                    id: updated.id,
                    title: notificationTitle(for: updated),
                    body: notificationBody(for: updated),
                    triggerTime: triggerTime,
                    relatedWindow: updated,
                    isRead: false,
                    createdAt: Date()
                )
                try? await notificationService.schedule(notification: item)
            } else {
                permissionWarning = "系统通知权限未开启，已先保存 mock 提醒订阅。"
            }
        }

        await syncAlertRule(for: updated)
        let didPersist = await persist(updated)
        if didPersist {
            await analyticsService.record(analyticsName, window: updated)
        }
        if let permissionWarning {
            errorMessage = permissionWarning
        }
    }

    func selectFeedbackRating(_ rating: FeedbackRating) {
        selectedFeedbackRating = rating
    }

    func submitFeedback() async {
        guard let window, let selectedFeedbackRating else { return }

        isSubmittingFeedback = true
        defer { isSubmittingFeedback = false }

        do {
            let user = try await userRepository.fetchCurrentUser()
            let trimmedComment = feedbackComment.trimmingCharacters(in: .whitespacesAndNewlines)
            let feedback = Feedback(
                id: UUID(),
                windowId: window.id,
                userId: user.id,
                rating: selectedFeedbackRating,
                comment: trimmedComment.isEmpty ? nil : trimmedComment,
                createdAt: Date()
            )
            try await feedbackRepository.submitFeedback(feedback)
            feedbackSubmitted = true
            await analyticsService.record(.feedbackSubmitted, window: window)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func formatReminderLead(minutes: Int) -> String {
        if minutes == 1_500 {
            return "1 天 + 1 小时"
        }

        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440) 天"
        }

        if minutes % 60 == 0 {
            return "\(minutes / 60) 小时"
        }

        return "\(minutes) 分钟"
    }

    private func loadReminderPreference(for window: ShootingWindow) async {
        let rules = (try? await alertRuleRepository.fetchAlertRules()) ?? []
        if let rule = matchingRule(for: window, in: rules) {
            selectedReminderMinutes = rule.remindBeforeMinutes
        } else {
            selectedReminderMinutes = window.defaultReminderLeadMinutes
        }
        usesCustomReminder = !reminderPresetOptions.contains { $0.minutes == selectedReminderMinutes }
    }

    private func loadExistingFeedback(for window: ShootingWindow) async {
        guard let user = try? await userRepository.fetchCurrentUser(),
              let feedbackItems = try? await feedbackRepository.fetchFeedback(),
              let existingFeedback = feedbackItems.first(where: { $0.windowId == window.id && $0.userId == user.id }) else {
            selectedFeedbackRating = nil
            feedbackComment = ""
            feedbackSubmitted = false
            return
        }

        selectedFeedbackRating = existingFeedback.rating
        feedbackComment = existingFeedback.comment ?? ""
        feedbackSubmitted = true
    }

    private func refreshReminderMergeSummary() {
        guard let window else {
            reminderMergeSummary = "提醒合并：将单独提醒"
            return
        }

        let nearbyCount = reminderMergeService.nearbyMergeCount(
            for: window,
            in: allWindows,
            remindBeforeMinutes: selectedReminderMinutes
        )

        if nearbyCount > 0 {
            reminderMergeSummary = "提醒合并：会与 \(nearbyCount) 个相近窗口合并进摘要提醒"
        } else {
            reminderMergeSummary = "提醒合并：将单独提醒"
        }
    }

    private func syncAlertRule(for window: ShootingWindow) async {
        do {
            let rules = try await alertRuleRepository.fetchAlertRules()
            let eventType = window.eventRefs.first?.eventType

            if var rule = matchingRule(for: window, in: rules) {
                rule.isEnabled = window.alertEnabled
                rule.minScore = min(rule.minScore, window.score)
                rule.remindBeforeMinutes = selectedReminderMinutes
                try await alertRuleRepository.upsertAlertRule(rule)
                return
            }

            let user = try await userRepository.fetchCurrentUser()
            let rule = AlertRule(
                id: window.id,
                userId: user.id,
                category: window.category,
                location: window.location,
                eventType: eventType,
                minScore: min(75, window.score),
                remindBeforeMinutes: selectedReminderMinutes,
                isEnabled: window.alertEnabled,
                keywords: [window.category.displayName, window.location.name]
            )
            try await alertRuleRepository.upsertAlertRule(rule)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func notificationTitle(for window: ShootingWindow) -> String {
        guard let event = window.primaryEvent else {
            return "拍摄窗口提醒"
        }

        if event.importanceLevel == .mustShoot {
            return "必拍事件：\(event.title)"
        }

        if event.importanceLevel == .rare {
            return "稀有事件：\(event.title)"
        }

        return "特殊事件：\(event.title)"
    }

    private func notificationBody(for window: ShootingWindow) -> String {
        guard let event = window.primaryEvent else {
            return "\(window.windowTitle) 将在 \(Self.formatReminderLead(minutes: selectedReminderMinutes)) 后开始。"
        }

        let weather = window.weatherSnapshot
        let time = "\(window.startTime.formatted(date: .omitted, time: .shortened))-\(window.endTime.formatted(date: .omitted, time: .shortened))"
        return "\(time)，云量 \(Int(weather.cloudCover))%，降雨 \(Int(weather.precipitationProbability))%，能见度 \(Int(weather.visibility)) km，\(event.title)。建议提前 \(Self.formatReminderLead(minutes: selectedReminderMinutes)) 到场。"
    }

    private func matchingRule(for window: ShootingWindow, in rules: [AlertRule]) -> AlertRule? {
        let eventType = window.eventRefs.first?.eventType
        return rules.first { rule in
            rule.category == window.category &&
            rule.locationId == window.location.id &&
            (rule.eventType == eventType || eventType == nil)
        }
    }

    private func findAlternative(
        for window: ShootingWindow,
        in windows: [ShootingWindow]
    ) -> ShootingWindow? {
        guard window.score < 70 else { return nil }

        return windows
            .filter {
                $0.id != window.id &&
                $0.category == window.category &&
                $0.score >= 70 &&
                $0.startTime > window.startTime
            }
            .sorted {
                if $0.startTime == $1.startTime {
                    return $0.score > $1.score
                }
                return $0.startTime < $1.startTime
            }
            .first
    }

    private func persist(_ updated: ShootingWindow) async -> Bool {
        do {
            try await shootingWindowRepository.updateWindow(updated)
            window = updated
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
