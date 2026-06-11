import Foundation

enum ShootingLocationType: String, CaseIterable, Identifiable, Codable, Hashable {
    case airport
    case darkSky
    case campus
    case scenic
    case urban
    case wildlifeArea

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
}
