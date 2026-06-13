import SwiftUI
import UIKit

struct SpecialEventDetailView: View {
    @StateObject private var viewModel: SpecialEventDetailViewModel
    @State private var shareSheetItem: ShareSheetItem?

    init(viewModel: SpecialEventDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            if let event = viewModel.event {
                VStack(alignment: .leading, spacing: 22) {
                    header(event)
                    actionButtons
                    exportActionSection
                    recommendationSection
                    metadataSection(event)
                    sourceSection(event)
                    aviationNotice(event)
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
        .sheet(item: $shareSheetItem) { item in
            ShareSheet(activityItems: item.activityItems)
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

    private var exportActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("拍摄计划")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Button {
                Task { await viewModel.addToCalendar() }
            } label: {
                Label(viewModel.isExportingCalendar ? "写入中" : "加入系统日历", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)
            .disabled(viewModel.isExportingCalendar)

            VStack(spacing: 10) {
                Button {
                    let items = viewModel.shareActivityItems()
                    guard !items.isEmpty else { return }
                    shareSheetItem = ShareSheetItem(activityItems: items)
                } label: {
                    Label("分享拍摄卡片", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoAccent)

                Button {
                    guard let text = viewModel.copyPlanText() else { return }
                    UIPasteboard.general.string = text
                } label: {
                    Label("复制拍摄计划文本", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoAccent)
            }

            if let exportMessage = viewModel.exportMessage {
                Label(exportMessage, systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
            }
        }
        .photoCardStyle()
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
        }
        .photoCardStyle()
    }

    private func sourceSection(_ event: SpecialEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据来源")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            detailRow("sourceType", "\(event.sourceType.displayName) · \(event.sourceType.rawValue)")
            detailRow("sourceName", displaySourceName(for: event))
            sourceURLRow(event.sourceURL, title: "sourceURL")
            detailRow("lastUpdated", viewModel.sourceUpdatedText)

            if event.tags.isEmpty {
                detailRow("tags", "-")
            } else {
                Text("tags")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                ReasonTagChips(tags: event.tags)
            }
        }
        .photoCardStyle()
    }

    @ViewBuilder
    private func aviationNotice(_ event: SpecialEvent) -> some View {
        if event.sourceType == .aviationAPI {
            Label("该航空事件由实时航迹数据推导，拍摄前建议确认航班状态和机场风向。", systemImage: "airplane.departure")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.photoAccent)
                .fixedSize(horizontal: false, vertical: true)
                .photoCardStyle()
        }
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

    private func displaySourceName(for event: SpecialEvent) -> String {
        let sourceName = event.sourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "PhotoWindow", with: "photochaser")
        return sourceName.isEmpty ? "-" : sourceName
    }

    @ViewBuilder
    private func sourceURLRow(_ sourceURL: String?, title: String = "来源链接") -> some View {
        let trimmed = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            detailRow(title, "-")
        } else if let url = URL(string: trimmed) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
                Spacer(minLength: 12)
                Link(trimmed, destination: url)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            detailRow(title, trimmed)
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
