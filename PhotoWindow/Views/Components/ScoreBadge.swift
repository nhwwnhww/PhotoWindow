import SwiftUI

struct ScoreBadge: View {
    let score: Int
    let level: ShootingWindowScoreLevel

    var body: some View {
        Text("\(level.displayName) · \(score)/100")
            .font(.caption.weight(.bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.scoreColor(for: level))
        .clipShape(Capsule())
        .accessibilityLabel("评分 \(score)，\(level.displayName)")
    }
}
