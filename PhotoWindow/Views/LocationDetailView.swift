import SwiftUI

struct LocationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LocationDetailViewModel

    init(viewModel: LocationDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            if let location = viewModel.location {
                VStack(alignment: .leading, spacing: 18) {
                    header(location)
                    actions(location)
                    categories(location)
                    windowsSection
                    alertRulesSection(location)
                    notesSection(location)
                }
                .padding(20)
            } else if viewModel.isLoading {
                ProgressView()
                    .tint(Color.photoAccent)
                    .padding(40)
            } else {
                Text("没有找到这个地点。")
                    .foregroundStyle(Color.photoMutedText)
                    .padding(20)
            }
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("地点详情")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.didDelete) { _, didDelete in
            if didDelete {
                dismiss()
            }
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

    private func header(_ location: ShootingLocation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(location.locationType.displayName, systemImage: location.locationType.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.photoAccent)

            Text(location.name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(location.city), \(location.country)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.86))

            Text("\(String(format: "%.5f", location.latitude)), \(String(format: "%.5f", location.longitude))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.photoMutedText)
        }
    }

    private func actions(_ location: ShootingLocation) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    Label(location.isFavorite ? "取消收藏" : "收藏地点", systemImage: location.isFavorite ? "star.fill" : "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.photoAccent)

                NavigationLink {
                    AddLocationScreen(existingLocation: location)
                } label: {
                    Label("编辑", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoAccent)
            }

            Button(role: .destructive) {
                Task { await viewModel.deleteLocation() }
            } label: {
                Label("删除地点", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func categories(_ location: ShootingLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("适合类别")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("光污染 \(location.lightPollutionLevel)/9")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoMutedText)
            }

            ReasonTagChips(tags: viewModel.supportedCategories.map(\.displayName))
        }
        .photoCardStyle()
    }

    private var windowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("未来 7 天最佳拍摄窗口")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if viewModel.windows.isEmpty && !viewModel.isLoading {
                Text("这个地点暂时没有生成高质量拍摄窗口。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                    .photoCardStyle()
            } else {
                ForEach(viewModel.windows.prefix(8)) { window in
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

    private func alertRulesSection(_ location: ShootingLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地点提醒规则")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if viewModel.alertRules.isEmpty {
                Text("还没有为这个地点开启提醒。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
            } else {
                ForEach(viewModel.alertRules) { rule in
                    HStack {
                        Label(rule.category.displayName, systemImage: rule.category.iconName)
                        Spacer()
                        Text(rule.isEnabled ? "已开启" : "已关闭")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                ForEach(viewModel.supportedCategories) { category in
                    Button {
                        Task { await viewModel.createAlertRule(for: category) }
                    } label: {
                        Label(category.displayName, systemImage: "bell.badge")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.photoAccent)
                }
            }
        }
        .photoCardStyle()
    }

    private func notesSection(_ location: ShootingLocation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("地点备注")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(location.notes.isEmpty ? "暂无备注。" : location.notes)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .photoCardStyle()
    }
}
