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

                if viewModel.alertRules.isEmpty && !viewModel.isLoading {
                    Text("还没有订阅提醒。")
                        .foregroundStyle(Color.photoMutedText)
                        .photoCardStyle()
                } else {
                    ForEach(viewModel.alertRules) { rule in
                        alertRuleCard(rule)
                    }
                }
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
                "提前 \(rule.remindBeforeMinutes) 分钟提醒",
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
}
