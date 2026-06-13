import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                dataStatus
                refreshButton

                if viewModel.isLoading && viewModel.windows.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .tint(Color.photoAccent)
                } else if !viewModel.hasSavedLocations {
                    firstLocationEmptyState
                } else {
                    dailySummarySection
                    upcomingSpecialEventsSection
                    upcomingNotificationsSection
                    favoriteWindowsSection
                    todaySection
                    topWindowsSection
                    categoriesSection
                    specialEventWindowsSection
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("photochaser")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .savedLocationsDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = viewModel.errorMessage, viewModel.fallbackMessage == nil {
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
            Text("摄影机会雷达")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("未来几天值得拍的窗口、事件和提醒都在这里。")
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
        }
    }

    @ViewBuilder
    private var dataStatus: some View {
        if viewModel.isLoading && !viewModel.windows.isEmpty {
            statusCard(icon: "arrow.triangle.2.circlepath", title: "正在刷新天气和天文数据", detail: nil)
        } else if let specialEventWarningMessage = viewModel.specialEventWarningMessage {
            statusCard(
                icon: "exclamationmark.triangle",
                title: specialEventWarningMessage,
                detail: viewModel.specialEventDebugText
            )
        } else if let fallbackMessage = viewModel.fallbackMessage {
            statusCard(
                icon: "exclamationmark.triangle",
                title: fallbackMessage,
                detail: [viewModel.specialEventDebugText, viewModel.errorMessage]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            )
        } else if let lastUpdated = viewModel.lastUpdated {
            statusCard(
                icon: "clock.arrow.circlepath",
                title: "数据更新于 \(lastUpdated.formatted(date: .omitted, time: .shortened))",
                detail: viewModel.specialEventDebugText
            )
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            Label(viewModel.isLoading ? "刷新中" : "刷新事件数据", systemImage: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.photoAccent)
        .disabled(viewModel.isLoading)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("今日推荐")

            if let window = viewModel.todayRecommendations.first {
                NavigationLink {
                    ShootingWindowDetailScreen(windowID: window.id)
                } label: {
                    ShootingWindowCard(window: window)
                }
                .buttonStyle(.plain)
                .onAppear {
                    viewModel.recordHomeWindowViewed(window)
                }
            } else {
                emptyState("今天暂时没有高分拍摄窗口。")
            }
        }
    }

    private var dailySummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("今日摄影机会摘要")
            Text(viewModel.dailySummaryText)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .photoCardStyle()
        }
    }

    private var upcomingNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("即将触发的地点提醒")
                Spacer()
                NavigationLink {
                    UpcomingNotificationsScreen()
                } label: {
                    Text("查看全部")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)
                }
            }

            if viewModel.upcomingNotifications.isEmpty {
                emptyState("还没有自动匹配到提醒。保存偏好或开启规则后会显示在这里。")
            } else {
                ForEach(viewModel.upcomingNotifications.prefix(3)) { notification in
                    if let window = notification.relatedWindow {
                        NavigationLink {
                            ShootingWindowDetailScreen(windowID: window.id)
                        } label: {
                            upcomingNotificationRow(notification, window: window)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.recordNotificationClicked(notification)
                        })
                        .onAppear {
                            viewModel.recordHomeWindowViewed(window)
                        }
                    } else {
                        upcomingNotificationRow(notification, window: nil)
                    }
                }
            }
        }
    }

    private var favoriteWindowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("收藏地点高分窗口")

            if viewModel.favoriteTopWindows.isEmpty {
                emptyState("收藏常用地点后，这里会优先显示这些地点的高分拍摄窗口。")
            } else {
                ForEach(viewModel.favoriteTopWindows) { window in
                    NavigationLink {
                        ShootingWindowDetailScreen(windowID: window.id)
                    } label: {
                        ShootingWindowCard(window: window)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        viewModel.recordHomeWindowViewed(window)
                    }
                }
            }
        }
    }

    private var topWindowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("评分最高的 3 个窗口")

            ForEach(viewModel.topWindows) { window in
                NavigationLink {
                    ShootingWindowDetailScreen(windowID: window.id)
                } label: {
                    ShootingWindowCard(window: window)
                }
                .buttonStyle(.plain)
                .onAppear {
                    viewModel.recordHomeWindowViewed(window)
                }
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("按类别查看")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PhotographyCategory.mvpCases) { category in
                    NavigationLink {
                        CategoryScreen(category: category)
                    } label: {
                        CategoryPill(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var upcomingSpecialEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("即将发生的特殊事件")
                Spacer()
                NavigationLink {
                    SpecialEventsScreen()
                } label: {
                    Text("查看全部")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)
                }
            }

            if viewModel.priorityUpcomingSpecialEvents.isEmpty {
                emptyState("未来一周暂无特殊事件。")
            } else {
                ForEach(viewModel.priorityUpcomingSpecialEvents.prefix(3)) { event in
                    NavigationLink {
                        SpecialEventDetailScreen(eventID: event.id)
                    } label: {
                        SpecialEventRow(
                            event: event,
                            watchlistHitText: viewModel.watchlistHitText(for: event)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var specialEventWindowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("特殊事件驱动窗口")

            if viewModel.specialEvents.isEmpty {
                emptyState("当前没有特殊事件提醒。")
            } else {
                ForEach(viewModel.specialEvents.prefix(4)) { window in
                    NavigationLink {
                        ShootingWindowDetailScreen(windowID: window.id)
                    } label: {
                        ShootingWindowCard(window: window)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        viewModel.recordHomeWindowViewed(window)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.photoMutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .photoCardStyle()
    }

    private var firstLocationEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加你的第一个拍摄地点，photochaser 会帮你寻找最佳拍摄时间。")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                AddLocationScreen()
            } label: {
                Label("添加地点", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }

    private func statusCard(icon: String, title: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.photoAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Color.photoMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func upcomingNotificationRow(_ notification: NotificationItem, window: ShootingWindow?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell")
                .foregroundStyle(Color.photoAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(window?.windowTitle ?? notification.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(2)
                Text("提醒 \(notification.triggerTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
            }

            Spacer()

            if let window {
                ScoreBadge(score: window.score, level: window.scoreLevel)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .photoCardStyle()
    }
}
