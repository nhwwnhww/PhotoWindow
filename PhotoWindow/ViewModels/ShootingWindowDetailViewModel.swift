import Foundation
import Combine

@MainActor
final class ShootingWindowDetailViewModel: ObservableObject {
    @Published private(set) var window: ShootingWindow?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let windowID: UUID
    private let shootingWindowRepository: any ShootingWindowRepository
    private let notificationService: any NotificationServicing

    init(
        windowID: UUID,
        shootingWindowRepository: any ShootingWindowRepository,
        notificationService: any NotificationServicing
    ) {
        self.windowID = windowID
        self.shootingWindowRepository = shootingWindowRepository
        self.notificationService = notificationService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            window = try await shootingWindowRepository.fetchWindow(id: windowID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleBookmark() async {
        guard var updated = window else { return }
        updated.isBookmarked.toggle()
        await persist(updated)
    }

    func toggleAlert() async {
        guard var updated = window else { return }

        if updated.alertEnabled {
            updated.alertEnabled = false
            notificationService.cancel(notificationId: updated.id)
        } else {
            let granted = await notificationService.requestAuthorization()
            guard granted else {
                errorMessage = "通知权限未开启，无法创建本地提醒。"
                return
            }

            updated.alertEnabled = true
            let triggerTime = updated.startTime.addingTimeInterval(-Double(60 * 60 * 3))
            let item = NotificationItem(
                id: updated.id,
                title: "拍摄窗口提醒",
                body: "\(updated.windowTitle) 将在 3 小时后开始。",
                triggerTime: triggerTime,
                relatedWindow: updated,
                isRead: false,
                createdAt: Date()
            )
            try? await notificationService.schedule(notification: item)
        }

        await persist(updated)
    }

    private func persist(_ updated: ShootingWindow) async {
        do {
            try await shootingWindowRepository.updateWindow(updated)
            window = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
