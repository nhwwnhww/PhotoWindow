import SwiftUI

struct CategoryView: View {
    @StateObject private var viewModel: CategoryViewModel

    init(viewModel: CategoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.category.iconName)
                        .font(.title2)
                        .foregroundStyle(Color.photoAccent)
                    Text(viewModel.category.displayName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                }

                if viewModel.windows.isEmpty && !viewModel.isLoading {
                    Text("这个类别暂时没有 mock 拍摄窗口。")
                        .foregroundStyle(Color.photoMutedText)
                        .photoCardStyle()
                } else {
                    ForEach(viewModel.windows) { window in
                        NavigationLink {
                            ShootingWindowDetailScreen(windowID: window.id)
                        } label: {
                            ShootingWindowCard(window: window)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle(viewModel.category.displayName)
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
    }
}
