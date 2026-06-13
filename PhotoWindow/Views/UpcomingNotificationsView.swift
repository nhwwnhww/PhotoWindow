import SwiftUI

struct UpcomingNotificationsView: View {
    @StateObject private var viewModel: UpcomingNotificationsViewModel

    init(viewModel: UpcomingNotificationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("即将提醒")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    Spacer()

                    if !viewModel.notifications.isEmpty {
                        Button {
                            Task { await viewModel.cancelAll() }
                        } label: {
                            Image(systemName: "bell.slash")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.photoAccent)
                        .accessibilityLabel("取消全部提醒")
                    }
                }

                if viewModel.notifications.isEmpty && !viewModel.isLoading {
                    Text("暂时没有即将触发的提醒。保存偏好或开启提醒后，这里会显示匹配到的拍摄窗口。")
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                        .photoCardStyle()
                } else {
                    ForEach(viewModel.notifications) { notification in
                        notificationCard(notification)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("即将提醒")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .padding(10)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding()
            }
        }
    }

    private func notificationCard(_ notification: NotificationItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let window = notification.relatedWindow {
                NavigationLink {
                    ShootingWindowDetailScreen(windowID: window.id)
                } label: {
                    cardContent(notification, window: window)
                }
                .buttonStyle(.plain)
            } else {
                cardContent(notification, window: nil)
            }

            Button(role: .destructive) {
                Task { await viewModel.cancel(notification: notification) }
            } label: {
                Label("取消这个提醒", systemImage: "bell.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .photoCardStyle()
    }

    private func cardContent(_ notification: NotificationItem, window: ShootingWindow?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(notification.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(window?.location.name ?? "未关联地点")
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                }

                Spacer()

                if let window {
                    ScoreBadge(score: window.score, level: window.scoreLevel)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            if let window {
                Label(
                    "拍摄 \(window.startTime.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "camera"
                )
                .font(.caption)
                .foregroundStyle(Color.photoMutedText)
            }

            Label(
                "提醒 \(notification.triggerTime.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "bell"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.photoAccent)

            Text(notification.body)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
