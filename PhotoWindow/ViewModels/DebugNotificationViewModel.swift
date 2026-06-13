import Foundation
import Combine

@MainActor
final class DebugNotificationViewModel: ObservableObject {
    @Published private(set) var pendingNotifications: [PendingNotification] = []
    @Published private(set) var skippedNotifications: [SkippedNotificationRecord] = []
    @Published private(set) var qualityRules: NotificationQualityRulesSnapshot?
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?

    private let notificationService: any NotificationServicing

    init(notificationService: any NotificationServicing) {
        self.notificationService = notificationService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        pendingNotifications = await notificationService.pendingNotifications()
        skippedNotifications = notificationService.recentSkippedNotifications()
        qualityRules = notificationService.notificationQualityRules()
    }

    func scheduleTest(after seconds: TimeInterval) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await notificationService.scheduleTestNotification(after: seconds)
            pendingNotifications = await notificationService.pendingNotifications()
            skippedNotifications = notificationService.recentSkippedNotifications()
            qualityRules = notificationService.notificationQualityRules()
            statusMessage = seconds < 60 ? "已创建 5 秒后测试提醒。" : "已创建 1 分钟后测试提醒。"
        } catch {
            statusMessage = "测试提醒创建失败：\(error.localizedDescription)"
        }
    }

    func clearAll() async {
        notificationService.cancelAll()
        pendingNotifications = await notificationService.pendingNotifications()
        skippedNotifications = notificationService.recentSkippedNotifications()
        qualityRules = notificationService.notificationQualityRules()
        statusMessage = "已清除全部提醒。"
    }
}
