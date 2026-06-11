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
                    recommendation(window)
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

    private func recommendation(_ window: ShootingWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐理由")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(window.reasonSummary)
                .font(.body)
                .foregroundStyle(.white.opacity(0.88))

            Text(window.recommendationText)
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
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
                        Text(event.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.photoMutedText)
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
