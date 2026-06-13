import SwiftUI

struct DebugNotificationView: View {
    @StateObject private var viewModel: DebugNotificationViewModel

    init(viewModel: DebugNotificationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                qualityRulesSection
                actions
                pendingList
                skippedList
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("通知测试")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提醒可靠性测试")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.photoAccent)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.scheduleTest(after: 5) }
            } label: {
                Label("5 秒后测试提醒", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)

            Button {
                Task { await viewModel.scheduleTest(after: 60) }
            } label: {
                Label("1 分钟后测试提醒", systemImage: "clock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)

            Button(role: .destructive) {
                Task { await viewModel.clearAll() }
            } label: {
                Label("清除全部提醒", systemImage: "bell.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .disabled(viewModel.isLoading)
    }

    @ViewBuilder
    private var qualityRulesSection: some View {
        if let rules = viewModel.qualityRules {
            VStack(alignment: .leading, spacing: 10) {
                Text("质量控制规则")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                detailRow("每日最大提醒", "\(rules.dailyMaxNotifications)")
                detailRow("勿扰时段", rules.quietHoursDescription)
                detailRow("最低提醒评分", "\(rules.minScoreForNotification)")
                detailRow("必拍覆盖勿扰", rules.allowMustShootOverride ? "开启" : "关闭")
                detailRow("同地点同类别合并", rules.mergeNearbyNotifications ? "开启" : "关闭")
            }
            .photoCardStyle()
        }
    }

    private var pendingList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前待触发提醒")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoAccent)
                .accessibilityLabel("刷新待触发提醒")
            }

            if viewModel.pendingNotifications.isEmpty {
                Text("没有待触发提醒。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                    .photoCardStyle()
            } else {
                ForEach(viewModel.pendingNotifications) { notification in
                    pendingNotificationRow(notification)
                }
            }
        }
    }

    private var skippedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近被跳过的提醒")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if viewModel.skippedNotifications.isEmpty {
                Text("暂无被质量规则跳过的提醒。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                    .photoCardStyle()
            } else {
                ForEach(viewModel.skippedNotifications.prefix(8)) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.windowTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(record.reason)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.84))
                        Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.photoMutedText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .photoCardStyle()
                }
            }
        }
    }

    private func pendingNotificationRow(_ notification: PendingNotification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notification.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(notification.body)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.84))
            Text(notification.triggerDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.photoAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .photoCardStyle()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.photoMutedText)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
