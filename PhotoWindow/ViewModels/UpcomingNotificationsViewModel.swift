import Foundation
import Combine

@MainActor
final class UpcomingNotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let notificationItemRepository: any NotificationItemRepository
    private let shootingWindowRepository: any ShootingWindowRepository
    private let alertRuleRepository: any AlertRuleRepository
    private let notificationService: any NotificationServicing
    private let alertMatchingService = AlertMatchingService()

    init(
        notificationItemRepository: any NotificationItemRepository,
        shootingWindowRepository: any ShootingWindowRepository,
        alertRuleRepository: any AlertRuleRepository,
        notificationService: any NotificationServicing
    ) {
        self.notificationItemRepository = notificationItemRepository
        self.shootingWindowRepository = shootingWindowRepository
        self.alertRuleRepository = alertRuleRepository
        self.notificationService = notificationService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            var fetched = try await notificationItemRepository.fetchNotifications()
            if fetched.isEmpty {
                let windows = try await shootingWindowRepository.fetchWindows()
                let rules = try await alertRuleRepository.fetchAlertRules()
                fetched = alertMatchingService.match(windows: windows, alertRules: rules)
                try await notificationItemRepository.replaceNotifications(fetched)
            }

            notifications = fetched.sorted { $0.triggerTime < $1.triggerTime }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel(notification: NotificationItem) async {
        do {
            notificationService.cancel(notificationId: notification.id)
            try await notificationItemRepository.deleteNotification(id: notification.id)
            notifications.removeAll { $0.id == notification.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelAll() async {
        do {
            notificationService.cancelAll()
            try await notificationItemRepository.deleteAllNotifications()
            notifications = []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
