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

                if viewModel.isLoading && viewModel.windows.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .tint(Color.photoAccent)
                } else {
                    todaySection
                    topWindowsSection
                    categoriesSection
                    specialEventsSection
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("PhotoWindow")
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
            Text("摄影机会雷达")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("未来几天值得拍的窗口、事件和提醒都在这里。")
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
        }
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
            } else {
                emptyState("今天暂时没有高分拍摄窗口。")
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
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("按类别查看")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PhotographyCategory.allCases) { category in
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

    private var specialEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("即将发生的特殊事件")

            if viewModel.specialEvents.isEmpty {
                emptyState("当前没有特殊事件提醒。")
            } else {
                ForEach(viewModel.specialEvents) { window in
                    NavigationLink {
                        ShootingWindowDetailScreen(windowID: window.id)
                    } label: {
                        ShootingWindowCard(window: window)
                    }
                    .buttonStyle(.plain)
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
}
