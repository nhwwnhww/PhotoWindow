import Foundation

struct ShootingWindowScoreResult {
    var score: Int
    var scoreLevel: ShootingWindowScoreLevel
    var reasonSummary: String
    var reasonTags: [String]
    var scoreBreakdown: [ScoreBreakdownItem]
    var notRecommendedReason: String?
    var recommendationResult: RecommendationResult
}

struct ShootingWindowScoringService {
    private let configService: ScoringRuleConfigService

    init(configService: ScoringRuleConfigService = ScoringRuleConfigService()) {
        self.configService = configService
    }

    func scoreAstroWindow(
        weather: WeatherSnapshot,
        location: ShootingLocation,
        timeRange: ClosedRange<Date>
    ) -> Int {
        let cloudScore = inversePercent(weather.cloudCover)
        let rainScore = inversePercent(weather.precipitationProbability)
        let moonScore = inversePercent(weather.moonIllumination)
        let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
        let pollutionScore = clamp(100.0 - Double(location.lightPollutionLevel) * 12.0)

        return configuredScore(
            category: .astro,
            cloudCover: cloudScore,
            precipitation: rainScore,
            visibility: visibilityScore,
            moonIllumination: moonScore,
            lightPollution: pollutionScore
        )
    }

    func scoreAstroWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation,
        timeRange: ClosedRange<Date>
    ) -> Int {
        evaluateAstroWindow(
            weather: weather,
            astronomy: astronomy,
            location: location,
            timeRange: timeRange
        ).score
    }

    func evaluateAstroWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation,
        timeRange: ClosedRange<Date>
    ) -> ShootingWindowScoreResult {
        let cloudScore = inversePercent(weather.cloudCover)
        let rainScore = inversePercent(weather.precipitationProbability)
        let moonScore = inversePercent(astronomy.moonIllumination)
        let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
        let pollutionScore = clamp(100.0 - Double(location.lightPollutionLevel) * 12.0)
        let nightScore = isNightWindow(timeRange) ? 100.0 : 42.0
        let score = configuredScore(
            category: .astro,
            cloudCover: cloudScore,
            precipitation: rainScore,
            visibility: visibilityScore,
            moonIllumination: moonScore,
            lightPollution: pollutionScore,
            goldenHour: nightScore
        )
        let tags = [
            weather.cloudCover <= 25 ? "云量低" : "云量偏高",
            weather.precipitationProbability <= 20 ? "降雨概率低" : "降雨风险",
            astronomy.moonIllumination <= 25 ? "月光影响小" : "月光偏强",
            weather.visibility >= 15 ? "能见度高" : "能见度一般",
            location.lightPollutionLevel <= 3 ? "光污染低" : "光污染偏高",
            isNightWindow(timeRange) ? "夜间窗口" : "非深夜窗口"
        ]
        return makeResult(
            category: .astro,
            score: score,
            reasonSummary: score >= 70
                ? "夜间窗口叠加较低云量、低降雨和较弱月光，适合星空/银河拍摄。"
                : "云量、月光、降雨或光污染条件不够理想，不建议专程拍星空。",
            reasonTags: tags,
            notRecommendedReason: score < 70
                ? "云量 \(Int(weather.cloudCover))%，月亮照明 \(Int(astronomy.moonIllumination))%，降雨概率 \(Int(weather.precipitationProbability))%，会削弱星空可见度。"
                : nil,
            riskNotes: astroRiskNotes(weather: weather, astronomy: astronomy, location: location)
        )
    }

    func scoreLandscapeWindow(weather: WeatherSnapshot, timeRange: ClosedRange<Date>) -> Int {
        let cloudScore: Double
        switch weather.cloudCover {
        case 25...65:
            cloudScore = 90
        case 10..<25, 66...80:
            cloudScore = 72
        default:
            cloudScore = 45
        }

        let timeBonus = overlaps(timeRange, weather.goldenHourStart...weather.goldenHourEnd)
            || overlaps(timeRange, weather.blueHourStart...weather.blueHourEnd)
            ? 100.0
            : 62.0
        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = clamp(100.0 - weather.windSpeed * 4.0)

        return configuredScore(
            category: .landscape,
            cloudCover: cloudScore,
            precipitation: rainScore,
            wind: windScore,
            goldenHour: timeBonus
        )
    }

    func scoreLandscapeWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        timeRange: ClosedRange<Date>
    ) -> Int {
        evaluateLandscapeWindow(weather: weather, astronomy: astronomy, timeRange: timeRange).score
    }

    func evaluateLandscapeWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        timeRange: ClosedRange<Date>
    ) -> ShootingWindowScoreResult {
        let cloudScore = landscapeCloudScore(weather.cloudCover)
        let goldenOverlap = overlaps(timeRange, astronomy.goldenHourStart...astronomy.goldenHourEnd)
        let blueOverlap = overlaps(timeRange, astronomy.blueHourStart...astronomy.blueHourEnd)
        let sunriseOrSunsetWindow = contains(timeRange, astronomy.sunriseTime) || contains(timeRange, astronomy.sunsetTime)
        let lightScore = goldenOverlap ? 100.0 : (blueOverlap || sunriseOrSunsetWindow ? 86.0 : 58.0)
        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = clamp(100.0 - weather.windSpeed * 4.0)
        let score = configuredScore(
            category: .landscape,
            cloudCover: cloudScore,
            precipitation: rainScore,
            wind: windScore,
            goldenHour: lightScore
        )
        let lightTag = goldenOverlap ? "接近黄金时刻" : (blueOverlap ? "接近蓝调时刻" : "日出/日落窗口")
        let tags = [
            lightTag,
            weather.cloudCover >= 25 && weather.cloudCover <= 65 ? "云量适中" : "云量不稳定",
            weather.precipitationProbability <= 20 ? "降雨概率低" : "降雨风险",
            weather.windSpeed <= 22 ? "风速可控" : "风速偏高"
        ]
        return makeResult(
            category: .landscape,
            score: score,
            reasonSummary: score >= 70
                ? "光线窗口明确，云量和降雨条件适合尝试风光拍摄。"
                : "光线或天气条件一般，风光出片概率偏低。",
            reasonTags: tags,
            notRecommendedReason: score < 70
                ? "云量 \(Int(weather.cloudCover))%，降雨概率 \(Int(weather.precipitationProbability))%，风速 \(Int(weather.windSpeed)) km/h，风光窗口不够稳定。"
                : nil,
            riskNotes: commonRiskNotes(weather: weather)
        )
    }

    func scoreAviationWindow(event: ShootingEvent, weather: WeatherSnapshot) -> Int {
        evaluateAviationWindow(event: event, weather: weather).score
    }

    func evaluateAviationWindow(event: ShootingEvent, weather: WeatherSnapshot) -> ShootingWindowScoreResult {
        let importance = clamp(Double(event.importanceScore) + event.importanceLevel.scoreWeight)
        let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = weather.windSpeed > 38 ? 35.0 : clamp(100.0 - weather.windSpeed * 2.2)

        let score = configuredScore(
            category: .aviation,
            precipitation: rainScore,
            wind: windScore,
            visibility: visibilityScore,
            eventImportance: importance,
            confidence: 82
        )
        let tags = [
            event.importanceLevel == .normal ? "普通事件" : event.importanceLevel.badgeText,
            weather.visibility >= 14 ? "能见度好" : "能见度一般",
            weather.precipitationProbability <= 25 ? "降雨概率低" : "降雨风险",
            weather.windSpeed <= 28 ? "风速可控" : "风速偏高"
        ]
        return makeResult(
            category: .aviation,
            score: score,
            reasonSummary: score >= 70
                ? "事件重要程度和能见度较好，适合提前到场关注。"
                : "事件或天气条件一般，建议谨慎安排飞机拍摄。",
            reasonTags: tags,
            notRecommendedReason: score < 70
                ? "能见度 \(Int(weather.visibility)) km，降雨概率 \(Int(weather.precipitationProbability))%，风速 \(Int(weather.windSpeed)) km/h，航空拍摄条件一般。"
                : nil,
            riskNotes: commonRiskNotes(weather: weather)
        )
    }

    func applyEventImportance(baseScore: Int, events: [ShootingEvent]) -> Int {
        let strongestBoost = events.map(\.importanceLevel.scoreWeight).max() ?? 0
        return Int(round(clamp(Double(baseScore) + strongestBoost * 0.45)))
    }

    func scorePortraitOrGraduationWindow(weather: WeatherSnapshot, timeRange: ClosedRange<Date>) -> Int {
        let softLightScore: Double
        if overlaps(timeRange, weather.goldenHourStart...weather.goldenHourEnd) {
            softLightScore = 92
        } else if weather.cloudCover >= 45 && weather.cloudCover <= 85 {
            softLightScore = 86
        } else {
            softLightScore = 58
        }

        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = clamp(100.0 - weather.windSpeed * 4.5)
        let temperatureScore = scoreTemperature(weather.temperature)

        return configuredScore(
            category: .portrait,
            cloudCover: softLightScore,
            precipitation: rainScore,
            wind: windScore,
            goldenHour: softLightScore,
            confidence: temperatureScore
        )
    }

    func scorePortraitOrGraduationWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        timeRange: ClosedRange<Date>
    ) -> Int {
        evaluatePortraitOrGraduationWindow(
            weather: weather,
            astronomy: astronomy,
            timeRange: timeRange,
            category: .portrait
        ).score
    }

    func evaluatePortraitOrGraduationWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        timeRange: ClosedRange<Date>,
        category: PhotographyCategory
    ) -> ShootingWindowScoreResult {
        let goldenOverlap = overlaps(timeRange, astronomy.goldenHourStart...astronomy.goldenHourEnd)
        let cloudySoftLight = weather.cloudCover >= 45 && weather.cloudCover <= 85
        let softLightScore: Double = goldenOverlap ? 94 : (cloudySoftLight ? 88 : 58)
        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = clamp(100.0 - weather.windSpeed * 4.5)
        let temperatureScore = scoreTemperature(weather.temperature)
        let score = configuredScore(
            category: category,
            cloudCover: softLightScore,
            precipitation: rainScore,
            wind: windScore,
            goldenHour: softLightScore,
            confidence: temperatureScore
        )
        let tags = [
            goldenOverlap ? "黄金时刻" : (cloudySoftLight ? "阴天柔光" : "光线一般"),
            weather.precipitationProbability <= 15 ? "无雨" : "降雨风险",
            weather.windSpeed <= 15 ? "风小" : "风速偏高",
            (16...27).contains(weather.temperature) ? "温度舒适" : "温度不理想"
        ]
        return makeResult(
            category: category,
            score: score,
            reasonSummary: score >= 70
                ? "柔光、低风速和低降雨条件适合人像/毕业照拍摄。"
                : "风速、降雨、温度或光线条件一般，不建议安排重要人像拍摄。",
            reasonTags: tags,
            notRecommendedReason: score < 70
                ? "降雨概率 \(Int(weather.precipitationProbability))%，风速 \(Int(weather.windSpeed)) km/h，温度 \(Int(weather.temperature)) C，会影响人像拍摄体验。"
                : nil,
            riskNotes: commonRiskNotes(weather: weather)
        )
    }

    func evaluateWildlifeWindow(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        timeRange: ClosedRange<Date>
    ) -> ShootingWindowScoreResult {
        let sunriseOverlap = overlaps(timeRange, astronomy.sunriseTime...astronomy.goldenHourEnd)
        let sunsetOverlap = overlaps(timeRange, astronomy.goldenHourStart...astronomy.sunsetTime)
        let lightScore: Double = sunriseOverlap || sunsetOverlap ? 92 : 60
        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = clamp(100.0 - weather.windSpeed * 4.0)
        let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
        let score = configuredScore(
            category: .wildlife,
            precipitation: rainScore,
            wind: windScore,
            visibility: visibilityScore,
            goldenHour: lightScore
        )
        let tags = [
            sunriseOverlap ? "清晨活跃期" : (sunsetOverlap ? "傍晚活跃期" : "普通时段"),
            weather.precipitationProbability <= 20 ? "降雨概率低" : "降雨风险",
            weather.windSpeed <= 16 ? "风速适合观察" : "风速偏高",
            weather.visibility >= 14 ? "能见度好" : "能见度一般"
        ]

        return makeResult(
            category: .wildlife,
            score: score,
            reasonSummary: score >= 70
                ? "清晨/傍晚窗口叠加较低降雨和可控风速，适合野生动物观察和拍摄。"
                : "风速、降雨或能见度一般，野生动物出片概率偏低。",
            reasonTags: tags,
            notRecommendedReason: score < 70
                ? "降雨概率 \(Int(weather.precipitationProbability))%，风速 \(Int(weather.windSpeed)) km/h，能见度 \(Int(weather.visibility)) km，观察条件不够稳定。"
                : nil,
            riskNotes: commonRiskNotes(weather: weather)
        )
    }

    func scoreSpecialEventWindow(
        event: SpecialEvent,
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation
    ) -> Int {
        evaluateSpecialEventWindow(
            event: event,
            weather: weather,
            astronomy: astronomy,
            location: location
        ).score
    }

    func evaluateSpecialEventWindow(
        event: SpecialEvent,
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation
    ) -> ShootingWindowScoreResult {
        let categoryScore = categorySpecificSpecialEventScore(
            event: event,
            weather: weather,
            astronomy: astronomy,
            location: location
        )
        let score = configuredScore(
            category: event.category,
            precipitation: inversePercent(weather.precipitationProbability),
            wind: windScore(weather.windSpeed, category: event.category),
            visibility: clamp(weather.visibility / 20.0 * 100.0),
            moonIllumination: event.category == .astro ? inversePercent(astronomy.moonIllumination) : nil,
            lightPollution: event.category == .astro ? clamp(100.0 - Double(location.lightPollutionLevel) * 12.0) : nil,
            goldenHour: Double(categoryScore),
            eventImportance: importanceScore(for: event.importanceLevel),
            confidence: confidenceScore(for: event.confidenceLevel)
        )
        let tags = specialEventReasonTags(
            event: event,
            weather: weather,
            astronomy: astronomy,
            location: location
        )
        let confidenceText = event.confidenceLevel == .low
            ? "可信度偏低，建议临近出发前再复核一次。"
            : "事件可信度足以进入提醒队列。"
        let summary = score >= 70
            ? "\(event.eventReasonTag) 与当前天气/天文条件匹配，适合设置提醒并提前到场。"
            : "\(event.eventReasonTag) 值得留意，但天气或可信度条件一般。"

        return makeResult(
            category: event.category,
            score: score,
            reasonSummary: "\(summary) \(confidenceText)",
            reasonTags: tags,
            notRecommendedReason: score < 70
                ? "云量 \(Int(weather.cloudCover))%，降雨概率 \(Int(weather.precipitationProbability))%，能见度 \(Int(weather.visibility)) km，风速 \(Int(weather.windSpeed)) km/h，当前特殊事件窗口稳定性不足。"
                : nil,
            confidenceLevel: event.confidenceLevel,
            riskNotes: commonRiskNotes(weather: weather)
        )
    }

    private func inversePercent(_ value: Double) -> Double {
        clamp(100.0 - value)
    }

    private func importanceScore(for level: EventImportanceLevel) -> Double {
        switch level {
        case .normal:
            return 58
        case .worthWatching:
            return 74
        case .rare:
            return 90
        case .mustShoot:
            return 98
        }
    }

    private func confidenceScore(for level: SpecialEventConfidenceLevel) -> Double {
        switch level {
        case .low:
            return 48
        case .medium:
            return 76
        case .high:
            return 94
        }
    }

    private func categorySpecificSpecialEventScore(
        event: SpecialEvent,
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation
    ) -> Int {
        let range = event.startTime...event.endTime

        switch event.category {
        case .astro:
            let cloudScore = inversePercent(weather.cloudCover)
            let moonScore = inversePercent(astronomy.moonIllumination)
            let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
            let pollutionScore = clamp(100.0 - Double(location.lightPollutionLevel) * 12.0)
            let nightScore = isNightWindow(range) ? 100.0 : 45.0
            return weightedScore([
                (cloudScore, 0.28),
                (moonScore, 0.24),
                (visibilityScore, 0.17),
                (pollutionScore, 0.18),
                (nightScore, 0.13)
            ])
        case .aviation:
            let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
            let rainScore = inversePercent(weather.precipitationProbability)
            let wind = windScore(weather.windSpeed, category: .aviation)
            let cloudScore = weather.cloudCover <= 70 ? 82.0 : 58.0
            return weightedScore([
                (visibilityScore, 0.40),
                (rainScore, 0.26),
                (wind, 0.22),
                (cloudScore, 0.12)
            ])
        case .landscape, .cityscape:
            let lightScore: Double
            if overlaps(range, astronomy.goldenHourStart...astronomy.goldenHourEnd) {
                lightScore = 96
            } else if overlaps(range, astronomy.blueHourStart...astronomy.blueHourEnd) ||
                contains(range, astronomy.sunriseTime) ||
                contains(range, astronomy.sunsetTime) {
                lightScore = 88
            } else {
                lightScore = 64
            }
            return weightedScore([
                (lightScore, 0.30),
                (landscapeCloudScore(weather.cloudCover), 0.28),
                (inversePercent(weather.precipitationProbability), 0.24),
                (windScore(weather.windSpeed, category: event.category), 0.18)
            ])
        case .portrait, .graduation:
            let softLightScore: Double
            if overlaps(range, astronomy.goldenHourStart...astronomy.goldenHourEnd) {
                softLightScore = 94
            } else if weather.cloudCover >= 45 && weather.cloudCover <= 85 {
                softLightScore = 88
            } else {
                softLightScore = 58
            }
            return weightedScore([
                (softLightScore, 0.34),
                (inversePercent(weather.precipitationProbability), 0.26),
                (windScore(weather.windSpeed, category: event.category), 0.20),
                (scoreTemperature(weather.temperature), 0.20)
            ])
        case .wildlife:
            let activeTime = overlaps(range, astronomy.sunriseTime...astronomy.goldenHourEnd) ||
                overlaps(range, astronomy.goldenHourStart...astronomy.sunsetTime)
            return weightedScore([
                (activeTime ? 92 : 58, 0.30),
                (inversePercent(weather.precipitationProbability), 0.25),
                (windScore(weather.windSpeed, category: .wildlife), 0.20),
                (clamp(weather.visibility / 20.0 * 100.0), 0.25)
            ])
        }
    }

    private func specialEventReasonTags(
        event: SpecialEvent,
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation
    ) -> [String] {
        var tags = [
            event.eventReasonTag,
            event.importanceLevel.badgeText,
            "可信度\(event.confidenceLevel.displayName)"
        ]

        switch event.category {
        case .astro:
            tags.append(contentsOf: [
                weather.cloudCover <= 25 ? "云量低" : "云量需复核",
                astronomy.moonIllumination <= 25 ? "月光影响小" : "月光偏强",
                location.lightPollutionLevel <= 3 ? "暗空地点" : "光污染偏高"
            ])
        case .aviation:
            tags.append(contentsOf: [
                weather.visibility >= 14 ? "能见度好" : "能见度一般",
                weather.windSpeed <= 28 ? "风速可控" : "风速偏高"
            ])
        case .landscape, .cityscape:
            tags.append(contentsOf: [
                weather.cloudCover >= 25 && weather.cloudCover <= 70 ? "云层结构可用" : "云量不稳定",
                weather.precipitationProbability <= 20 ? "降雨概率低" : "降雨风险"
            ])
        case .portrait, .graduation:
            tags.append(contentsOf: [
                weather.cloudCover >= 45 && weather.cloudCover <= 85 ? "柔光条件" : "光线需控",
                weather.windSpeed <= 15 ? "风小" : "风速偏高"
            ])
        case .wildlife:
            tags.append(contentsOf: [
                weather.windSpeed <= 16 ? "风速适合观察" : "风速偏高",
                weather.visibility >= 14 ? "能见度好" : "能见度一般"
            ])
        }

        return tags.removingDuplicateStrings()
    }

    private func windScore(_ windSpeed: Double, category: PhotographyCategory) -> Double {
        switch category {
        case .aviation:
            return windSpeed > 38 ? 35 : clamp(100.0 - windSpeed * 2.2)
        case .portrait, .graduation:
            return clamp(100.0 - windSpeed * 4.5)
        case .wildlife:
            return clamp(100.0 - windSpeed * 4.0)
        case .astro, .landscape, .cityscape:
            return clamp(100.0 - windSpeed * 4.0)
        }
    }

    private func landscapeCloudScore(_ cloudCover: Double) -> Double {
        switch cloudCover {
        case 25...65:
            return 90
        case 10..<25, 66...80:
            return 72
        default:
            return 45
        }
    }

    private func scoreTemperature(_ temperature: Double) -> Double {
        switch temperature {
        case 16...27:
            return 95
        case 10..<16, 28...32:
            return 72
        default:
            return 42
        }
    }

    private func weightedScore(_ parts: [(value: Double, weight: Double)]) -> Int {
        let total = parts.reduce(0.0) { $0 + clamp($1.value) * $1.weight }
        return Int(round(clamp(total)))
    }

    private func configuredScore(
        category: PhotographyCategory,
        cloudCover: Double? = nil,
        precipitation: Double? = nil,
        wind: Double? = nil,
        visibility: Double? = nil,
        moonIllumination: Double? = nil,
        lightPollution: Double? = nil,
        goldenHour: Double? = nil,
        eventImportance: Double? = nil,
        confidence: Double? = nil
    ) -> Int {
        let config = configService.config(for: category)
        let parts: [(Double?, Double)] = [
            (cloudCover, config.cloudCoverWeight),
            (precipitation, config.precipitationWeight),
            (wind, config.windWeight),
            (visibility, config.visibilityWeight),
            (moonIllumination, config.moonIlluminationWeight),
            (lightPollution, config.lightPollutionWeight),
            (goldenHour, config.goldenHourWeight),
            (eventImportance, config.eventImportanceWeight),
            (confidence, config.confidenceWeight)
        ]
        let active = parts.compactMap { value, weight -> (value: Double, weight: Double)? in
            guard let value, weight > 0 else { return nil }
            return (value, weight)
        }
        let totalWeight = active.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }
        let score = active.reduce(0.0) { $0 + clamp($1.value) * ($1.weight / totalWeight) }
        return Int(round(clamp(score)))
    }

    private func overlaps(_ lhs: ClosedRange<Date>, _ rhs: ClosedRange<Date>) -> Bool {
        lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
    }

    private func contains(_ range: ClosedRange<Date>, _ date: Date) -> Bool {
        range.lowerBound <= date && date <= range.upperBound
    }

    private func isNightWindow(_ range: ClosedRange<Date>) -> Bool {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: range.lowerBound)
        let endHour = calendar.component(.hour, from: range.upperBound)
        return startHour >= 20 || startHour <= 4 || endHour >= 20 || endHour <= 5
    }

    private func makeResult(
        category: PhotographyCategory,
        score: Int,
        reasonSummary: String,
        reasonTags: [String],
        notRecommendedReason: String?,
        confidenceLevel: SpecialEventConfidenceLevel? = nil,
        riskNotes: [String] = []
    ) -> ShootingWindowScoreResult {
        let penaltyTags = reasonTags.filter(isPenaltyTag)
        let positiveTags = reasonTags.filter { !isPenaltyTag($0) }
        let displayReasonTags = positiveTags.isEmpty ? Array(reasonTags.prefix(3)) : positiveTags
        let penaltySummary = notRecommendedReason ?? (penaltyTags.isEmpty ? nil : penaltyTags.joined(separator: "、"))
        let result = RecommendationResult(
            score: score,
            scoreLevel: .from(score: score),
            confidenceLevel: confidenceLevel ?? self.confidenceLevel(for: score),
            reasonTags: displayReasonTags,
            penaltyTags: penaltyTags,
            reasonSummary: reasonSummary,
            penaltySummary: penaltySummary,
            recommendationText: defaultRecommendationText(category: category, score: score),
            arrivalSuggestionMinutes: arrivalSuggestionMinutes(for: category, score: score),
            riskNotes: riskNotes.isEmpty ? derivedRiskNotes(penaltySummary: penaltySummary) : riskNotes,
            suitableFor: RecommendationResult.defaultSuitableFor(category: category),
            shouldNotifyByDefault: score >= 75
        )

        return ShootingWindowScoreResult(
            score: score,
            scoreLevel: .from(score: score),
            reasonSummary: reasonSummary,
            reasonTags: displayReasonTags,
            scoreBreakdown: makeScoreBreakdown(for: category, score: score),
            notRecommendedReason: notRecommendedReason,
            recommendationResult: result
        )
    }

    private func isPenaltyTag(_ tag: String) -> Bool {
        ["偏高", "风险", "一般", "不稳定", "偏强", "不理想", "需复核", "不够"].contains {
            tag.contains($0)
        }
    }

    private func confidenceLevel(for score: Int) -> SpecialEventConfidenceLevel {
        score >= 80 ? .high : (score >= 65 ? .medium : .low)
    }

    private func arrivalSuggestionMinutes(for category: PhotographyCategory, score: Int) -> Int {
        let base = category.defaultArrivalLeadMinutes
        return score >= 85 ? base + 15 : base
    }

    private func defaultRecommendationText(category: PhotographyCategory, score: Int) -> String {
        let prefix = score >= 85 ? "强烈推荐。" : (score >= 70 ? "推荐。" : "谨慎安排。")
        switch category {
        case .astro:
            return "\(prefix)优先确认月光、云量和暗空方向，提前完成构图与对焦。"
        case .aviation:
            return "\(prefix)提前确认跑道方向、航班动态和公开拍摄点。"
        case .landscape:
            return "\(prefix)提前踩点，围绕前景和光线变化准备备选构图。"
        case .graduation:
            return "\(prefix)适合安排校园毕业照，注意风速和雨备方案。"
        case .portrait:
            return "\(prefix)适合轻量外拍，优先使用柔光和避风位置。"
        case .cityscape:
            return "\(prefix)适合城市天际线、蓝调时刻和灯光层次。"
        case .wildlife:
            return "\(prefix)保持距离和安静，优先长焦和清晨活动窗口。"
        }
    }

    private func derivedRiskNotes(penaltySummary: String?) -> [String] {
        penaltySummary.map { [$0] } ?? []
    }

    private func commonRiskNotes(weather: WeatherSnapshot) -> [String] {
        var notes: [String] = []
        if weather.precipitationProbability > 35 {
            notes.append("降雨概率偏高，建议准备雨备方案。")
        }
        if weather.windSpeed > 28 {
            notes.append("风速偏高，三脚架、长焦或人像发型可能受影响。")
        }
        if weather.visibility < 10 {
            notes.append("能见度一般，远景和航空拍摄清晰度可能下降。")
        }
        return notes
    }

    private func astroRiskNotes(
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        location: ShootingLocation
    ) -> [String] {
        var notes = commonRiskNotes(weather: weather)
        if astronomy.moonIllumination > 45 {
            notes.append("月亮照明偏高，银河对比度可能下降。")
        }
        if location.lightPollutionLevel > 4 {
            notes.append("光污染偏高，建议寻找更暗方向或改期。")
        }
        return notes
    }

    private func makeScoreBreakdown(for category: PhotographyCategory, score: Int) -> [ScoreBreakdownItem] {
        let specs: [(String, Int)]
        switch category {
        case .astro:
            specs = [("天气", 35), ("月相", 20), ("光污染", 20), ("能见度", 15), ("地点条件", 10)]
        case .aviation:
            specs = [("事件重要度", 35), ("能见度", 20), ("降雨", 15), ("风速", 15), ("到场准备", 15)]
        case .landscape, .cityscape:
            specs = [("光线", 30), ("云量", 25), ("降雨", 20), ("风速", 15), ("地点条件", 10)]
        case .portrait, .graduation:
            specs = [("光线", 30), ("降雨", 20), ("风速", 20), ("温度", 20), ("地点条件", 10)]
        case .wildlife:
            specs = [("光线", 25), ("风速", 20), ("降雨", 20), ("能见度", 20), ("地点条件", 15)]
        }
        return scaledScoreBreakdown(specs: specs, totalScore: score)
    }

    private func scaledScoreBreakdown(
        specs: [(title: String, maxScore: Int)],
        totalScore: Int
    ) -> [ScoreBreakdownItem] {
        var scores = specs.map { Int(floor(Double($0.maxScore) * Double(totalScore) / 100.0)) }
        var remaining = totalScore - scores.reduce(0, +)
        var index = 0

        while remaining > 0 && index < scores.count * 2 {
            let targetIndex = index % scores.count
            if scores[targetIndex] < specs[targetIndex].maxScore {
                scores[targetIndex] += 1
                remaining -= 1
            }
            index += 1
        }

        return zip(specs, scores).map { spec, score in
            ScoreBreakdownItem(title: spec.title, score: score, maxScore: spec.maxScore)
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(100.0, max(0.0, value))
    }
}

private extension Array where Element == String {
    func removingDuplicateStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
