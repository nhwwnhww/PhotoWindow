import Foundation

enum PhotographyCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case astro
    case aviation
    case landscape
    case wildlife
    case portrait
    case graduation
    case cityscape

    static var mvpCases: [PhotographyCategory] {
        [.astro, .aviation, .landscape, .graduation]
    }

    var id: String { rawValue }
    var key: String { rawValue }

    var defaultArrivalLeadMinutes: Int {
        switch self {
        case .astro:
            return 90
        case .aviation:
            return 45
        case .landscape, .cityscape:
            return 45
        case .portrait, .graduation:
            return 30
        case .wildlife:
            return 45
        }
    }

    var shootingChecklist: [String] {
        switch self {
        case .astro:
            return ["三脚架", "广角镜头", "头灯", "快门线", "保暖衣物", "备用电池"]
        case .aviation:
            return ["长焦镜头", "查好跑道方向", "带水", "防晒", "关注风向", "预留停车时间"]
        case .graduation:
            return ["反光板", "补光灯", "学士服", "发夹/小道具", "雨备方案", "提前确认集合点"]
        case .landscape:
            return ["三脚架", "渐变镜", "备用电池", "防风外套", "提前踩点", "清洁镜头布"]
        case .portrait:
            return ["反光板", "补光灯", "备用电池", "发夹/小道具", "雨备方案", "提前确认集合点"]
        case .cityscape:
            return ["三脚架", "快门线", "备用电池", "长焦镜头", "清洁镜头布", "确认机位"]
        case .wildlife:
            return ["长焦镜头", "备用电池", "防晒", "驱蚊", "安静快门", "提前观察路线"]
        }
    }

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
