import SwiftUI

struct ExploreLocationsView: View {
    @StateObject private var viewModel: LocationViewModel

    init(viewModel: LocationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("拍摄地点")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                ForEach(viewModel.locations) { location in
                    locationCard(location)
                }
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("地点")
        .photoInlineNavigationTitle()
        .task {
            await viewModel.load()
        }
    }

    private func locationCard(_ location: ShootingLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: location.locationType))
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color.photoAccent)

                VStack(alignment: .leading, spacing: 5) {
                    Text(location.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(location.city), \(location.country)")
                        .font(.subheadline)
                        .foregroundStyle(Color.photoMutedText)
                    Text(location.notes)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                Label(location.locationType.displayName, systemImage: "tag")
                Spacer()
                Label("光污染 \(location.lightPollutionLevel)/9", systemImage: "moon.stars")
                Spacer()
                Label("\(viewModel.windowCount(for: location)) 个窗口", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(Color.photoMutedText)
        }
        .photoCardStyle()
    }

    private func icon(for type: ShootingLocationType) -> String {
        switch type {
        case .airport:
            return "airplane"
        case .darkSky:
            return "moon.stars"
        case .campus:
            return "graduationcap"
        case .scenic:
            return "mountain.2"
        case .urban:
            return "building.2"
        case .wildlifeArea:
            return "pawprint"
        }
    }
}
