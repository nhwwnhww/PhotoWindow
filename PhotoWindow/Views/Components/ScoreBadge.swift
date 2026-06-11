import SwiftUI

struct ScoreBadge: View {
    let score: Int
    let level: ShootingWindowScoreLevel

    var body: some View {
        HStack(spacing: 6) {
            Text("\(score)")
                .font(.headline.weight(.bold))
            Text(level.displayName)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.scoreColor(for: level))
        .clipShape(Capsule())
        .accessibilityLabel("评分 \(score)，\(level.displayName)")
    }
}
