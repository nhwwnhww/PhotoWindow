import SwiftUI

struct AlertSettingsView: View {
    @StateObject private var viewModel: AlertSettingsViewModel

    init(viewModel: AlertSettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("提醒规则")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                reminderMergeStatus
                debugNotificationLink

                if viewModel.alertRules.isEmpty && !viewModel.isLoading {
                    Text("还没有订阅提醒。")
                        .foregroundStyle(Color.photoMutedText)
                        .photoCardStyle()
                } else {
                    ForEach(viewModel.alertRules) { rule in
                        alertRuleCard(rule)
                    }
                }

                watchlistSection
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("提醒")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
    }

    private func alertRuleCard(_ rule: AlertRule) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(rule.category.displayName, systemImage: rule.category.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)
                    Text(rule.location.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let eventType = rule.eventType {
                        Text(eventType.displayName)
                            .font(.subheadline)
                            .foregroundStyle(Color.photoMutedText)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { isEnabled in
                        Task { await viewModel.setEnabled(isEnabled, for: rule) }
                    }
                ))
                .labelsHidden()
                .tint(Color.photoAccent)
            }

            Stepper(
                "最低评分 \(rule.minScore)",
                value: Binding(
                    get: { rule.minScore },
                    set: { value in
                        Task { await viewModel.setMinScore(value, for: rule) }
                    }
                ),
                in: 0...100,
                step: 5
            )
            .foregroundStyle(.white)

            Stepper(
                "提前 \(ShootingWindowDetailViewModel.formatReminderLead(minutes: rule.remindBeforeMinutes)) 提醒",
                value: Binding(
                    get: { rule.remindBeforeMinutes },
                    set: { value in
                        Task { await viewModel.setRemindBeforeMinutes(value, for: rule) }
                    }
                ),
                in: 5...4320,
                step: 15
            )
            .foregroundStyle(.white)

            if !rule.keywords.isEmpty {
                Text(rule.keywords.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
            }

            Button(role: .destructive) {
                Task { await viewModel.delete(rule: rule) }
            } label: {
                Label("删除提醒", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .photoCardStyle()
    }

    private var reminderMergeStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.shouldMergeNearbyReminders ? "rectangle.3.group.bubble" : "bell")
                .font(.title3)
                .foregroundStyle(Color.photoAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("提醒合并")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.shouldMergeNearbyReminders ? "已开启：同日 2 小时内的提醒会合并为摘要。" : "未开启：每个窗口会单独提醒。")
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
            }

            Spacer()
        }
        .photoCardStyle()
    }

    private var debugNotificationLink: some View {
        NavigationLink {
            DebugNotificationScreen()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(Color.photoAccent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("通知测试")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("5 秒、1 分钟测试提醒和待触发列表")
                        .font(.caption)
                        .foregroundStyle(Color.photoMutedText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoMutedText)
            }
            .photoCardStyle()
        }
        .buttonStyle(.plain)
    }

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("事件关注关键词")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if viewModel.watchlistItems.isEmpty && !viewModel.isLoading {
                Text("还没有关注关键词。")
                    .foregroundStyle(Color.photoMutedText)
                    .photoCardStyle()
            } else {
                ForEach(viewModel.watchlistItems) { item in
                    watchlistItemCard(item)
                }
            }
        }
    }

    private func watchlistItemCard(_ item: EventWatchlistItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.category.iconName)
                .font(.headline)
                .foregroundStyle(Color.photoAccent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(item.category.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { isEnabled in
                    Task { await viewModel.setWatchlistEnabled(isEnabled, for: item) }
                }
            ))
            .labelsHidden()
            .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }
}
