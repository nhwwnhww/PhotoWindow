import Foundation
import Combine

@MainActor
final class AlertSettingsViewModel: ObservableObject {
    @Published private(set) var alertRules: [AlertRule] = []
    @Published private(set) var watchlistItems: [EventWatchlistItem] = []
    @Published private(set) var shouldMergeNearbyReminders = true
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let alertRuleRepository: any AlertRuleRepository
    private let eventWatchlistRepository: any EventWatchlistRepository
    private let userRepository: any UserRepository
    private let analyticsService: any AnalyticsServicing

    init(
        alertRuleRepository: any AlertRuleRepository,
        eventWatchlistRepository: any EventWatchlistRepository,
        userRepository: any UserRepository,
        analyticsService: any AnalyticsServicing
    ) {
        self.alertRuleRepository = alertRuleRepository
        self.eventWatchlistRepository = eventWatchlistRepository
        self.userRepository = userRepository
        self.analyticsService = analyticsService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            alertRules = try await alertRuleRepository.fetchAlertRules()
            watchlistItems = try await eventWatchlistRepository.fetchWatchlistItems()
            shouldMergeNearbyReminders = try await userRepository.fetchCurrentUser()
                .notificationPreference
                .shouldMergeNearbyReminders
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ isEnabled: Bool, for rule: AlertRule) async {
        var updated = rule
        updated.isEnabled = isEnabled
        if await update(updated) {
            await analyticsService.record(isEnabled ? .alertEnabled : .alertDisabled, rule: updated)
        }
    }

    func setMinScore(_ minScore: Int, for rule: AlertRule) async {
        var updated = rule
        updated.minScore = min(max(minScore, 0), 100)
        _ = await update(updated)
    }

    func setRemindBeforeMinutes(_ minutes: Int, for rule: AlertRule) async {
        var updated = rule
        updated.remindBeforeMinutes = max(minutes, 5)
        _ = await update(updated)
    }

    func delete(rule: AlertRule) async {
        do {
            try await alertRuleRepository.deleteAlertRule(id: rule.id)
            alertRules.removeAll { $0.id == rule.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setWatchlistEnabled(_ isEnabled: Bool, for item: EventWatchlistItem) async {
        var updated = item
        updated.isEnabled = isEnabled

        do {
            try await eventWatchlistRepository.updateWatchlistItem(updated)
            if let index = watchlistItems.firstIndex(where: { $0.id == item.id }) {
                watchlistItems[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(_ rule: AlertRule) async -> Bool {
        do {
            try await alertRuleRepository.updateAlertRule(rule)
            if let index = alertRules.firstIndex(where: { $0.id == rule.id }) {
                alertRules[index] = rule
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
