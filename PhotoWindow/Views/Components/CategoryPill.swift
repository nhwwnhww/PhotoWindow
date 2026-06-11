import SwiftUI

struct CategoryPill: View {
    let category: PhotographyCategory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.iconName)
                .font(.headline)
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.photoAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(category.key)
                    .font(.caption2)
                    .foregroundStyle(Color.photoMutedText)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 58)
        .photoCardStyle()
    }
}
