import Foundation
import Combine

extension Notification.Name {
    static let savedLocationsDidChange = Notification.Name("PhotoWindow.savedLocationsDidChange")
}

@MainActor
final class AddLocationViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [ShootingLocation] = []
    @Published var name = ""
    @Published var latitudeText = ""
    @Published var longitudeText = ""
    @Published var city = "Brisbane"
    @Published var country = "Australia"
    @Published var locationType: ShootingLocationType = .custom
    @Published var selectedCategories: Set<PhotographyCategory> = Set(ShootingLocationType.custom.defaultSupportedCategories)
    @Published var lightPollutionLevel = 5
    @Published var notes = ""
    @Published private(set) var isLoading = false
    @Published private(set) var didSave = false
    @Published private(set) var selectedMapCoordinate: LocationCoordinate?
    @Published var errorMessage: String?

    private let savedLocationRepository: any SavedLocationRepository
    private let locationSearchService: any LocationSearchServicing
    private let existingLocation: ShootingLocation?

    init(
        savedLocationRepository: any SavedLocationRepository,
        locationSearchService: any LocationSearchServicing,
        existingLocation: ShootingLocation? = nil
    ) {
        self.savedLocationRepository = savedLocationRepository
        self.locationSearchService = locationSearchService
        self.existingLocation = existingLocation

        if let existingLocation {
            apply(existingLocation)
        }
    }

    var isEditing: Bool {
        existingLocation != nil
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Double(latitudeText) != nil &&
            Double(longitudeText) != nil &&
            !selectedCategories.isEmpty
    }

    var mapInitialCoordinate: LocationCoordinate {
        if let latitude = Double(latitudeText),
           let longitude = Double(longitudeText),
           (-90...90).contains(latitude),
           (-180...180).contains(longitude) {
            return LocationCoordinate(latitude: latitude, longitude: longitude)
        }

        return selectedMapCoordinate ?? .brisbane
    }

    func search() async {
        isLoading = true
        defer { isLoading = false }

        do {
            searchResults = try await locationSearchService.searchLocations(query: searchQuery)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func useCurrentLocation() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let location = try await locationSearchService.getCurrentLocation()
            apply(location)
            errorMessage = nil
        } catch {
            errorMessage = "无法使用当前位置，请手动输入经纬度。"
        }
    }

    func reverseGeocodeManualCoordinate() async {
        guard let latitude = Double(latitudeText), let longitude = Double(longitudeText) else {
            errorMessage = LocationSearchError.invalidCoordinate.localizedDescription
            return
        }

        _ = await resolveCoordinate(
            LocationCoordinate(latitude: latitude, longitude: longitude),
            keepNameIfPresent: true
        )
    }

    func updateMapSelectedCoordinate(_ coordinate: LocationCoordinate) {
        guard (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else { return }
        selectedMapCoordinate = coordinate
        latitudeText = String(format: "%.6f", coordinate.latitude)
        longitudeText = String(format: "%.6f", coordinate.longitude)
        LocationDebugStateStore.recordSelectedCoordinate(coordinate)
    }

    func applyMapSelection(_ coordinate: LocationCoordinate) async -> Bool {
        await resolveCoordinate(coordinate, keepNameIfPresent: false)
    }

    func selectSearchResult(_ location: ShootingLocation) {
        apply(location)
        searchResults = []
    }

    func setLocationType(_ type: ShootingLocationType) {
        locationType = type
        selectedCategories = Set(type.defaultSupportedCategories)
    }

    func toggleCategory(_ category: PhotographyCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func save() async {
        guard let latitude = Double(latitudeText), let longitude = Double(longitudeText) else {
            errorMessage = LocationSearchError.invalidCoordinate.localizedDescription
            return
        }

        guard canSave else {
            errorMessage = "请填写名称、经纬度和适合类别。"
            return
        }

        let now = Date()
        let location = ShootingLocation(
            id: existingLocation?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : city,
            country: country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : country,
            lightPollutionLevel: lightPollutionLevel,
            locationType: locationType,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isFavorite: existingLocation?.isFavorite ?? false,
            supportedCategories: Array(selectedCategories).sorted { $0.displayName < $1.displayName },
            createdAt: existingLocation?.createdAt ?? now,
            updatedAt: now
        )

        isLoading = true
        defer { isLoading = false }

        do {
            if isEditing {
                try await savedLocationRepository.updateLocation(location)
            } else {
                try await savedLocationRepository.saveLocation(location)
            }
            NotificationCenter.default.post(name: .savedLocationsDidChange, object: nil)
            didSave = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveCoordinate(
        _ coordinate: LocationCoordinate,
        keepNameIfPresent: Bool
    ) async -> Bool {
        guard (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else {
            errorMessage = LocationSearchError.invalidCoordinate.localizedDescription
            return false
        }

        updateMapSelectedCoordinate(coordinate)
        isLoading = true
        defer { isLoading = false }

        do {
            let location = try await locationSearchService.reverseGeocode(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            apply(location, keepNameIfPresent: keepNameIfPresent)
            errorMessage = nil
        } catch {
            let location = Self.customLocation(for: coordinate)
            LocationDebugStateStore.recordReverseFallback(location, coordinate: coordinate, error: error)
            apply(location, keepNameIfPresent: keepNameIfPresent)
            errorMessage = "地点 API 暂不可用，已使用自定义坐标。"
        }

        return true
    }

    private func apply(_ location: ShootingLocation, keepNameIfPresent: Bool = false) {
        if !keepNameIfPresent || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = location.name
        }
        latitudeText = String(format: "%.6f", location.latitude)
        longitudeText = String(format: "%.6f", location.longitude)
        city = location.city
        country = location.country
        locationType = location.locationType
        lightPollutionLevel = location.lightPollutionLevel
        notes = location.notes
        selectedCategories = Set(
            location.supportedCategories.isEmpty
                ? location.locationType.defaultSupportedCategories
                : location.supportedCategories
        )
        selectedMapCoordinate = LocationCoordinate(latitude: location.latitude, longitude: location.longitude)
        if let selectedMapCoordinate {
            LocationDebugStateStore.recordSelectedCoordinate(selectedMapCoordinate)
        }
    }

    private static func customLocation(for coordinate: LocationCoordinate) -> ShootingLocation {
        ShootingLocation(
            id: UUID(),
            name: "自定义点位 \(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude))",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            city: "Manual",
            country: "Australia",
            lightPollutionLevel: 5,
            locationType: .custom,
            notes: "地图选点创建的自定义坐标。",
            supportedCategories: ShootingLocationType.custom.defaultSupportedCategories
        )
    }
}
