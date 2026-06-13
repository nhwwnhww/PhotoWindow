import SwiftUI

struct ExploreLocationsView: View {
    @StateObject private var viewModel: ExploreLocationsViewModel

    init(viewModel: ExploreLocationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                typeFilter
                favoriteSection
                allLocationsSection

                NavigationLink {
                    AddLocationScreen()
                } label: {
                    Label("添加地点", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.photoAccent)
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

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("拍摄地点")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("管理收藏地点和自定义拍摄点位。")
                    .font(.subheadline)
                    .foregroundStyle(Color.photoMutedText)
            }

            Spacer()
        }
    }

    private var typeFilter: some View {
        Picker("地点类型", selection: $viewModel.selectedType) {
            Text("全部类型").tag(ShootingLocationType?.none)
            ForEach(ShootingLocationType.allCases) { type in
                Text(type.displayName).tag(Optional(type))
            }
        }
        .pickerStyle(.menu)
        .tint(Color.photoAccent)
    }

    private var favoriteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("我的收藏地点")

            if viewModel.filteredFavoriteLocations.isEmpty {
                emptyState("还没有收藏地点。收藏常用点位后会优先生成高分窗口。")
            } else {
                ForEach(viewModel.filteredFavoriteLocations) { location in
                    locationLink(location)
                }
            }
        }
    }

    private var allLocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("所有保存地点")

            if viewModel.filteredSavedLocations.isEmpty {
                emptyState("添加你的第一个拍摄地点，PhotoWindow 会帮你寻找最佳拍摄时间。")
            } else {
                ForEach(viewModel.filteredSavedLocations) { location in
                    locationLink(location)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.photoMutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .photoCardStyle()
    }

    private func locationLink(_ location: ShootingLocation) -> some View {
        NavigationLink {
            LocationDetailScreen(locationID: location.id)
        } label: {
            locationCard(location)
        }
        .buttonStyle(.plain)
    }

    private func locationCard(_ location: ShootingLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: location.locationType.iconName)
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

                if location.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.photoAccent)
                }
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

            ReasonTagChips(tags: location.supportedCategories.map(\.displayName))
        }
        .photoCardStyle()
    }
}
