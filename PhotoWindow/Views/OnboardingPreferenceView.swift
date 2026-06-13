import SwiftUI

struct OnboardingPreferenceView: View {
    @StateObject private var viewModel: OnboardingPreferenceViewModel

    init(viewModel: OnboardingPreferenceViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                stepIndicator
                stepContent
                navigationControls
                debugSection

                if let savedMessage = viewModel.savedMessage {
                    Text(savedMessage)
                        .font(.caption)
                        .foregroundStyle(Color.photoAccent)
                        .photoCardStyle()
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("偏好")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("个性化订阅")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("用 5 步完成内测前的推荐和提醒偏好，也可以跳过任一步。")
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
        }
    }

    private var stepIndicator: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Step \(viewModel.currentStep.stepNumber)/\(OnboardingPreferenceStep.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
                Spacer()
                Text(viewModel.currentStep.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoMutedText)
            }

            GeometryReader { proxy in
                let progress = CGFloat(viewModel.currentStep.stepNumber) / CGFloat(OnboardingPreferenceStep.allCases.count)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.photoAccent)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .categories:
            categorySection
        case .locations:
            locationSection
        case .threshold:
            thresholdSection
        case .notifications:
            notificationPreferenceSection
        case .authorization:
            permissionSection
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关注类别")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(PhotographyCategory.mvpCases) { category in
                    selectableRow(
                        title: category.displayName,
                        iconName: category.iconName,
                        isSelected: viewModel.selectedCategories.contains(category)
                    ) {
                        viewModel.toggleCategory(category)
                    }
                }
            }
        }
        .photoCardStyle()
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用地点")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(viewModel.locations) { location in
                selectableRow(
                    title: location.name,
                    iconName: "mappin.and.ellipse",
                    isSelected: viewModel.favoriteLocationIds.contains(location.id)
                ) {
                    viewModel.toggleLocation(location)
                }
            }
        }
        .photoCardStyle()
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("默认提醒规则")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Stepper(
                "最低评分 \(viewModel.defaultMinScore)",
                value: $viewModel.defaultMinScore,
                in: 0...100,
                step: 5
            )
            .foregroundStyle(.white)

            Stepper(
                "提前 \(ShootingWindowDetailViewModel.formatReminderLead(minutes: viewModel.defaultReminderMinutes)) 提醒",
                value: $viewModel.defaultReminderMinutes,
                in: 5...4_320,
                step: 15
            )
            .foregroundStyle(.white)

            Toggle("每日摄影机会摘要", isOn: $viewModel.dailySummaryEnabled)
                .foregroundStyle(.white)
                .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }

    private var notificationPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("提醒质量控制")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Stepper(
                "每日最多 \(viewModel.dailyMaxNotifications) 条提醒",
                value: $viewModel.dailyMaxNotifications,
                in: 1...12,
                step: 1
            )
            .foregroundStyle(.white)

            Stepper(
                "勿扰开始 \(String(format: "%02d:00", viewModel.quietHoursStart))",
                value: $viewModel.quietHoursStart,
                in: 0...23,
                step: 1
            )
            .foregroundStyle(.white)

            Stepper(
                "勿扰结束 \(String(format: "%02d:00", viewModel.quietHoursEnd))",
                value: $viewModel.quietHoursEnd,
                in: 0...23,
                step: 1
            )
            .foregroundStyle(.white)

            Toggle("必拍事件允许覆盖勿扰", isOn: $viewModel.allowMustShootOverride)
                .foregroundStyle(.white)
                .tint(Color.photoAccent)

            Toggle("合并同地点同类别提醒", isOn: $viewModel.mergeNearbyNotifications)
                .foregroundStyle(.white)
                .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("通知权限")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("开启后，系统才可以按评分和事件重要度推送本地提醒。")
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)

            if let granted = viewModel.notificationPermissionGranted {
                Label(granted ? "通知权限已开启" : "通知权限未开启", systemImage: granted ? "bell.badge.fill" : "bell.slash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(granted ? Color.photoAccent : Color.photoMutedText)
            }

            Button {
                Task { await viewModel.requestNotificationPermission() }
            } label: {
                Label("请求通知权限", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }

    private var navigationControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Label("上一步", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoAccent)
                .disabled(viewModel.currentStep == .categories)

                Button {
                    viewModel.skipStep()
                } label: {
                    Text("跳过")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoMutedText)
            }

            Button {
                if viewModel.currentStep == .authorization {
                    Task { await viewModel.save() }
                } else {
                    viewModel.nextStep()
                }
            } label: {
                Label(
                    viewModel.currentStep == .authorization ? "保存偏好并生成提醒规则" : "下一步",
                    systemImage: viewModel.currentStep == .authorization ? "checkmark.circle" : "chevron.right"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)
        }
    }

    private var debugSection: some View {
        NavigationLink {
            DataDebugScreen()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .foregroundStyle(Color.photoAccent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("数据调试")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("查看 API 环境、缓存和特殊事件同步状态。")
                        .font(.caption)
                        .foregroundStyle(Color.photoMutedText)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.photoMutedText)
            }
            .photoCardStyle()
        }
        .buttonStyle(.plain)
    }

    private func selectableRow(
        title: String,
        iconName: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(isSelected ? Color.photoAccent : Color.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background((isSelected ? Color.photoAccent : Color.white).opacity(isSelected ? 0.14 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
