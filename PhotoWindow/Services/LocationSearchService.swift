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

struct RemoteLocationSearchService: LocationSearchServicing {
    private let configProvider: () -> APIConfig
    private let session: URLSession
    private let fallbackService: any LocationSearchServicing

    init(
        configProvider: @escaping () -> APIConfig = { APIConfig.current },
        session: URLSession = .shared,
        fallbackService: any LocationSearchServicing = LocationSearchService()
    ) {
        self.configProvider = configProvider
        self.session = session
        self.fallbackService = fallbackService
    }

    func searchLocations(query: String) async throws -> [ShootingLocation] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { throw LocationSearchError.emptyQuery }

        do {
            return try await fetchRemoteSearch(query: normalizedQuery)
        } catch {
            return try await fallbackService.searchLocations(query: query)
        }
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> ShootingLocation {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw LocationSearchError.invalidCoordinate
        }

        do {
            return try await fetchRemoteReverse(latitude: latitude, longitude: longitude)
        } catch {
            return try await fallbackService.reverseGeocode(latitude: latitude, longitude: longitude)
        }
    }

    func getCurrentLocation() async throws -> ShootingLocation {
        try await fallbackService.getCurrentLocation()
    }

    private func fetchRemoteSearch(query: String) async throws -> [ShootingLocation] {
        let response: APIResponse<RemoteLocationCollectionPayload> = try await networkClient().get(
            APIRequest(
                path: "api/v1/locations/search",
                queryItems: [
                    URLQueryItem(name: "q", value: query)
                ],
                timeout: 6
            )
        )

        guard let payload = response.data else {
            throw APIError.noData
        }

        let locations = payload.locations.compactMap { try? $0.makeLocation() }
        if locations.isEmpty, !payload.locations.isEmpty {
            throw APIError.validationFailed(["location search returned no valid locations"])
        }
        return locations
    }

    private func fetchRemoteReverse(latitude: Double, longitude: Double) async throws -> ShootingLocation {
        let response: APIResponse<RemoteLocationSinglePayload> = try await networkClient().get(
            APIRequest(
                path: "api/v1/locations/reverse",
                queryItems: [
                    URLQueryItem(name: "lat", value: String(latitude)),
                    URLQueryItem(name: "lon", value: String(longitude))
                ],
                timeout: 6
            )
        )

        guard let payload = response.data,
              let location = try payload.location?.makeLocation() else {
            throw APIError.noData
        }

        return location
    }

    private func networkClient() -> NetworkClient {
        NetworkClient(baseURL: configProvider().baseURL, session: session, timeout: 6)
    }
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
                name: "UQ St Lucia Campus",
                latitude: -27.4975,
                longitude: 153.0137,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 7,
                locationType: .campus,
                notes: "适合毕业季、人像和校园建筑拍摄。",
                supportedCategories: [.graduation, .portrait, .cityscape]
            ),
            ShootingLocation(
                id: UUID(),
                name: "South Bank Parklands",
                latitude: -27.4785,
                longitude: 153.0225,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 7,
                locationType: .urban,
                notes: "适合河岸城市风光、火烧云和蓝调时段。",
                supportedCategories: [.cityscape, .landscape, .portrait]
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

private struct RemoteLocationCollectionPayload: Decodable {
    var locations: [RemoteLocationDTO]

    init(from decoder: Decoder) throws {
        if let locations = try? decoder.singleValueContainer().decode([RemoteLocationDTO].self) {
            self.locations = locations
            return
        }

        let container = try decoder.container(keyedBy: RemoteLocationCollectionCodingKey.self)
        for key in RemoteLocationCollectionCodingKey.collectionKeys {
            if let locations = try? container.decode([RemoteLocationDTO].self, forKey: key) {
                self.locations = locations
                return
            }
        }

        for key in RemoteLocationCollectionCodingKey.singleLocationKeys {
            if let location = try? container.decode(RemoteLocationDTO.self, forKey: key) {
                self.locations = [location]
                return
            }
        }

        self.locations = []
    }
}

private struct RemoteLocationSinglePayload: Decodable {
    var location: RemoteLocationDTO?

    init(from decoder: Decoder) throws {
        if let location = try? decoder.singleValueContainer().decode(RemoteLocationDTO.self) {
            self.location = location
            return
        }

        if let collection = try? RemoteLocationCollectionPayload(from: decoder) {
            self.location = collection.locations.first
            return
        }

        self.location = nil
    }
}

private struct RemoteLocationCollectionCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    static let collectionKeys = [
        RemoteLocationCollectionCodingKey(stringValue: "locations")!,
        RemoteLocationCollectionCodingKey(stringValue: "results")!,
        RemoteLocationCollectionCodingKey(stringValue: "items")!,
        RemoteLocationCollectionCodingKey(stringValue: "data")!
    ]

    static let singleLocationKeys = [
        RemoteLocationCollectionCodingKey(stringValue: "location")!,
        RemoteLocationCollectionCodingKey(stringValue: "result")!
    ]
}

private struct RemoteLocationDTO: Decodable {
    var id: UUID?
    var name: String
    var latitude: Double
    var longitude: Double
    var city: String?
    var country: String?
    var locationType: ShootingLocationType?
    var lightPollutionLevel: Int?
    var notes: String?
    var supportedCategories: [PhotographyCategory]?
    var createdAt: Date?
    var updatedAt: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RemoteLocationCodingKey.self)
        guard let name = container.trimmedString(for: ["name", "displayName", "title"]) else {
            throw APIError.validationFailed(["location name is missing"])
        }
        guard let latitude = container.double(for: ["latitude", "lat"]) else {
            throw APIError.validationFailed(["location latitude is missing"])
        }
        guard let longitude = container.double(for: ["longitude", "lon", "lng"]) else {
            throw APIError.validationFailed(["location longitude is missing"])
        }

        self.id = container.uuid(for: ["id"])
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.city = container.trimmedString(for: ["city", "suburb", "town", "locality"])
        self.country = container.trimmedString(for: ["country", "countryName"]) ?? "Australia"
        self.locationType = container.locationType(for: ["locationType", "suggestedLocationType", "type"])
        self.lightPollutionLevel = container.int(for: ["lightPollutionLevel"])
        self.notes = container.trimmedString(for: ["notes", "description"])
        self.supportedCategories = container.categories(for: ["supportedCategories", "categories"])
        self.createdAt = container.date(for: ["createdAt"])
        self.updatedAt = container.date(for: ["updatedAt", "lastUpdated"])
    }

    func makeLocation() throws -> ShootingLocation {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw LocationSearchError.invalidCoordinate
        }

        let resolvedType = locationType ?? Self.inferLocationType(name: name, city: city)
        let now = Date()
        return ShootingLocation(
            id: id ?? UUID(),
            name: name,
            latitude: latitude,
            longitude: longitude,
            city: city?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? city! : "Unknown",
            country: country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? country! : "Unknown",
            lightPollutionLevel: lightPollutionLevel ?? Self.defaultLightPollutionLevel(for: resolvedType),
            locationType: resolvedType,
            notes: notes ?? "由 PhotoWindow server 地点搜索返回。",
            supportedCategories: supportedCategories ?? resolvedType.defaultSupportedCategories,
            createdAt: createdAt ?? now,
            updatedAt: updatedAt ?? now
        )
    }

    private static func inferLocationType(name: String, city: String?) -> ShootingLocationType {
        let searchable = [name, city ?? ""].joined(separator: " ").lowercased()
        if searchable.contains("airport") || searchable.contains("runway") {
            return .airport
        }
        if searchable.contains("uq") || searchable.contains("university") || searchable.contains("campus") {
            return .campus
        }
        if searchable.contains("lookout") || searchable.contains("mount") || searchable.contains("park") {
            return .scenic
        }
        if searchable.contains("beach") || searchable.contains("wetland") {
            return .wildlifeArea
        }
        return .urban
    }

    private static func defaultLightPollutionLevel(for type: ShootingLocationType) -> Int {
        switch type {
        case .darkSky:
            return 2
        case .wildlifeArea, .scenic:
            return 5
        case .airport, .campus, .urban, .portraitSpot:
            return 7
        case .custom:
            return 5
        }
    }
}

private struct RemoteLocationCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == RemoteLocationCodingKey {
    func trimmedString(for keys: [String]) -> String? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let value = try? decode(String.self, forKey: codingKey) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    func double(for keys: [String]) -> Double? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let value = try? decode(Double.self, forKey: codingKey) {
                return value
            }
            if let value = try? decode(String.self, forKey: codingKey),
               let doubleValue = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return doubleValue
            }
        }
        return nil
    }

    func int(for keys: [String]) -> Int? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let value = try? decode(Int.self, forKey: codingKey) {
                return value
            }
            if let value = try? decode(String.self, forKey: codingKey),
               let intValue = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return intValue
            }
        }
        return nil
    }

    func uuid(for keys: [String]) -> UUID? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let uuid = try? decode(UUID.self, forKey: codingKey) {
                return uuid
            }
            if let value = try? decode(String.self, forKey: codingKey),
               let uuid = UUID(uuidString: value) {
                return uuid
            }
        }
        return nil
    }

    func locationType(for keys: [String]) -> ShootingLocationType? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let locationType = try? decode(ShootingLocationType.self, forKey: codingKey) {
                return locationType
            }
            if let value = try? decode(String.self, forKey: codingKey) {
                return ShootingLocationType(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return nil
    }

    func categories(for keys: [String]) -> [PhotographyCategory]? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let categories = try? decode([PhotographyCategory].self, forKey: codingKey) {
                return categories
            }
            if let values = try? decode([String].self, forKey: codingKey) {
                let categories = values.compactMap { PhotographyCategory(rawValue: $0) }
                if !categories.isEmpty {
                    return categories
                }
            }
        }
        return nil
    }

    func date(for keys: [String]) -> Date? {
        for key in keys {
            guard let codingKey = RemoteLocationCodingKey(stringValue: key) else { continue }
            if let date = try? decode(Date.self, forKey: codingKey) {
                return date
            }
        }
        return nil
    }
}
