import Foundation

struct MockDataService {
    private let scoringService = ShootingWindowScoringService()
    private let calendar = Calendar.current

    func makeSeedData() -> MockSeedData {
        let locations = makeLocations()
        let weather = makeWeatherSnapshots()
        let events = makeEvents(locations: locations)
        let windows = makeWindows(locations: locations, weather: weather, events: events)
        let user = makeUser(homeLocation: locations[1])
        let alertRules = makeAlertRules(user: user, locations: locations)

        return MockSeedData(
            user: user,
            locations: locations,
            events: events,
            windows: windows,
            alertRules: alertRules
        )
    }

    private func makeUser(homeLocation: ShootingLocation) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: "F65DFE38-7E3E-4D90-8400-2359806408A1") ?? UUID(),
            displayName: "Wei",
            avatarURL: nil,
            preferredCategories: [.astro, .aviation, .landscape, .graduation],
            homeLocation: homeLocation,
            cameraTags: ["Sony A7", "70-200mm", "Tripod"],
            skillTags: ["银河", "飞机", "校园人像"],
            notificationPreference: NotificationPreference(
                isEnabled: true,
                defaultRemindBeforeMinutes: 180,
                quietHoursStart: 23,
                quietHoursEnd: 7
            )
        )
    }

    private func makeLocations() -> [ShootingLocation] {
        [
            ShootingLocation(
                id: UUID(uuidString: "7E020280-4CA3-4A46-927F-B64E0D01B111") ?? UUID(),
                name: "Brisbane Airport",
                latitude: -27.3842,
                longitude: 153.1175,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 7,
                locationType: .airport,
                notes: "适合追踪特殊机型和特殊涂装，注意遵守机场周边拍摄规则。"
            ),
            ShootingLocation(
                id: UUID(uuidString: "63FC10D3-0CE1-4A10-B2DD-20DE7E363F51") ?? UUID(),
                name: "UQ St Lucia Campus",
                latitude: -27.4975,
                longitude: 153.0137,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 6,
                locationType: .campus,
                notes: "草坪、湖边和砂岩建筑适合毕业照与自然光人像。"
            ),
            ShootingLocation(
                id: UUID(uuidString: "214E2E45-1D34-427C-8CF4-9327169C7F51") ?? UUID(),
                name: "Lake Moogerah",
                latitude: -28.0295,
                longitude: 152.5436,
                city: "Scenic Rim",
                country: "Australia",
                lightPollutionLevel: 2,
                locationType: .darkSky,
                notes: "远离市区光污染，适合银河、星轨和日出风光。"
            )
        ]
    }

    private func makeWeatherSnapshots() -> [String: WeatherSnapshot] {
        [
            "airport": weather(
                dayOffset: 1,
                temperature: 24,
                cloudCover: 38,
                precipitation: 12,
                windSpeed: 18,
                visibility: 18,
                humidity: 62,
                moonPhase: "Waxing Crescent",
                moonIllumination: 18
            ),
            "campus": weather(
                dayOffset: 2,
                temperature: 23,
                cloudCover: 58,
                precipitation: 8,
                windSpeed: 10,
                visibility: 16,
                humidity: 66,
                moonPhase: "First Quarter",
                moonIllumination: 48
            ),
            "darkSky": weather(
                dayOffset: 3,
                temperature: 17,
                cloudCover: 14,
                precipitation: 5,
                windSpeed: 9,
                visibility: 21,
                humidity: 52,
                moonPhase: "New Moon",
                moonIllumination: 6
            ),
            "landscape": weather(
                dayOffset: 1,
                temperature: 20,
                cloudCover: 46,
                precipitation: 10,
                windSpeed: 12,
                visibility: 19,
                humidity: 60,
                moonPhase: "Waxing Crescent",
                moonIllumination: 22
            )
        ]
    }

    private func makeEvents(locations: [ShootingLocation]) -> [ShootingEvent] {
        let airport = locations[0]
        let campus = locations[1]
        let darkSky = locations[2]

        return [
            ShootingEvent(
                id: UUID(uuidString: "E4DD8E45-AD5B-4DEB-BFF5-78750E978D11") ?? UUID(),
                title: "QF Retro Roo 特殊涂装预计抵达",
                category: .aviation,
                eventType: .specialAircraft,
                location: airport,
                startTime: date(dayOffset: 1, hour: 17, minute: 20),
                endTime: date(dayOffset: 1, hour: 18, minute: 0),
                importanceScore: 88,
                description: "Mock 航空事件：特殊涂装机预计傍晚抵达，光线方向适合侧面记录。",
                tags: ["Qantas", "Special Livery", "Arrival"],
                sourceType: .mock
            ),
            ShootingEvent(
                id: UUID(uuidString: "934E0D53-A186-42DA-8950-9250D7D8A21C") ?? UUID(),
                title: "Lake Moogerah 新月银河窗口",
                category: .astro,
                eventType: .milkyWayWindow,
                location: darkSky,
                startTime: date(dayOffset: 3, hour: 21, minute: 30),
                endTime: date(dayOffset: 4, hour: 1, minute: 15),
                importanceScore: 92,
                description: "低月光、低云量和低光污染叠加，适合拍摄银河核心。",
                tags: ["Milky Way", "New Moon", "Dark Sky"],
                sourceType: .mock
            ),
            ShootingEvent(
                id: UUID(uuidString: "88002A8A-9C1D-4E2F-B30D-8CE878395211") ?? UUID(),
                title: "UQ 毕业季拍摄高峰",
                category: .graduation,
                eventType: .graduationSeason,
                location: campus,
                startTime: date(dayOffset: 2, hour: 15, minute: 30),
                endTime: date(dayOffset: 2, hour: 18, minute: 20),
                importanceScore: 78,
                description: "校园人像与毕业照需求高，下午柔光和低风速比较友好。",
                tags: ["Graduation", "Portrait", "Campus"],
                sourceType: .mock
            )
        ]
    }

    private func makeWindows(
        locations: [ShootingLocation],
        weather: [String: WeatherSnapshot],
        events: [ShootingEvent]
    ) -> [ShootingWindow] {
        let airport = locations[0]
        let campus = locations[1]
        let darkSky = locations[2]
        let airportWeather = weather["airport"]!
        let campusWeather = weather["campus"]!
        let darkSkyWeather = weather["darkSky"]!
        let landscapeWeather = weather["landscape"]!
        let aviationEvent = events[0]
        let astroEvent = events[1]
        let graduationEvent = events[2]

        let astroStart = date(dayOffset: 3, hour: 21, minute: 30)
        let astroEnd = date(dayOffset: 4, hour: 1, minute: 15)
        let astroScore = scoringService.scoreAstroWindow(
            weather: darkSkyWeather,
            location: darkSky,
            timeRange: astroStart...astroEnd
        )

        let sunsetStart = date(dayOffset: 1, hour: 16, minute: 45)
        let sunsetEnd = date(dayOffset: 1, hour: 18, minute: 35)
        let sunsetScore = scoringService.scoreLandscapeWindow(
            weather: landscapeWeather,
            timeRange: sunsetStart...sunsetEnd
        )

        let aviationStart = date(dayOffset: 1, hour: 16, minute: 45)
        let aviationEnd = date(dayOffset: 1, hour: 18, minute: 10)
        let aviationScore = scoringService.scoreAviationWindow(event: aviationEvent, weather: airportWeather)

        let graduationStart = date(dayOffset: 2, hour: 15, minute: 45)
        let graduationEnd = date(dayOffset: 2, hour: 18, minute: 10)
        let graduationScore = scoringService.scorePortraitOrGraduationWindow(
            weather: campusWeather,
            timeRange: graduationStart...graduationEnd
        )

        let cityStart = date(dayOffset: 1, hour: 5, minute: 10)
        let cityEnd = date(dayOffset: 1, hour: 6, minute: 25)
        let cityScore = scoringService.scoreLandscapeWindow(weather: landscapeWeather, timeRange: cityStart...cityEnd)

        let portraitStart = date(dayOffset: 2, hour: 16, minute: 40)
        let portraitEnd = date(dayOffset: 2, hour: 18, minute: 0)
        let portraitScore = scoringService.scorePortraitOrGraduationWindow(
            weather: campusWeather,
            timeRange: portraitStart...portraitEnd
        )

        return [
            ShootingWindow(
                id: UUID(uuidString: "119A8C86-B531-4D7B-8E1B-25E0B50AB5C2") ?? UUID(),
                category: .astro,
                location: darkSky,
                startTime: astroStart,
                endTime: astroEnd,
                windowTitle: "Lake Moogerah 银河核心窗口",
                score: astroScore,
                scoreLevel: .from(score: astroScore),
                reasonSummary: "云量较低，月光影响小，光污染低，适合银河拍摄。",
                weatherSnapshot: darkSkyWeather,
                eventRefs: [astroEvent],
                recommendationText: "建议提前到达完成构图，预留 20 分钟适应黑暗环境。",
                isBookmarked: true,
                alertEnabled: true
            ),
            ShootingWindow(
                id: UUID(uuidString: "98CF1F2A-A2D2-4FA1-88B1-ECE3B98642A1") ?? UUID(),
                category: .landscape,
                location: darkSky,
                startTime: sunsetStart,
                endTime: sunsetEnd,
                windowTitle: "湖区日落与晚霞窗口",
                score: sunsetScore,
                scoreLevel: .from(score: sunsetScore),
                reasonSummary: "日落前后有适量高云，降雨概率低，值得尝试晚霞。",
                weatherSnapshot: landscapeWeather,
                eventRefs: [],
                recommendationText: "优先选择开阔湖岸机位，保留前景层次。",
                isBookmarked: false,
                alertEnabled: false
            ),
            ShootingWindow(
                id: UUID(uuidString: "29733B3A-1A4B-4F26-AC9D-A73D87664F9B") ?? UUID(),
                category: .aviation,
                location: airport,
                startTime: aviationStart,
                endTime: aviationEnd,
                windowTitle: "特殊涂装航班抵达提醒",
                score: aviationScore,
                scoreLevel: .from(score: aviationScore),
                reasonSummary: "特殊涂装稀缺度高，能见度好，预计傍晚抵达。",
                weatherSnapshot: airportWeather,
                eventRefs: [aviationEvent],
                recommendationText: "建议提前 45 分钟到达公开安全拍摄点，留意航班变更。",
                isBookmarked: true,
                alertEnabled: true
            ),
            ShootingWindow(
                id: UUID(uuidString: "EE6AF2D6-E06B-442E-BC9D-E23BC893E192") ?? UUID(),
                category: .graduation,
                location: campus,
                startTime: graduationStart,
                endTime: graduationEnd,
                windowTitle: "UQ 毕业照柔光窗口",
                score: graduationScore,
                scoreLevel: .from(score: graduationScore),
                reasonSummary: "云量适中、风速较低，下午柔光适合校园人像。",
                weatherSnapshot: campusWeather,
                eventRefs: [graduationEvent],
                recommendationText: "砂岩建筑、湖边和草坪都适合安排 20 分钟一组的拍摄节奏。",
                isBookmarked: false,
                alertEnabled: true
            ),
            ShootingWindow(
                id: UUID(uuidString: "82A6D223-C2D8-4B5F-9082-D22FDE5786E7") ?? UUID(),
                category: .cityscape,
                location: airport,
                startTime: cityStart,
                endTime: cityEnd,
                windowTitle: "布里斯班清晨蓝调城市线",
                score: cityScore,
                scoreLevel: .from(score: cityScore),
                reasonSummary: "清晨蓝调时刻叠加较好能见度，适合城市天际线。",
                weatherSnapshot: landscapeWeather,
                eventRefs: [],
                recommendationText: "建议使用三脚架，保留天空渐变和城市灯光细节。",
                isBookmarked: false,
                alertEnabled: false
            ),
            ShootingWindow(
                id: UUID(uuidString: "F102D0F5-B1C9-48AE-886A-4229E16D9C16") ?? UUID(),
                category: .portrait,
                location: campus,
                startTime: portraitStart,
                endTime: portraitEnd,
                windowTitle: "校园自然光人像窗口",
                score: portraitScore,
                scoreLevel: .from(score: portraitScore),
                reasonSummary: "黄金时刻接近、风速低，适合自然光人像。",
                weatherSnapshot: campusWeather,
                eventRefs: [],
                recommendationText: "逆光和侧逆光都可尝试，注意保留肤色和背景层次。",
                isBookmarked: false,
                alertEnabled: false
            )
        ]
    }

    private func makeAlertRules(user: UserProfile, locations: [ShootingLocation]) -> [AlertRule] {
        [
            AlertRule(
                id: UUID(uuidString: "C03BE834-C573-43D0-9633-48C87E650111") ?? UUID(),
                userId: user.id,
                category: .astro,
                location: locations[2],
                eventType: .milkyWayWindow,
                minScore: 75,
                remindBeforeMinutes: 180,
                isEnabled: true,
                keywords: ["银河", "新月", "低云量"]
            ),
            AlertRule(
                id: UUID(uuidString: "B6D60437-7F52-4417-AE2E-771888081F72") ?? UUID(),
                userId: user.id,
                category: .aviation,
                location: locations[0],
                eventType: .specialAircraft,
                minScore: 65,
                remindBeforeMinutes: 45,
                isEnabled: true,
                keywords: ["special livery", "Qantas", "widebody"]
            ),
            AlertRule(
                id: UUID(uuidString: "7B596C56-DBF1-4601-80EC-3800D27B74E2") ?? UUID(),
                userId: user.id,
                category: .graduation,
                location: locations[1],
                eventType: .graduationSeason,
                minScore: 70,
                remindBeforeMinutes: 120,
                isEnabled: true,
                keywords: ["毕业照", "柔光", "校园"]
            )
        ]
    }

    private func weather(
        dayOffset: Int,
        temperature: Double,
        cloudCover: Double,
        precipitation: Double,
        windSpeed: Double,
        visibility: Double,
        humidity: Double,
        moonPhase: String,
        moonIllumination: Double
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            temperature: temperature,
            cloudCover: cloudCover,
            precipitationProbability: precipitation,
            windSpeed: windSpeed,
            visibility: visibility,
            humidity: humidity,
            moonPhase: moonPhase,
            moonIllumination: moonIllumination,
            sunriseTime: date(dayOffset: dayOffset, hour: 5, minute: 52),
            sunsetTime: date(dayOffset: dayOffset, hour: 17, minute: 22),
            goldenHourStart: date(dayOffset: dayOffset, hour: 16, minute: 35),
            goldenHourEnd: date(dayOffset: dayOffset, hour: 17, minute: 35),
            blueHourStart: date(dayOffset: dayOffset, hour: 17, minute: 45),
            blueHourEnd: date(dayOffset: dayOffset, hour: 18, minute: 16)
        )
    }

    private func date(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let startOfToday = calendar.startOfDay(for: Date())
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) ?? startOfToday
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay) ?? targetDay
    }
}

struct MockSeedData {
    var user: UserProfile
    var locations: [ShootingLocation]
    var events: [ShootingEvent]
    var windows: [ShootingWindow]
    var alertRules: [AlertRule]
}
