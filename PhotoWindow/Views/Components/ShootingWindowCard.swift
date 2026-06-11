import SwiftUI

struct ShootingWindowCard: View {
    let window: ShootingWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(window.category.displayName, systemImage: window.category.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoAccent)

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
            }

            Text(window.reasonSummary)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label(window.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                Spacer()
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
