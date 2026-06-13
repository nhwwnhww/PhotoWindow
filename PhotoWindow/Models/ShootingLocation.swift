import Foundation

enum ShootingLocationType: String, CaseIterable, Identifiable, Codable, Hashable {
    case airport
    case darkSky
    case campus
    case scenic
    case urban
    case wildlifeArea
    case portraitSpot
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .airport:
            return "机场"
        case .darkSky:
            return "暗空地点"
        case .campus:
            return "校园"
        case .scenic:
            return "风景区"
        case .urban:
            return "城市"
        case .wildlifeArea:
            return "野生动物区域"
        case .portraitSpot:
            return "人像点位"
        case .custom:
            return "自定义"
        }
    }

    var iconName: String {
        switch self {
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
        case .portraitSpot:
            return "person.crop.rectangle"
        case .custom:
            return "mappin"
        }
    }

    var defaultSupportedCategories: [PhotographyCategory] {
        switch self {
        case .airport:
            return [.aviation]
        case .darkSky:
            return [.astro, .landscape]
        case .campus:
            return [.graduation, .portrait]
        case .scenic:
            return [.landscape]
        case .urban:
            return [.cityscape, .landscape]
        case .wildlifeArea:
            return [.wildlife]
        case .portraitSpot:
            return [.portrait, .graduation]
        case .custom:
            return [.landscape, .portrait]
        }
    }
}

struct ShootingLocation: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var city: String
    var country: String
    var lightPollutionLevel: Int
    var locationType: ShootingLocationType
    var notes: String
    var isFavorite: Bool
    var supportedCategories: [PhotographyCategory]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        city: String,
        country: String,
        lightPollutionLevel: Int,
        locationType: ShootingLocationType,
        notes: String,
        isFavorite: Bool = false,
        supportedCategories: [PhotographyCategory]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.country = country
        self.lightPollutionLevel = min(max(lightPollutionLevel, 1), 9)
        self.locationType = locationType
        self.notes = notes
        self.isFavorite = isFavorite
        self.supportedCategories = supportedCategories ?? locationType.defaultSupportedCategories
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case city
        case country
        case lightPollutionLevel
        case locationType
        case notes
        case isFavorite
        case supportedCategories
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedLocationType = try container.decode(ShootingLocationType.self, forKey: .locationType)
        let decodedCreatedAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        let decodedUpdatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? decodedCreatedAt

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude),
            city: try container.decode(String.self, forKey: .city),
            country: try container.decode(String.self, forKey: .country),
            lightPollutionLevel: try container.decode(Int.self, forKey: .lightPollutionLevel),
            locationType: decodedLocationType,
            notes: try container.decode(String.self, forKey: .notes),
            isFavorite: (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false,
            supportedCategories: (try? container.decode([PhotographyCategory].self, forKey: .supportedCategories))
                ?? decodedLocationType.defaultSupportedCategories,
            createdAt: decodedCreatedAt,
            updatedAt: decodedUpdatedAt
        )
    }
}
