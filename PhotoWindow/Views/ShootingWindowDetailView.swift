import SwiftUI

struct ShootingWindowDetailView: View {
    @StateObject private var viewModel: ShootingWindowDetailViewModel

    init(viewModel: ShootingWindowDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            if let window = viewModel.window {
                VStack(alignment: .leading, spacing: 22) {
                    header(window)
                    actionButtons(window)
                    reminderPresetSection(window)
                    eventReminderSection(window)
                    recommendation(window)
                    feedbackSection
                    scoreBreakdownSection(window)
                    notRecommendedSection(window)
                    checklistSection(window.category)
                    weatherSection(window.weatherSnapshot)
                    relatedEvents(window.eventRefs)
                }
                .padding(20)
            } else if viewModel.isLoading {
                ProgressView()
                    .tint(Color.photoAccent)
                    .padding(40)
            } else {
                Text("没有找到这个拍摄窗口。")
                    .foregroundStyle(Color.photoMutedText)
                    .padding(20)
            }
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("窗口详情")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
    }

    private func header(_ window: ShootingWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(window.category.displayName, systemImage: window.category.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.photoAccent)

            Text(window.windowTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.location.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(window.startTime.formatted(date: .abbreviated, time: .shortened)) - \(window.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                    Text("建议到场 \(window.suggestedArrivalTime.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)
                }

                Spacer()

                ScoreBadge(score: window.score, level: window.scoreLevel)
            }
        }
    }

    private func actionButtons(_ window: ShootingWindow) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleAlert() }
            } label: {
                Label(window.alertEnabled ? "关闭提醒" : "开启提醒", systemImage: window.alertEnabled ? "bell.fill" : "bell")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)

            Button {
                Task { await viewModel.toggleBookmark() }
            } label: {
                Image(systemName: window.isBookmarked ? "bookmark.fill" : "bookmark")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
            .accessibilityLabel(window.isBookmarked ? "取消收藏" : "收藏")
        }
    }

    private func reminderPresetSection(_ window: ShootingWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("提醒时间")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("当前设置：提前 \(ShootingWindowDetailViewModel.formatReminderLead(minutes: viewModel.selectedReminderMinutes))")
                        .font(.caption)
                        .foregroundStyle(Color.photoMutedText)
                }

                Spacer()

                Label(window.alertEnabled ? "已开启" : "未开启", systemImage: window.alertEnabled ? "bell.fill" : "bell")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(viewModel.reminderPresetOptions) { option in
                    reminderPresetButton(
                        title: option.title,
                        isSelected: !viewModel.usesCustomReminder && viewModel.selectedReminderMinutes == option.minutes
                    ) {
                        viewModel.selectReminderPreset(option)
                    }
                }

                reminderPresetButton(title: "自定义", isSelected: viewModel.usesCustomReminder) {
                    viewModel.setCustomReminderMinutes(viewModel.selectedReminderMinutes)
                }
            }

            if viewModel.usesCustomReminder {
                Stepper(
                    "自定义提前 \(ShootingWindowDetailViewModel.formatReminderLead(minutes: viewModel.selectedReminderMinutes))",
                    value: Binding(
                        get: { viewModel.selectedReminderMinutes },
                        set: { viewModel.setCustomReminderMinutes($0) }
                    ),
                    in: 5...4_320,
                    step: 15
                )
                .font(.subheadline)
                .foregroundStyle(.white)
            }
        }
        .photoCardStyle()
    }

    private func reminderPresetButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .black : Color.photoAccent)
        .background(isSelected ? Color.photoAccent : Color.photoAccent.opacity(0.12))
        .clipShape(Capsule())
    }

    private func eventReminderSection(_ window: ShootingWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("特殊事件提醒")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let event = window.primaryEvent {
                    EventImportanceBadge(level: event.importanceLevel)
                }
            }

            if let event = window.primaryEvent {
                Text(event.importanceExplanation)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.88))
            } else {
                Text("该窗口没有关联特殊事件，将按普通拍摄窗口提醒。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
            }

            if !viewModel.matchedWatchlistKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("命中关注关键词")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoMutedText)
                    ReasonTagChips(tags: viewModel.matchedWatchlistKeywords)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("建议提醒：提前 \(ShootingWindowDetailViewModel.formatReminderLead(minutes: viewModel.selectedReminderMinutes))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
                Text(viewModel.reminderMergeSummary)
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
            }
        }
        .photoCardStyle()
    }

    private func recommendation(_ window: ShootingWindow) -> some View {
        let recommendation = window.effectiveRecommendationResult

        return VStack(alignment: .leading, spacing: 12) {
            Text("推荐理由")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ReasonTagChips(tags: recommendation.reasonTags)

            Text(recommendation.reasonSummary)
                .font(.body)
                .foregroundStyle(.white.opacity(0.88))

            Text(recommendation.recommendationText)
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)

            VStack(alignment: .leading, spacing: 8) {
                detailRow("评分等级", recommendation.scoreLevel.displayName)
                detailRow("可信度", recommendation.confidenceLevel.displayName)
                detailRow("建议到场", "提前 \(ShootingWindowDetailViewModel.formatReminderLead(minutes: recommendation.arrivalSuggestionMinutes))")
                detailRow("默认提醒", recommendation.shouldNotifyByDefault ? "建议开启" : "不建议默认开启")
            }

            if !recommendation.penaltyTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("扣分原因")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoMutedText)
                    ReasonTagChips(tags: recommendation.penaltyTags)
                    if let penaltySummary = recommendation.penaltySummary {
                        Text(penaltySummary)
                            .font(.caption)
                            .foregroundStyle(Color.photoMutedText)
                    }
                }
            }

            if !recommendation.riskNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("风险提示")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoMutedText)
                    ForEach(recommendation.riskNotes, id: \.self) { note in
                        Label(note, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Color.photoMutedText)
                    }
                }
            }

            if !recommendation.suitableFor.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("适合人群")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoMutedText)
                    ReasonTagChips(tags: recommendation.suitableFor)
                }
            }
        }
        .photoCardStyle()
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这个推荐有用吗？")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if viewModel.feedbackSubmitted {
                Label("感谢反馈", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    ForEach(FeedbackRating.allCases) { rating in
                        feedbackRatingButton(rating)
                    }
                }

                TextField("可选补充原因", text: $viewModel.feedbackComment, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    Task { await viewModel.submitFeedback() }
                } label: {
                    Label("提交反馈", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.photoAccent)
                .disabled(viewModel.selectedFeedbackRating == nil || viewModel.isSubmittingFeedback)
            }
        }
        .photoCardStyle()
    }

    private func feedbackRatingButton(_ rating: FeedbackRating) -> some View {
        let isSelected = viewModel.selectedFeedbackRating == rating

        return Button {
            viewModel.selectFeedbackRating(rating)
        } label: {
            Text(rating.displayName)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .black : Color.photoAccent)
        .background(isSelected ? Color.photoAccent : Color.photoAccent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    @ViewBuilder
    private func scoreBreakdownSection(_ window: ShootingWindow) -> some View {
        if !window.scoreBreakdown.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("评分拆解")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("总分 \(window.score)/100")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)
                }

                VStack(spacing: 10) {
                    ForEach(window.scoreBreakdown) { item in
                        HStack {
                            Text(item.title)
                                .foregroundStyle(.white.opacity(0.88))
                            Spacer()
                            Text("\(item.score)/\(item.maxScore)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.photoAccent)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .photoCardStyle()
        }
    }

    @ViewBuilder
    private func notRecommendedSection(_ window: ShootingWindow) -> some View {
        if window.score < 70 {
            VStack(alignment: .leading, spacing: 12) {
                Text("不推荐原因")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(window.notRecommendedReason ?? window.reasonSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.88))

                if let alternative = viewModel.alternativeWindow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("更好的窗口")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.photoMutedText)

                        NavigationLink {
                            ShootingWindowDetailScreen(windowID: alternative.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alternative.windowTitle)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(alternative.startTime.formatted(date: .abbreviated, time: .shortened)) - \(alternative.endTime.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(Color.photoMutedText)
                                }

                                Spacer()

                                ScoreBadge(score: alternative.score, level: alternative.scoreLevel)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .photoCardStyle()
        }
    }

    private func checklistSection(_ category: PhotographyCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("出发前检查")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(category.shootingChecklist, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .photoCardStyle()
    }

    private func weatherSection(_ weather: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("天气快照")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                WeatherMetricView(title: "温度", value: "\(Int(weather.temperature)) C", iconName: "thermometer")
                WeatherMetricView(title: "云量", value: "\(Int(weather.cloudCover))%", iconName: "cloud")
                WeatherMetricView(title: "降雨概率", value: "\(Int(weather.precipitationProbability))%", iconName: "cloud.rain")
                WeatherMetricView(title: "风速", value: "\(Int(weather.windSpeed)) km/h", iconName: "wind")
                WeatherMetricView(title: "能见度", value: "\(Int(weather.visibility)) km", iconName: "eye")
                WeatherMetricView(title: "月亮照明", value: "\(Int(weather.moonIllumination))%", iconName: "moon")
            }
        }
    }

    private func relatedEvents(_ events: [ShootingEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相关事件")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if events.isEmpty {
                Text("没有关联的特殊事件。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                    .photoCardStyle()
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        EventImportanceBadge(level: event.importanceLevel)
                        Text(event.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.photoMutedText)
                        Text(event.importanceExplanation)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.82))
                        Text(event.tags.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Color.photoAccent)
                    }
                    .photoCardStyle()
                }
            }
        }
    }
}
