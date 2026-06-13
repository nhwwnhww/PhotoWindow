import SwiftUI

struct SpecialEventsView: View {
    @StateObject private var viewModel: SpecialEventsViewModel

    init(viewModel: SpecialEventsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dataStatus
                refreshButton

                if viewModel.isLoading && viewModel.sections.isEmpty {
                    ProgressView()
                        .tint(Color.photoAccent)
                        .frame(maxWidth: .infinity)
                } else if viewModel.sections.isEmpty {
                    Text("未来一周暂无特殊事件。")
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                        .photoCardStyle()
                } else {
                    ForEach(viewModel.sections) { section in
                        eventSection(section)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("特殊事件")
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
            Text("特殊事件")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("Today / Tomorrow / This Week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.photoAccent)
        }
    }

    private var dataStatus: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: viewModel.dataSourceWarningMessage == nil ? "clock.arrow.circlepath" : "exclamationmark.triangle")
                .foregroundStyle(Color.photoAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.dataSourceWarningMessage ?? viewModel.dataSourceText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                if viewModel.dataSourceWarningMessage != nil {
                    Text(viewModel.statusText)
                        .font(.caption2)
                        .foregroundStyle(Color.photoMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("同步状态：\(viewModel.syncState.displayName)")
                        .font(.caption2)
                        .foregroundStyle(Color.photoMutedText)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func eventSection(_ section: SpecialEventSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(section.events) { event in
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

struct SpecialEventRow: View {
    let event: SpecialEvent
    let watchlistHitText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Label(event.category.displayName, systemImage: event.category.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)

                    Text(event.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.locationName)
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    EventImportanceBadge(level: event.importanceLevel)
                    SpecialEventConfidenceBadge(level: event.confidenceLevel)
                }
            }

            HStack(spacing: 8) {
                Label(event.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                Spacer()
                Label(event.endTime.formatted(date: .omitted, time: .shortened), systemImage: "flag.checkered")
            }
            .font(.caption)
            .foregroundStyle(Color.photoMutedText)

            if let watchlistHitText {
                Label(watchlistHitText, systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
            }

            Text(recommendationPreview)
                .font(.caption)
                .foregroundStyle(Color.photoMutedText)
                .fixedSize(horizontal: false, vertical: true)

            ReasonTagChips(tags: Array(([event.eventReasonTag] + event.tags).prefix(5)))
        }
        .photoCardStyle()
    }

    private var recommendationPreview: String {
        let confidenceText = event.confidenceLevel == .low
            ? "可信度偏低，出发前需要复核。"
            : "可信度\(event.confidenceLevel.displayName)，可进入提醒候选。"
        let importanceText = event.importanceLevel == .mustShoot || event.importanceLevel == .rare
            ? "\(event.importanceLevel.displayName)事件，推荐系统会优先保留。"
            : "\(event.importanceLevel.displayName)事件，适合作为普通拍摄窗口参考。"
        return "推荐预览：\(importanceText) \(confidenceText)"
    }
}

struct SpecialEventConfidenceBadge: View {
    let level: SpecialEventConfidenceLevel

    var body: some View {
        Text("可信度 \(level.displayName)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(level == .low ? Color.photoMutedText : Color.photoAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((level == .low ? Color.white : Color.photoAccent).opacity(0.12))
            .clipShape(Capsule())
    }
}
