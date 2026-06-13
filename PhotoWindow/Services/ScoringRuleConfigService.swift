import Foundation

struct ScoringRuleConfig: Codable, Hashable {
    var cloudCoverWeight: Double
    var precipitationWeight: Double
    var windWeight: Double
    var visibilityWeight: Double
    var moonIlluminationWeight: Double
    var lightPollutionWeight: Double
    var goldenHourWeight: Double
    var eventImportanceWeight: Double
    var confidenceWeight: Double

    static let fallback = ScoringRuleConfig(
        cloudCoverWeight: 0.20,
        precipitationWeight: 0.18,
        windWeight: 0.12,
        visibilityWeight: 0.12,
        moonIlluminationWeight: 0.10,
        lightPollutionWeight: 0.08,
        goldenHourWeight: 0.12,
        eventImportanceWeight: 0.05,
        confidenceWeight: 0.03
    )
}

struct ScoringRulesFile: Codable {
    var categories: [String: ScoringRuleConfig]
}

final class ScoringRuleConfigService {
    private let bundle: Bundle
    private let fileName: String
    private let fileExtension: String
    private var cachedRules: [PhotographyCategory: ScoringRuleConfig]?
    private(set) var lastLoadSucceeded = false
    private(set) var lastLoadError: String?

    init(
        bundle: Bundle = .main,
        fileName: String = "scoring_rules",
        fileExtension: String = "json"
    ) {
        self.bundle = bundle
        self.fileName = fileName
        self.fileExtension = fileExtension
    }

    func loadConfig() -> [PhotographyCategory: ScoringRuleConfig] {
        if let cachedRules {
            return cachedRules
        }

        guard let url = bundle.url(forResource: fileName, withExtension: fileExtension) ?? fallbackURL() else {
            lastLoadSucceeded = false
            lastLoadError = "scoring_rules.json not found; using defaults."
            let defaults = defaultRules()
            cachedRules = defaults
            return defaults
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ScoringRulesFile.self, from: data)
            var rules = defaultRules()
            decoded.categories.forEach { key, value in
                if let category = PhotographyCategory(rawValue: key) {
                    rules[category] = value.normalized()
                }
            }
            lastLoadSucceeded = true
            lastLoadError = nil
            cachedRules = rules
            return rules
        } catch {
            lastLoadSucceeded = false
            lastLoadError = error.localizedDescription
            let defaults = defaultRules()
            cachedRules = defaults
            return defaults
        }
    }

    func config(for category: PhotographyCategory) -> ScoringRuleConfig {
        loadConfig()[category] ?? .fallback
    }

    private func defaultRules() -> [PhotographyCategory: ScoringRuleConfig] {
        Dictionary(uniqueKeysWithValues: PhotographyCategory.allCases.map { ($0, defaultConfig(for: $0)) })
    }

    private func defaultConfig(for category: PhotographyCategory) -> ScoringRuleConfig {
        switch category {
        case .astro:
            return ScoringRuleConfig(cloudCoverWeight: 0.24, precipitationWeight: 0.14, windWeight: 0.05, visibilityWeight: 0.13, moonIlluminationWeight: 0.22, lightPollutionWeight: 0.17, goldenHourWeight: 0.00, eventImportanceWeight: 0.03, confidenceWeight: 0.02)
        case .aviation:
            return ScoringRuleConfig(cloudCoverWeight: 0.05, precipitationWeight: 0.18, windWeight: 0.12, visibilityWeight: 0.24, moonIlluminationWeight: 0.00, lightPollutionWeight: 0.00, goldenHourWeight: 0.00, eventImportanceWeight: 0.29, confidenceWeight: 0.12)
        case .landscape, .cityscape:
            return ScoringRuleConfig(cloudCoverWeight: 0.26, precipitationWeight: 0.20, windWeight: 0.12, visibilityWeight: 0.06, moonIlluminationWeight: 0.00, lightPollutionWeight: 0.00, goldenHourWeight: 0.30, eventImportanceWeight: 0.04, confidenceWeight: 0.02)
        case .graduation, .portrait:
            return ScoringRuleConfig(cloudCoverWeight: 0.24, precipitationWeight: 0.24, windWeight: 0.20, visibilityWeight: 0.00, moonIlluminationWeight: 0.00, lightPollutionWeight: 0.00, goldenHourWeight: 0.22, eventImportanceWeight: 0.06, confidenceWeight: 0.04)
        case .wildlife:
            return ScoringRuleConfig(cloudCoverWeight: 0.05, precipitationWeight: 0.22, windWeight: 0.20, visibilityWeight: 0.22, moonIlluminationWeight: 0.00, lightPollutionWeight: 0.00, goldenHourWeight: 0.24, eventImportanceWeight: 0.04, confidenceWeight: 0.03)
        }
    }

    private func fallbackURL() -> URL? {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            currentDirectory
                .appendingPathComponent("PhotoWindow")
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(fileName).\(fileExtension)"),
            currentDirectory
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(fileName).\(fileExtension)")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

private extension ScoringRuleConfig {
    func normalized() -> ScoringRuleConfig {
        let weights = [
            cloudCoverWeight,
            precipitationWeight,
            windWeight,
            visibilityWeight,
            moonIlluminationWeight,
            lightPollutionWeight,
            goldenHourWeight,
            eventImportanceWeight,
            confidenceWeight
        ]
        guard weights.allSatisfy({ $0 >= 0 }), weights.reduce(0, +) > 0 else {
            return .fallback
        }
        return self
    }
}
