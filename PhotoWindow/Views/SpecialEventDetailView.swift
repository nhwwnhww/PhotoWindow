import SwiftUI

struct SpecialEventDetailView: View {
    @StateObject private var viewModel: SpecialEventDetailViewModel

    init(viewModel: SpecialEventDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            if let event = viewModel.event {
                VStack(alignment: .leading, spacing: 22) {
                    header(event)
                    actionButtons
                    recommendationSection
                    metadataSection(event)
                    tagsSection(event)
                    associatedWindowSection
                }
                .padding(20)
            } else if viewModel.isLoading {
                ProgressView()
                    .tint(Color.photoAccent)
                    .padding(40)
            } else {
                Text("没有找到这个特殊事件。")
                    .foregroundStyle(Color.photoMutedText)
                    .padding(20)
            }
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("事件详情")
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

    private func header(_ event: SpecialEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(event.category.displayName, systemImage: event.category.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.photoAccent)

            Text(event.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.locationName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.eventTimeText)
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
            }

            HStack(spacing: 8) {
                EventImportanceBadge(level: event.importanceLevel)
                SpecialEventConfidenceBadge(level: event.confidenceLevel)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleAlert() }
            } label: {
                Label(viewModel.isAlertEnabled ? "关闭提醒" : "开启提醒", systemImage: viewModel.isAlertEnabled ? "bell.fill" : "bell")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)

            Button {
                Task { await viewModel.toggleBookmark() }
            } label: {
                Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
            .accessibilityLabel(viewModel.isBookmarked ? "取消收藏" : "收藏")
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐理由")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ReasonTagChips(tags: viewModel.reasonTags)

            Text(viewModel.recommendationText)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            if let window = viewModel.shootingWindow {
                Text("关联窗口评分 \(window.score)/100，建议提醒 \(viewModel.reminderLeadText)。")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
            }
        }
        .photoCardStyle()
    }

    private func metadataSection(_ event: SpecialEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("事件信息")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            detailRow("类别", event.category.displayName)
            detailRow("地点", event.locationName)
            detailRow("时间", viewModel.eventTimeText)
            detailRow("重要程度", "\(event.importanceLevel.displayName) · \(event.importanceLevel.rawValue)")
            detailRow("可信度", "\(event.confidenceLevel.displayName) · \(event.confidenceLevel.rawValue)")
            detailRow("来源类型", "\(event.sourceType.displayName) · \(event.sourceType.rawValue)")
            detailRow("来源", event.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : event.sourceName)
            sourceURLRow(event.sourceURL)
            detailRow("数据更新", viewModel.sourceUpdatedText)
        }
        .photoCardStyle()
    }

    private func tagsSection(_ event: SpecialEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            ReasonTagChips(tags: ([event.eventReasonTag] + event.tags).removingDuplicates())
        }
        .photoCardStyle()
    }

    @ViewBuilder
    private var associatedWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关联 ShootingWindow")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if let window = viewModel.shootingWindow {
                NavigationLink {
                    ShootingWindowDetailScreen(windowID: window.id)
                } label: {
                    ShootingWindowCard(window: window)
                }
                .buttonStyle(.plain)
            } else {
                Text("暂未生成关联拍摄窗口。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                    .photoCardStyle()
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func sourceURLRow(_ sourceURL: String?) -> some View {
        let trimmed = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            detailRow("来源链接", "-")
        } else if let url = URL(string: trimmed) {
            HStack(alignment: .top) {
                Text("来源链接")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                Spacer(minLength: 12)
                Link(trimmed, destination: url)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            detailRow("来源链接", trimmed)
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
