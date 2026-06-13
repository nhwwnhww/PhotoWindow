import SwiftUI

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddLocationViewModel

    init(viewModel: AddLocationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchSection
                coordinateSection
                detailSection
                saveButton
            }
            .padding(20)
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle(viewModel.isEditing ? "编辑地点" : "添加地点")
        .photoInlineNavigationTitle()
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave {
                dismiss()
            }
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
            Text(viewModel.isEditing ? "更新拍摄地点" : "添加你的拍摄地点")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("photochaser 会基于地点类型、光污染和适合类别生成未来拍摄窗口。")
                .font(.subheadline)
                .foregroundStyle(Color.photoMutedText)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("搜索地点")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                TextField("搜索地点或城市", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    Task { await viewModel.search() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.bordered)
                .tint(Color.photoAccent)
                .accessibilityLabel("搜索地点")
            }

            Button {
                Task { await viewModel.useCurrentLocation() }
            } label: {
                Label("使用当前位置", systemImage: "location")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)

            ForEach(viewModel.searchResults) { location in
                Button {
                    viewModel.selectSearchResult(location)
                } label: {
                    searchResultRow(location)
                }
                .buttonStyle(.plain)
            }
        }
        .photoCardStyle()
    }

    private var coordinateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("经纬度")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            NavigationLink {
                MapLocationPickerView(viewModel: viewModel)
            } label: {
                Label("地图选点", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)

            HStack(spacing: 10) {
                TextField("纬度", text: $viewModel.latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                TextField("经度", text: $viewModel.longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                Task { await viewModel.reverseGeocodeManualCoordinate() }
            } label: {
                Label("用手动坐标填充地点信息", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.photoAccent)
        }
        .photoCardStyle()
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("地点信息")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            textField("地点名称", text: $viewModel.name)

            HStack(spacing: 10) {
                textField("城市", text: $viewModel.city)
                textField("国家", text: $viewModel.country)
            }

            Picker("地点类型", selection: Binding(
                get: { viewModel.locationType },
                set: { viewModel.setLocationType($0) }
            )) {
                ForEach(ShootingLocationType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.photoAccent)

            categorySelector

            VStack(alignment: .leading, spacing: 6) {
                Text("光污染等级 \(viewModel.lightPollutionLevel)/9")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Stepper(
                    "光污染等级",
                    value: $viewModel.lightPollutionLevel,
                    in: 1...9
                )
                .labelsHidden()
            }

            TextField("备注", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .photoCardStyle()
    }

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("适合的摄影类别")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                ForEach(PhotographyCategory.allCases) { category in
                    Button {
                        viewModel.toggleCategory(category)
                    } label: {
                        Label(category.displayName, systemImage: category.iconName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.selectedCategories.contains(category) ? .black : Color.photoAccent)
                    .background(
                        viewModel.selectedCategories.contains(category)
                            ? Color.photoAccent
                            : Color.photoAccent.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            Label(viewModel.isEditing ? "保存修改" : "保存地点", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.photoAccent)
        .disabled(!viewModel.canSave || viewModel.isLoading)
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.words)
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func searchResultRow(_ location: ShootingLocation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: location.locationType.iconName)
                .foregroundStyle(Color.photoAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(location.city), \(location.country)")
                    .font(.caption)
                    .foregroundStyle(Color.photoMutedText)
                Text("lat \(String(format: "%.5f", location.latitude)) / lon \(String(format: "%.5f", location.longitude))")
                    .font(.caption2)
                    .foregroundStyle(Color.photoMutedText)
                Label("建议类型：\(location.locationType.displayName)", systemImage: location.locationType.iconName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.photoAccent)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
