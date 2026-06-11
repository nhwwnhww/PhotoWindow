import Foundation

enum PhotographyCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case astro
    case aviation
    case landscape
    case wildlife
    case portrait
    case graduation
    case cityscape

    var id: String { rawValue }
    var key: String { rawValue }

    var displayName: String {
        switch self {
        case .astro:
            return "星空 / 银河"
        case .aviation:
            return "飞机摄影"
        case .landscape:
            return "风光"
        case .wildlife:
            return "野生动物"
        case .portrait:
            return "人像"
        case .graduation:
            return "毕业照"
        case .cityscape:
            return "城市风光"
        }
    }

    var iconName: String {
        switch self {
        case .astro:
            return "sparkles"
        case .aviation:
            return "airplane"
        case .landscape:
            return "mountain.2"
        case .wildlife:
            return "pawprint"
        case .portrait:
            return "person.crop.rectangle"
        case .graduation:
            return "graduationcap"
        case .cityscape:
            return "building.2"
        }
    }
}
