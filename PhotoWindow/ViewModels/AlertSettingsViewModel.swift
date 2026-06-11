import Foundation
import Combine

@MainActor
final class AlertSettingsViewModel: ObservableObject {
    @Published private(set) var alertRules: [AlertRule] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let alertRuleRepository: any AlertRuleRepository

    init(alertRuleRepository: any AlertRuleRepository) {
        self.alertRuleRepository = alertRuleRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            alertRules = try await alertRuleRepository.fetchAlertRules()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ isEnabled: Bool, for rule: AlertRule) async {
        var updated = rule
        updated.isEnabled = isEnabled
        await update(updated)
    }

    func setMinScore(_ minScore: Int, for rule: AlertRule) async {
        var updated = rule
        updated.minScore = min(max(minScore, 0), 100)
        await update(updated)
    }

    func setRemindBeforeMinutes(_ minutes: Int, for rule: AlertRule) async {
        var updated = rule
        updated.remindBeforeMinutes = max(minutes, 5)
        await update(updated)
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

    private func update(_ rule: AlertRule) async {
        do {
            try await alertRuleRepository.updateAlertRule(rule)
            if let index = alertRules.firstIndex(where: { $0.id == rule.id }) {
                alertRules[index] = rule
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
