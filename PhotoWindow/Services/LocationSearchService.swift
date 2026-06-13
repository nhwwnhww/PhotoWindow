import Foundation

enum LocationSearchError: LocalizedError {
    case emptyQuery
    case invalidCoordinate
    case currentLocationUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "请输入地点关键词。"
        case .invalidCoordinate:
            return "经纬度格式不正确。"
        case .currentLocationUnavailable:
            return "暂时无法读取当前位置，请手动输入经纬度。"
        }
    }
}

protocol LocationSearchServicing {
    func searchLocations(query: String) async throws -> [ShootingLocation]
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> ShootingLocation
    func getCurrentLocation() async throws -> ShootingLocation
}

struct LocationSearchService: LocationSearchServicing {
    private let mockLocations: [ShootingLocation]

    init(mockLocations: [ShootingLocation] = LocationSearchService.defaultMockLocations()) {
        self.mockLocations = mockLocations
    }

    func searchLocations(query: String) async throws -> [ShootingLocation] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { throw LocationSearchError.emptyQuery }

        let matches = mockLocations.filter { location in
            location.name.lowercased().contains(normalizedQuery) ||
                location.city.lowercased().contains(normalizedQuery) ||
                location.locationType.displayName.lowercased().contains(normalizedQuery)
        }

        return matches.isEmpty ? Array(mockLocations.prefix(3)) : matches
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> ShootingLocation {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw LocationSearchError.invalidCoordinate
        }

        return ShootingLocation(
            id: UUID(),
            name: "自定义点位 \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))",
            latitude: latitude,
            longitude: longitude,
            city: "Manual",
            country: "Australia",
            lightPollutionLevel: 5,
            locationType: .custom,
            notes: "手动输入经纬度创建。",
            supportedCategories: ShootingLocationType.custom.defaultSupportedCategories
        )
    }

    func getCurrentLocation() async throws -> ShootingLocation {
        ShootingLocation(
            id: UUID(),
            name: "当前位置附近",
            latitude: -27.4705,
            longitude: 153.0260,
            city: "Brisbane",
            country: "Australia",
            lightPollutionLevel: 6,
            locationType: .urban,
            notes: "MVP mock 当前位置；如果系统定位不可用，可以改用手动经纬度。",
            supportedCategories: ShootingLocationType.urban.defaultSupportedCategories
        )
    }

    private static func defaultMockLocations() -> [ShootingLocation] {
        [
            ShootingLocation(
                id: UUID(),
                name: "Kangaroo Point Cliffs",
                latitude: -27.4765,
                longitude: 153.0352,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 7,
                locationType: .urban,
                notes: "适合城市日落、河岸蓝调和轻量人像。",
                supportedCategories: [.cityscape, .landscape, .portrait]
            ),
            ShootingLocation(
                id: UUID(),
                name: "Mount Coot-tha Lookout",
                latitude: -27.4698,
                longitude: 152.9487,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 6,
                locationType: .scenic,
                notes: "适合城市远景、日出和日落风光。",
                supportedCategories: [.landscape, .cityscape]
            ),
            ShootingLocation(
                id: UUID(),
                name: "Roma Street Parkland",
                latitude: -27.4626,
                longitude: 153.0180,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 7,
                locationType: .portraitSpot,
                notes: "适合自然光人像和毕业照小组拍摄。",
                supportedCategories: [.portrait, .graduation]
            ),
            ShootingLocation(
                id: UUID(),
                name: "Nudgee Beach",
                latitude: -27.3438,
                longitude: 153.1017,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 5,
                locationType: .wildlifeArea,
                notes: "适合鸟类、清晨湿地和低干扰观察。",
                supportedCategories: [.wildlife, .landscape]
            )
        ]
    }
}
