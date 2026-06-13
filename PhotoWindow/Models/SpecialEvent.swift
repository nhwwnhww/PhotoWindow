import Foundation

enum SpecialEventConfidenceLevel: String, CaseIterable, Identifiable, Codable, Hashable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        }
    }

    var scoreWeight: Double {
        switch self {
        case .low:
            return -10
        case .medium:
            return 0
        case .high:
            return 8
        }
    }

    var rank: Int {
        switch self {
        case .low:
            return 0
        case .medium:
            return 1
        case .high:
            return 2
        }
    }
}

enum SpecialEventSourceType: String, CaseIterable, Identifiable, Codable, Hashable {
    case systemGenerated
    case curatedJSON
    case weatherDerived
    case astronomyCalendar
    case curatedCalendar
    case aviationAPI
    case userSubmitted
    case mock

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = SpecialEventSourceType(rawValue: rawValue) ?? .mock
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .systemGenerated:
            return "系统预测"
        case .curatedJSON:
            return "人工精选"
        case .weatherDerived:
            return "天气推导"
        case .astronomyCalendar:
            return "天文日历"
        case .curatedCalendar:
            return "精选日历"
        case .aviationAPI:
            return "航空数据"
        case .userSubmitted:
            return "用户提交"
        case .mock:
            return "内置示例"
        }
    }

    var shootingEventSourceType: ShootingEventSourceType {
        switch self {
        case .weatherDerived:
            return .weatherAPI
        case .astronomyCalendar:
            return .astronomyAPI
        case .curatedCalendar:
            return .mock
        case .aviationAPI:
            return .aviationAPI
        case .userSubmitted:
            return .userGenerated
        case .systemGenerated, .curatedJSON, .mock:
            return .mock
        }
    }
}

struct SpecialEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: PhotographyCategory
    var eventType: ShootingEventType
    var locationId: UUID
    var locationName: String
    var latitude: Double
    var longitude: Double
    var startTime: Date
    var endTime: Date
    var importanceLevel: EventImportanceLevel
    var confidenceLevel: SpecialEventConfidenceLevel
    var description: String
    var tags: [String]
    var sourceType: SpecialEventSourceType
    var sourceName: String
    var sourceURL: String?
    var shareURL: String?
    var lastUpdated: Date
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case eventType
        case locationId
        case locationName
        case latitude
        case longitude
        case startTime
        case endTime
        case importanceLevel
        case confidenceLevel
        case description
        case tags
        case sourceType
        case sourceName
        case sourceURL
        case shareURL
        case lastUpdated
        case createdAt
    }

    init(
        id: UUID,
        title: String,
        category: PhotographyCategory,
        eventType: ShootingEventType,
        locationId: UUID,
        locationName: String,
        latitude: Double,
        longitude: Double,
        startTime: Date,
        endTime: Date,
        importanceLevel: EventImportanceLevel,
        confidenceLevel: SpecialEventConfidenceLevel,
        description: String,
        tags: [String],
        sourceType: SpecialEventSourceType,
        sourceName: String,
        sourceURL: String?,
        shareURL: String? = nil,
        lastUpdated: Date,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.eventType = eventType
        self.locationId = locationId
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.startTime = startTime
        self.endTime = endTime
        self.importanceLevel = importanceLevel
        self.confidenceLevel = confidenceLevel
        self.description = description
        self.tags = tags
        self.sourceType = sourceType
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.shareURL = shareURL
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(PhotographyCategory.self, forKey: .category)
        eventType = try container.decode(ShootingEventType.self, forKey: .eventType)
        locationId = try container.decode(UUID.self, forKey: .locationId)
        locationName = try container.decode(String.self, forKey: .locationName)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        importanceLevel = try container.decode(EventImportanceLevel.self, forKey: .importanceLevel)
        confidenceLevel = try container.decode(SpecialEventConfidenceLevel.self, forKey: .confidenceLevel)
        description = try container.decode(String.self, forKey: .description)
        tags = try container.decode([String].self, forKey: .tags)
        sourceType = try container.decode(SpecialEventSourceType.self, forKey: .sourceType)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        shareURL = try container.decodeIfPresent(String.self, forKey: .shareURL)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(locationId, forKey: .locationId)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(importanceLevel, forKey: .importanceLevel)
        try container.encode(confidenceLevel, forKey: .confidenceLevel)
        try container.encode(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(sourceName, forKey: .sourceName)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(shareURL, forKey: .shareURL)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(createdAt, forKey: .createdAt)
    }

    var isFuture: Bool {
        endTime >= Date()
    }

    var displaySource: String {
        sourceName.isEmpty ? sourceType.displayName : "\(sourceType.displayName) · \(sourceName)"
    }

    var eventReasonTag: String {
        let searchable = ([title, description] + tags).joined(separator: " ").lowercased()

        if searchable.contains("a380") {
            return "A380"
        }
        if searchable.contains("special livery") || searchable.contains("特殊涂装") || searchable.contains("retro") {
            return "特殊涂装"
        }
        if eventType == .meteorShower || searchable.contains("meteor") || searchable.contains("流星雨") {
            return "流星雨"
        }
        if eventType == .milkyWayWindow || searchable.contains("milky way") || searchable.contains("银河") {
            return "银河"
        }
        if eventType == .graduationSeason || searchable.contains("graduation") || searchable.contains("毕业") {
            return "毕业季"
        }
        if searchable.contains("fire sunset") || searchable.contains("火烧云") {
            return "火烧云可能"
        }
        if eventType == .lowCloud || searchable.contains("fog") || searchable.contains("低雾") {
            return "清晨低雾"
        }
        if eventType == .blueHour || searchable.contains("blue hour") || searchable.contains("蓝调") {
            return "蓝调时刻"
        }

        return importanceLevel.badgeText
    }

    func resolvedLocation(knownLocations: [ShootingLocation]) -> ShootingLocation {
        if let existing = knownLocations.first(where: { $0.id == locationId }) {
            return existing
        }

        return ShootingLocation(
            id: locationId,
            name: locationName,
            latitude: latitude,
            longitude: longitude,
            city: inferredCity,
            country: "Australia",
            lightPollutionLevel: inferredLightPollutionLevel,
            locationType: inferredLocationType,
            notes: "由特殊事件数据源生成的拍摄地点。",
            isFavorite: false,
            supportedCategories: [category],
            createdAt: createdAt,
            updatedAt: lastUpdated
        )
    }

    func shootingEvent(knownLocations: [ShootingLocation]) -> ShootingEvent {
        let confidenceAdjustedScore = baseImportanceScore + confidenceLevel.scoreWeight
        return ShootingEvent(
            id: id,
            title: title,
            category: category,
            eventType: eventType,
            location: resolvedLocation(knownLocations: knownLocations),
            startTime: startTime,
            endTime: endTime,
            importanceScore: Int(round(min(100, max(0, confidenceAdjustedScore)))),
            importanceLevel: importanceLevel,
            description: "\(description) 数据可信度：\(confidenceLevel.displayName)。来源：\(displaySource)。",
            tags: ([eventReasonTag] + tags).removingDuplicateStrings(),
            sourceType: sourceType.shootingEventSourceType
        )
    }

    private var baseImportanceScore: Double {
        switch importanceLevel {
        case .normal:
            return 58
        case .worthWatching:
            return 72
        case .rare:
            return 88
        case .mustShoot:
            return 96
        }
    }

    private var inferredLocationType: ShootingLocationType {
        switch category {
        case .aviation:
            return .airport
        case .astro:
            return .darkSky
        case .graduation:
            return .campus
        case .portrait:
            return .portraitSpot
        case .cityscape:
            return .urban
        case .landscape:
            return locationName.lowercased().contains("lake") ? .darkSky : .urban
        case .wildlife:
            return .wildlifeArea
        }
    }

    private var inferredLightPollutionLevel: Int {
        switch inferredLocationType {
        case .darkSky:
            return 2
        case .airport, .urban, .campus:
            return 7
        case .scenic, .portraitSpot, .custom:
            return 5
        case .wildlifeArea:
            return 4
        }
    }

    private var inferredCity: String {
        if locationName.lowercased().contains("moogerah") {
            return "Scenic Rim"
        }
        return "Brisbane"
    }
}

private extension Array where Element == String {
    func removingDuplicateStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
