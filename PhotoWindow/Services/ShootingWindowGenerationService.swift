import Foundation

struct ShootingWindowGenerationService {
    private let scoringService: ShootingWindowScoringService
    private let calendar: Calendar

    init(
        scoringService: ShootingWindowScoringService = ShootingWindowScoringService(),
        calendar: Calendar = .current
    ) {
        self.scoringService = scoringService
        self.calendar = calendar
    }

    func generateWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        astronomySnapshots: [AstronomySnapshot],
        category: PhotographyCategory,
        events: [ShootingEvent] = [],
        specialEvents: [SpecialEvent] = []
    ) -> [ShootingWindow] {
        guard !weatherSnapshots.isEmpty else { return [] }
        let matchingSpecialEvents = specialEventsForGeneration(
            specialEvents,
            category: category,
            location: location
        )
        let specialEventRefs = matchingSpecialEvents.map {
            $0.shootingEvent(knownLocations: [location])
        }
        let allEvents = uniqueEvents(events + specialEventRefs)

        let regularWindows: [ShootingWindow]
        switch category {
        case .astro:
            regularWindows = generateAstroWindows(
                location: location,
                weatherSnapshots: weatherSnapshots,
                astronomySnapshots: astronomySnapshots,
                events: allEvents
            )
        case .landscape, .cityscape:
            regularWindows = generateLandscapeWindows(
                location: location,
                weatherSnapshots: weatherSnapshots,
                astronomySnapshots: astronomySnapshots,
                category: category,
                events: allEvents
            )
        case .graduation, .portrait:
            regularWindows = generatePortraitWindows(
                location: location,
                weatherSnapshots: weatherSnapshots,
                astronomySnapshots: astronomySnapshots,
                category: category,
                events: allEvents
            )
        case .aviation:
            regularWindows = generateAviationWindows(
                location: location,
                weatherSnapshots: weatherSnapshots,
                events: allEvents
            )
        case .wildlife:
            regularWindows = generateWildlifeWindows(
                location: location,
                weatherSnapshots: weatherSnapshots,
                astronomySnapshots: astronomySnapshots,
                events: allEvents
            )
        }

        let directSpecialEventWindows = generateSpecialEventWindows(
            location: location,
            weatherSnapshots: weatherSnapshots,
            astronomySnapshots: astronomySnapshots,
            category: category,
            specialEvents: matchingSpecialEvents
        )

        return deduplicatedWindows(regularWindows + directSpecialEventWindows)
    }

    func categories(for location: ShootingLocation) -> [PhotographyCategory] {
        let supportedCategories = location.supportedCategories.isEmpty
            ? location.locationType.defaultSupportedCategories
            : location.supportedCategories
        return supportedCategories.removingDuplicates()
    }

    private func generateAstroWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        astronomySnapshots: [AstronomySnapshot],
        events: [ShootingEvent]
    ) -> [ShootingWindow] {
        guard location.locationType == .darkSky ||
            location.locationType == .custom ||
            location.lightPollutionLevel <= 3 else {
            return []
        }

        return astronomySnapshots.compactMap { astronomy in
            guard let startTime = time(on: astronomy.date, hour: 22, minute: 0),
                  let endTime = calendar.date(byAdding: .hour, value: 4, to: startTime),
                  let weather = nearestWeather(to: astronomy.date, in: weatherSnapshots)
            else { return nil }

            let windowEvents = matchingEvents(events, category: .astro, location: location, range: startTime...endTime)
            let result = scoringService.evaluateAstroWindow(
                weather: weather,
                astronomy: astronomy,
                location: location,
                timeRange: startTime...endTime
            )
            let boostedScore = scoringService.applyEventImportance(baseScore: result.score, events: windowEvents)
            let finalResult = resultWithUpdatedScore(result, score: boostedScore)
            let title = windowEvents.first?.title ?? "\(location.name) 星空/银河窗口"

            return makeWindow(
                category: .astro,
                location: location,
                startTime: startTime,
                endTime: endTime,
                title: title,
                result: finalResult,
                weather: weatherWithAstronomy(weather, astronomy: astronomy),
                eventRefs: windowEvents,
                recommendationText: boostedScore >= 70
                    ? "建议提前到场完成构图、对焦和设备检查，优先选择低光污染方向。"
                    : "今晚不建议专程跑远郊，可关注后续低云量和低月光窗口。"
            )
        }
    }

    private func generateLandscapeWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        astronomySnapshots: [AstronomySnapshot],
        category: PhotographyCategory,
        events: [ShootingEvent]
    ) -> [ShootingWindow] {
        guard location.locationType == .darkSky ||
            location.locationType == .scenic ||
            location.locationType == .urban ||
            location.locationType == .portraitSpot ||
            location.locationType == .custom else {
            return []
        }

        return astronomySnapshots.flatMap { astronomy -> [ShootingWindow] in
            guard let weather = nearestWeather(to: astronomy.date, in: weatherSnapshots) else { return [] }

            let sunriseStart = calendar.date(byAdding: .minute, value: -40, to: astronomy.sunriseTime) ?? astronomy.sunriseTime
            let sunriseEnd = calendar.date(byAdding: .minute, value: 40, to: astronomy.sunriseTime) ?? astronomy.sunriseTime
            let sunriseRange = sunriseStart...sunriseEnd
            let sunsetRange = astronomy.goldenHourStart...astronomy.blueHourEnd

            return [
                makeLandscapeWindow(
                    location: location,
                    category: category,
                    weather: weather,
                    astronomy: astronomy,
                    range: sunriseRange,
                    title: "\(location.name) 日出风光窗口",
                    events: events
                ),
                makeLandscapeWindow(
                    location: location,
                    category: category,
                    weather: weather,
                    astronomy: astronomy,
                    range: sunsetRange,
                    title: "\(location.name) 日落黄金时刻窗口",
                    events: events
                )
            ].compactMap { $0 }
        }
    }

    private func makeLandscapeWindow(
        location: ShootingLocation,
        category: PhotographyCategory,
        weather: WeatherSnapshot,
        astronomy: AstronomySnapshot,
        range: ClosedRange<Date>,
        title: String,
        events: [ShootingEvent]
    ) -> ShootingWindow? {
        let windowEvents = matchingEvents(events, category: category, location: location, range: range)
        let result = scoringService.evaluateLandscapeWindow(
            weather: weather,
            astronomy: astronomy,
            timeRange: range
        )
        let boostedScore = scoringService.applyEventImportance(baseScore: result.score, events: windowEvents)
        let finalResult = resultWithUpdatedScore(result, score: boostedScore)
        let windowTitle = windowEvents.first?.title ?? title

        return makeWindow(
            category: category,
            location: location,
            startTime: range.lowerBound,
            endTime: range.upperBound,
            title: windowTitle,
            result: finalResult,
            weather: weatherWithAstronomy(weather, astronomy: astronomy),
            eventRefs: windowEvents,
            recommendationText: boostedScore >= 70
                ? "建议提前踩点，保留前景层次，并根据云量变化快速调整构图。"
                : "风光条件不够稳定，建议优先关注下一次黄金时刻。"
        )
    }

    private func generatePortraitWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        astronomySnapshots: [AstronomySnapshot],
        category: PhotographyCategory,
        events: [ShootingEvent]
    ) -> [ShootingWindow] {
        guard location.locationType == .campus ||
            location.locationType == .urban ||
            location.locationType == .scenic ||
            location.locationType == .portraitSpot ||
            location.locationType == .custom else {
            return []
        }

        return astronomySnapshots.compactMap { astronomy in
            guard let weather = nearestWeather(to: astronomy.date, in: weatherSnapshots) else { return nil }
            let cloudySoftLight = weather.cloudCover >= 45 && weather.cloudCover <= 85
            let startTime = cloudySoftLight
                ? (time(on: astronomy.date, hour: 15, minute: 30) ?? astronomy.goldenHourStart)
                : astronomy.goldenHourStart
            let endTime = astronomy.goldenHourEnd
            let range = startTime...endTime
            let windowEvents = matchingEvents(events, category: category, location: location, range: range)
            let result = scoringService.evaluatePortraitOrGraduationWindow(
                weather: weather,
                astronomy: astronomy,
                timeRange: range,
                category: category
            )
            let boostedScore = scoringService.applyEventImportance(baseScore: result.score, events: windowEvents)
            let finalResult = resultWithUpdatedScore(result, score: boostedScore)
            let title = windowEvents.first?.title ?? "\(location.name) \(category == .graduation ? "毕业照" : "人像")柔光窗口"

            return makeWindow(
                category: category,
                location: location,
                startTime: startTime,
                endTime: endTime,
                title: title,
                result: finalResult,
                weather: weatherWithAstronomy(weather, astronomy: astronomy),
                eventRefs: windowEvents,
                recommendationText: boostedScore >= 70
                    ? "建议提前确认集合点，按光线变化安排正面、侧逆光和环境人像。"
                    : "建议准备雨备方案，或改到风速更低、光线更柔和的时间。"
            )
        }
    }

    private func generateAviationWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        events: [ShootingEvent]
    ) -> [ShootingWindow] {
        guard location.locationType == .airport else { return [] }

        return events
            .filter { $0.category == .aviation && $0.location.id == location.id }
            .compactMap { event in
                guard let weather = nearestWeather(to: event.startTime, in: weatherSnapshots) else { return nil }
                let startTime = calendar.date(byAdding: .minute, value: -45, to: event.startTime) ?? event.startTime
                let endTime = calendar.date(byAdding: .minute, value: 20, to: event.endTime) ?? event.endTime
                let result = scoringService.evaluateAviationWindow(event: event, weather: weather)

                return makeWindow(
                    category: .aviation,
                    location: location,
                    startTime: startTime,
                    endTime: endTime,
                    title: event.title,
                    result: result,
                    weather: weather,
                    eventRefs: [event],
                    recommendationText: "建议提前查看跑道方向和公开拍摄点，留出停车、步行和航班变更缓冲。"
                )
            }
    }

    private func generateWildlifeWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        astronomySnapshots: [AstronomySnapshot],
        events: [ShootingEvent]
    ) -> [ShootingWindow] {
        guard location.locationType == .wildlifeArea || location.locationType == .custom else { return [] }

        return astronomySnapshots.compactMap { astronomy in
            guard let weather = nearestWeather(to: astronomy.date, in: weatherSnapshots) else { return nil }
            let startTime = calendar.date(byAdding: .minute, value: -30, to: astronomy.sunriseTime) ?? astronomy.sunriseTime
            let endTime = calendar.date(byAdding: .minute, value: 75, to: astronomy.sunriseTime) ?? astronomy.sunriseTime
            let range = startTime...endTime
            let windowEvents = matchingEvents(events, category: .wildlife, location: location, range: range)
            let result = scoringService.evaluateWildlifeWindow(
                weather: weather,
                astronomy: astronomy,
                timeRange: range
            )
            let boostedScore = scoringService.applyEventImportance(baseScore: result.score, events: windowEvents)
            let finalResult = resultWithUpdatedScore(result, score: boostedScore)
            let title = windowEvents.first?.title ?? "\(location.name) 清晨野生动物窗口"

            return makeWindow(
                category: .wildlife,
                location: location,
                startTime: startTime,
                endTime: endTime,
                title: title,
                result: finalResult,
                weather: weatherWithAstronomy(weather, astronomy: astronomy),
                eventRefs: windowEvents,
                recommendationText: boostedScore >= 70
                    ? "建议保持距离和安静，优先使用长焦，避免干扰动物活动。"
                    : "观察条件一般，建议改到风速更低、降雨更少的清晨。"
            )
        }
    }

    private func makeWindow(
        category: PhotographyCategory,
        location: ShootingLocation,
        startTime: Date,
        endTime: Date,
        title: String,
        result: ShootingWindowScoreResult,
        weather: WeatherSnapshot,
        eventRefs: [ShootingEvent],
        recommendationText: String
    ) -> ShootingWindow {
        let reasonTags = enrichedReasonTags(result.reasonTags, eventRefs: eventRefs)
        let finalRecommendationText = enrichedRecommendationText(recommendationText, eventRefs: eventRefs)
        var recommendationResult = result.recommendationResult
        recommendationResult.reasonTags = reasonTags
        recommendationResult.recommendationText = finalRecommendationText
        recommendationResult.shouldNotifyByDefault = recommendationResult.shouldNotifyByDefault ||
            eventRefs.contains { $0.importanceLevel == .mustShoot || $0.importanceLevel == .rare }

        return ShootingWindow(
            id: UUID(),
            category: category,
            location: location,
            startTime: startTime,
            endTime: endTime,
            windowTitle: title,
            score: result.score,
            scoreLevel: result.scoreLevel,
            reasonSummary: result.reasonSummary,
            reasonTags: reasonTags,
            scoreBreakdown: result.scoreBreakdown,
            notRecommendedReason: result.notRecommendedReason,
            weatherSnapshot: weather,
            eventRefs: eventRefs,
            recommendationText: finalRecommendationText,
            recommendationResult: recommendationResult,
            isBookmarked: false,
            alertEnabled: false
        )
    }

    private func generateSpecialEventWindows(
        location: ShootingLocation,
        weatherSnapshots: [WeatherSnapshot],
        astronomySnapshots: [AstronomySnapshot],
        category: PhotographyCategory,
        specialEvents: [SpecialEvent]
    ) -> [ShootingWindow] {
        specialEvents
            .filter { $0.category == category }
            .compactMap { event in
                guard let weather = nearestWeather(to: event.startTime, in: weatherSnapshots),
                      let astronomy = nearestAstronomy(to: event.startTime, in: astronomySnapshots) else {
                    return nil
                }

                let resolvedLocation = event.resolvedLocation(knownLocations: [location])
                let result = scoringService.evaluateSpecialEventWindow(
                    event: event,
                    weather: weather,
                    astronomy: astronomy,
                    location: resolvedLocation
                )
                let eventRef = event.shootingEvent(knownLocations: [resolvedLocation])

                return makeWindow(
                    category: event.category,
                    location: resolvedLocation,
                    startTime: event.startTime,
                    endTime: event.endTime,
                    title: event.title,
                    result: result,
                    weather: weatherWithAstronomy(weather, astronomy: astronomy),
                    eventRefs: [eventRef],
                    recommendationText: specialEventRecommendationText(event, score: result.score)
                )
            }
    }

    private func nearestWeather(to date: Date, in snapshots: [WeatherSnapshot]) -> WeatherSnapshot? {
        snapshots.min {
            abs(dayStart(for: $0.sunriseTime).timeIntervalSince(dayStart(for: date))) <
                abs(dayStart(for: $1.sunriseTime).timeIntervalSince(dayStart(for: date)))
        }
    }

    private func nearestAstronomy(to date: Date, in snapshots: [AstronomySnapshot]) -> AstronomySnapshot? {
        snapshots.min {
            abs(dayStart(for: $0.date).timeIntervalSince(dayStart(for: date))) <
                abs(dayStart(for: $1.date).timeIntervalSince(dayStart(for: date)))
        }
    }

    private func matchingEvents(
        _ events: [ShootingEvent],
        category: PhotographyCategory,
        location: ShootingLocation,
        range: ClosedRange<Date>
    ) -> [ShootingEvent] {
        events
            .filter {
                $0.category == category &&
                $0.location.id == location.id &&
                $0.startTime <= range.upperBound &&
                range.lowerBound <= $0.endTime
            }
            .sorted {
                if $0.importanceLevel.scoreWeight == $1.importanceLevel.scoreWeight {
                    return $0.startTime < $1.startTime
                }
                return $0.importanceLevel.scoreWeight > $1.importanceLevel.scoreWeight
            }
    }

    private func specialEventsForGeneration(
        _ specialEvents: [SpecialEvent],
        category: PhotographyCategory,
        location: ShootingLocation
    ) -> [SpecialEvent] {
        specialEvents
            .filter {
                $0.category == category &&
                ($0.locationId == location.id || $0.locationName == location.name)
            }
            .sorted {
                if $0.importanceLevel.scoreWeight == $1.importanceLevel.scoreWeight {
                    return $0.startTime < $1.startTime
                }
                return $0.importanceLevel.scoreWeight > $1.importanceLevel.scoreWeight
            }
    }

    private func deduplicatedWindows(_ windows: [ShootingWindow]) -> [ShootingWindow] {
        var results: [ShootingWindow] = []

        for window in windows.sorted(by: { $0.score > $1.score }) {
            if let eventId = window.primaryEvent?.id,
               let existingIndex = results.firstIndex(where: { existing in
                   existing.eventRefs.contains { $0.id == eventId }
               }) {
                if window.score > results[existingIndex].score {
                    results[existingIndex] = window
                }
            } else {
                results.append(window)
            }
        }

        return results.sorted {
            if $0.score == $1.score {
                return $0.startTime < $1.startTime
            }
            return $0.score > $1.score
        }
    }

    private func uniqueEvents(_ events: [ShootingEvent]) -> [ShootingEvent] {
        var seen = Set<UUID>()
        return events.filter { seen.insert($0.id).inserted }
    }

    private func enrichedReasonTags(_ tags: [String], eventRefs: [ShootingEvent]) -> [String] {
        (eventReasonTags(from: eventRefs) + tags).removingDuplicates()
    }

    private func enrichedRecommendationText(_ baseText: String, eventRefs: [ShootingEvent]) -> String {
        guard let event = eventRefs.first else {
            return baseText
        }

        let eventValue: String
        switch event.importanceLevel {
        case .normal:
            eventValue = "该事件适合顺手纳入拍摄计划。"
        case .worthWatching:
            eventValue = "该事件值得关注，条件合适时建议预留到场时间。"
        case .rare:
            eventValue = "该事件属于稀有窗口，建议提前踩点并开启提醒。"
        case .mustShoot:
            eventValue = "该事件属于必拍窗口，建议提前完成路线、构图和设备准备。"
        }

        return "\(eventValue) \(event.description) \(baseText)"
    }

    private func specialEventRecommendationText(_ event: SpecialEvent, score: Int) -> String {
        let leadText = event.importanceLevel == .mustShoot || event.importanceLevel == .rare
            ? "这是 \(event.importanceLevel.displayName) 级别的 \(event.eventReasonTag)，建议开启提醒并提前到场。"
            : "这是 \(event.eventReasonTag) 相关窗口，适合纳入今日拍摄计划。"
        let confidenceText = event.confidenceLevel == .low
            ? "当前可信度偏低，出发前需要再次核对来源。"
            : "当前可信度为\(event.confidenceLevel.displayName)，可作为提醒依据。"

        return "\(leadText) \(event.description) \(confidenceText) 综合评分 \(score)/100。"
    }

    private func eventReasonTags(from events: [ShootingEvent]) -> [String] {
        events.flatMap { event in
            [eventReasonTag(for: event), event.importanceLevel.badgeText] + event.tags
        }
        .removingDuplicates()
        .prefix(6)
        .map { $0 }
    }

    private func eventReasonTag(for event: ShootingEvent) -> String {
        let searchable = ([event.title, event.description] + event.tags)
            .joined(separator: " ")
            .lowercased()

        if searchable.contains("a380") {
            return "A380"
        }
        if searchable.contains("special livery") || searchable.contains("特殊涂装") || searchable.contains("retro") {
            return "特殊涂装"
        }
        if event.eventType == .meteorShower || searchable.contains("meteor") || searchable.contains("流星雨") {
            return "流星雨"
        }
        if event.eventType == .milkyWayWindow || searchable.contains("milky way") || searchable.contains("银河") {
            return "银河"
        }
        if event.eventType == .graduationSeason || searchable.contains("graduation") || searchable.contains("毕业") {
            return "毕业季"
        }
        if searchable.contains("fire sunset") || searchable.contains("火烧云") {
            return "火烧云可能"
        }
        if event.eventType == .lowCloud || searchable.contains("fog") || searchable.contains("低雾") {
            return "清晨低雾"
        }
        if event.eventType == .blueHour || searchable.contains("blue hour") || searchable.contains("蓝调") {
            return "蓝调时刻"
        }

        return event.importanceLevel.badgeText
    }

    private func weatherWithAstronomy(
        _ weather: WeatherSnapshot,
        astronomy: AstronomySnapshot
    ) -> WeatherSnapshot {
        var merged = weather
        merged.moonPhase = astronomy.moonPhase
        merged.moonIllumination = astronomy.moonIllumination
        merged.sunriseTime = astronomy.sunriseTime
        merged.sunsetTime = astronomy.sunsetTime
        merged.goldenHourStart = astronomy.goldenHourStart
        merged.goldenHourEnd = astronomy.goldenHourEnd
        merged.blueHourStart = astronomy.blueHourStart
        merged.blueHourEnd = astronomy.blueHourEnd
        return merged
    }

    private func resultWithUpdatedScore(
        _ result: ShootingWindowScoreResult,
        score: Int
    ) -> ShootingWindowScoreResult {
        let scoreLevel = ShootingWindowScoreLevel.from(score: score)
        var recommendationResult = result.recommendationResult
        recommendationResult.score = score
        recommendationResult.scoreLevel = scoreLevel
        recommendationResult.penaltySummary = score < 70 ? recommendationResult.penaltySummary : nil
        recommendationResult.shouldNotifyByDefault = recommendationResult.shouldNotifyByDefault || score >= 75

        return ShootingWindowScoreResult(
            score: score,
            scoreLevel: scoreLevel,
            reasonSummary: result.reasonSummary,
            reasonTags: result.reasonTags,
            scoreBreakdown: scaleBreakdown(result.scoreBreakdown, to: score),
            notRecommendedReason: score < 70 ? result.notRecommendedReason : nil,
            recommendationResult: recommendationResult
        )
    }

    private func scaleBreakdown(_ breakdown: [ScoreBreakdownItem], to score: Int) -> [ScoreBreakdownItem] {
        guard !breakdown.isEmpty else { return [] }

        var scores = breakdown.map { Int(floor(Double($0.maxScore) * Double(score) / 100.0)) }
        var remaining = score - scores.reduce(0, +)
        var index = 0

        while remaining > 0 && index < scores.count * 2 {
            let targetIndex = index % scores.count
            if scores[targetIndex] < breakdown[targetIndex].maxScore {
                scores[targetIndex] += 1
                remaining -= 1
            }
            index += 1
        }

        return zip(breakdown, scores).map { item, scaledScore in
            ScoreBreakdownItem(title: item.title, score: scaledScore, maxScore: item.maxScore)
        }
    }

    private func time(on date: Date, hour: Int, minute: Int) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart(for: date))
    }

    private func dayStart(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
