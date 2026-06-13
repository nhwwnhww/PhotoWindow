import SwiftUI

struct ShootingWindowCard: View {
    let window: ShootingWindow

    var body: some View {
        let recommendation = window.effectiveRecommendationResult

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(window.category.displayName, systemImage: window.category.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)

                    if let event = window.primaryEvent {
                        HStack(spacing: 6) {
                            SpecialEventBadge()
                            EventImportanceBadge(level: event.importanceLevel)
                        }
                    }

                    Text(window.windowTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(window.location.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                }

                Spacer(minLength: 8)

                ScoreBadge(score: window.score, level: window.scoreLevel)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                Text(recommendation.scoreLevel.displayName)
                Text("可信度 \(recommendation.confidenceLevel.displayName)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.photoAccent)

            Text(recommendation.reasonSummary)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            ReasonTagChips(tags: Array(recommendation.reasonTags.prefix(3)))

            HStack(spacing: 8) {
                Label(window.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                Spacer()
                Label(window.suggestedArrivalTime.formatted(date: .omitted, time: .shortened), systemImage: "figure.walk.arrival")
                if window.alertEnabled {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Color.photoAccent)
                }
                if window.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color.photoAccent)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.photoMutedText)
        }
        .photoCardStyle()
    }
}

struct SpecialEventBadge: View {
    var body: some View {
        Label("特殊事件", systemImage: "sparkles")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.photoAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.photoAccent.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct EventImportanceBadge: View {
    let level: EventImportanceLevel

    var body: some View {
        Text(level.badgeText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(level == .normal ? Color.photoMutedText : Color.photoAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((level == .normal ? Color.white : Color.photoAccent).opacity(0.12))
            .clipShape(Capsule())
    }
}

struct ReasonTagChips: View {
    let tags: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 74), spacing: 6, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.photoAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(Color.photoAccent.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}
