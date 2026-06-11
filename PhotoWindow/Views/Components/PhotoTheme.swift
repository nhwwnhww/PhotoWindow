import SwiftUI

extension Color {
    static let photoBackground = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let photoSurface = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let photoElevated = Color(red: 0.15, green: 0.16, blue: 0.20)
    static let photoAccent = Color(red: 0.97, green: 0.72, blue: 0.31)
    static let photoMutedText = Color(red: 0.65, green: 0.68, blue: 0.74)

    static func scoreColor(for level: ShootingWindowScoreLevel) -> Color {
        switch level {
        case .poor:
            return Color(red: 0.67, green: 0.72, blue: 0.78)
        case .okay:
            return Color(red: 0.42, green: 0.70, blue: 0.95)
        case .good:
            return Color(red: 0.35, green: 0.82, blue: 0.57)
        case .excellent:
            return .photoAccent
        }
    }
}

extension View {
    func photoCardStyle() -> some View {
        padding(16)
            .background(Color.photoSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    @ViewBuilder
    func photoInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
