import SwiftUI

struct WeatherMetricView: View {
    let title: String
    let value: String
    let iconName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.subheadline)
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.photoAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.photoElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
