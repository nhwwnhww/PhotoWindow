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
        let userPreference = makeUserPreference(locations: locations)
        let alertRules = makeAlertRules(user: user, locations: locations)
        let watchlistItems = makeWatchlistItems(user: user)

        return MockSeedData(
            user: user,
            userPreference: userPreference,
            locations: locations,
            events: events,
            windows: windows,
            alertRules: alertRules,
            watchlistItems: watchlistItems
        )
    }

    private func makeUserPreference(locations: [ShootingLocation]) -> UserPreference {
        UserPreference(
            id: UUID(uuidString: "E6BC2E56-9DF7-4C2B-8B46-9A61F5CDA111") ?? UUID(),
            selectedCategories: [.astro, .aviation, .landscape, .graduation],
            favoriteLocationIds: [locations[0].id, locations[1].id, locations[2].id],
            defaultMinScore: 75,
            defaultReminderMinutes: 180,
            dailySummaryEnabled: true
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
                shouldMergeNearbyReminders: true,
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
                notes: "适合追踪特殊机型和特殊涂装，注意遵守机场周边拍摄规则。",
                isFavorite: true,
                supportedCategories: [.aviation]
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
                notes: "草坪、湖边和砂岩建筑适合毕业照与自然光人像。",
                isFavorite: true,
                supportedCategories: [.graduation, .portrait]
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
                notes: "远离市区光污染，适合银河、星轨和日出风光。",
                isFavorite: true,
                supportedCategories: [.astro, .landscape]
            ),
            ShootingLocation(
                id: UUID(uuidString: "A0B18D79-9EA7-482C-92DB-31CE3ABF3111") ?? UUID(),
                name: "South Bank",
                latitude: -27.4810,
                longitude: 153.0234,
                city: "Brisbane",
                country: "Australia",
                lightPollutionLevel: 7,
                locationType: .urban,
                notes: "适合城市日落、火烧云和河岸夜景，不做复杂地图。",
                isFavorite: false,
                supportedCategories: [.cityscape, .landscape]
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
            "astroPoor": weather(
                dayOffset: 1,
                temperature: 19,
                cloudCover: 82,
                precipitation: 45,
                windSpeed: 18,
                visibility: 8,
                humidity: 78,
                moonPhase: "Waxing Gibbous",
                moonIllumination: 76
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
            ),
            "southBank": weather(
                dayOffset: 1,
                temperature: 22,
                cloudCover: 54,
                precipitation: 12,
                windSpeed: 11,
                visibility: 18,
                humidity: 58,
                moonPhase: "Waxing Crescent",
                moonIllumination: 22
            )
        ]
    }

    private func makeEvents(locations: [ShootingLocation]) -> [ShootingEvent] {
        let airport = locations[0]
        let campus = locations[1]
        let darkSky = locations[2]
        let southBank = locations[3]

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
                importanceLevel: .rare,
                description: "Mock 航空事件：特殊涂装机预计傍晚抵达，出现频率较低，光线方向适合侧面记录。",
                tags: ["Qantas", "Special Livery", "Retro Livery", "Arrival"],
                sourceType: .mock
            ),
            ShootingEvent(
                id: UUID(uuidString: "63877092-F88C-4C40-B01D-A38000000111") ?? UUID(),
                title: "Brisbane Airport A380 到达",
                category: .aviation,
                eventType: .specialAircraft,
                location: airport,
                startTime: date(dayOffset: 1, hour: 18, minute: 10),
                endTime: date(dayOffset: 1, hour: 18, minute: 45),
                importanceScore: 76,
                importanceLevel: .worthWatching,
                description: "Mock 航空事件：A380 傍晚进港，机型体量和到达时间都值得关注。",
                tags: ["A380", "Rare Aircraft", "Arrival"],
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
                importanceLevel: .rare,
                description: "低月光、低云量和低光污染叠加，适合拍摄银河核心。",
                tags: ["Milky Way", "New Moon", "Dark Sky"],
                sourceType: .mock
            ),
            ShootingEvent(
                id: UUID(uuidString: "B5036E93-0B3D-49B5-8BBD-4E7300000111") ?? UUID(),
                title: "Lake Moogerah 流星雨窗口",
                category: .astro,
                eventType: .meteorShower,
                location: darkSky,
                startTime: date(dayOffset: 3, hour: 23, minute: 20),
                endTime: date(dayOffset: 4, hour: 2, minute: 30),
                importanceScore: 95,
                importanceLevel: .mustShoot,
                description: "Mock 天象事件：低月光叠加流星雨峰值，属于必拍级别窗口。",
                tags: ["Meteor Shower", "Dark Sky", "Must Shoot"],
                sourceType: .mock
            ),
            ShootingEvent(
                id: UUID(uuidString: "88002A8A-9C1D-4E2F-B30D-8CE878395211") ?? UUID(),
                title: "UQ Graduation Season 人像窗口",
                category: .graduation,
                eventType: .graduationSeason,
                location: campus,
                startTime: date(dayOffset: 2, hour: 15, minute: 30),
                endTime: date(dayOffset: 2, hour: 18, minute: 20),
                importanceScore: 78,
                importanceLevel: .worthWatching,
                description: "校园人像与毕业照需求高，下午柔光和低风速比较友好。",
                tags: ["Graduation Season", "Portrait", "Campus"],
                sourceType: .mock
            ),
            ShootingEvent(
                id: UUID(uuidString: "53D98B20-2F50-49B3-BE73-F19E50000111") ?? UUID(),
                title: "South Bank 火烧云可能性窗口",
                category: .landscape,
                eventType: .sunset,
                location: southBank,
                startTime: date(dayOffset: 1, hour: 16, minute: 55),
                endTime: date(dayOffset: 1, hour: 18, minute: 15),
                importanceScore: 70,
                importanceLevel: .worthWatching,
                description: "Mock 风光事件：西侧云层结构较好，South Bank 河岸有火烧云可能。",
                tags: ["Fire Sunset", "South Bank", "Sunset"],
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
        let southBank = locations[3]
        let airportWeather = weather["airport"]!
        let campusWeather = weather["campus"]!
        let darkSkyWeather = weather["darkSky"]!
        let astroPoorWeather = weather["astroPoor"]!
        let landscapeWeather = weather["landscape"]!
        let southBankWeather = weather["southBank"]!
        let aviationEvent = events.first { $0.tags.contains("Special Livery") }!
        let a380Event = events.first { $0.tags.contains("A380") }!
        let astroEvent = events.first { $0.eventType == .milkyWayWindow }!
        let meteorEvent = events.first { $0.eventType == .meteorShower }!
        let graduationEvent = events.first { $0.eventType == .graduationSeason }!
        let fireSunsetEvent = events.first { $0.tags.contains("Fire Sunset") }!

        let poorAstroStart = date(dayOffset: 1, hour: 21, minute: 10)
        let poorAstroEnd = date(dayOffset: 1, hour: 23, minute: 30)
        let poorAstroScore = scoringService.scoreAstroWindow(
            weather: astroPoorWeather,
            location: darkSky,
            timeRange: poorAstroStart...poorAstroEnd
        )

        let astroStart = date(dayOffset: 3, hour: 21, minute: 30)
        let astroEnd = date(dayOffset: 4, hour: 1, minute: 15)
        let astroBaseScore = scoringService.scoreAstroWindow(
            weather: darkSkyWeather,
            location: darkSky,
            timeRange: astroStart...astroEnd
        )
        let astroScore = scoringService.applyEventImportance(baseScore: astroBaseScore, events: [astroEvent])

        let meteorStart = date(dayOffset: 3, hour: 23, minute: 20)
        let meteorEnd = date(dayOffset: 4, hour: 2, minute: 30)
        let meteorBaseScore = scoringService.scoreAstroWindow(
            weather: darkSkyWeather,
            location: darkSky,
            timeRange: meteorStart...meteorEnd
        )
        let meteorScore = scoringService.applyEventImportance(baseScore: meteorBaseScore, events: [meteorEvent])

        let sunsetStart = date(dayOffset: 1, hour: 16, minute: 45)
        let sunsetEnd = date(dayOffset: 1, hour: 18, minute: 35)
        let sunsetScore = scoringService.scoreLandscapeWindow(
            weather: landscapeWeather,
            timeRange: sunsetStart...sunsetEnd
        )

        let aviationStart = date(dayOffset: 1, hour: 16, minute: 45)
        let aviationEnd = date(dayOffset: 1, hour: 18, minute: 10)
        let aviationScore = scoringService.scoreAviationWindow(event: aviationEvent, weather: airportWeather)

        let a380Start = date(dayOffset: 1, hour: 17, minute: 20)
        let a380End = date(dayOffset: 1, hour: 18, minute: 50)
        let a380Score = scoringService.scoreAviationWindow(event: a380Event, weather: airportWeather)

        let graduationStart = date(dayOffset: 2, hour: 15, minute: 45)
        let graduationEnd = date(dayOffset: 2, hour: 18, minute: 10)
        let graduationBaseScore = scoringService.scorePortraitOrGraduationWindow(
            weather: campusWeather,
            timeRange: graduationStart...graduationEnd
        )
        let graduationScore = scoringService.applyEventImportance(baseScore: graduationBaseScore, events: [graduationEvent])

        let fireSunsetStart = date(dayOffset: 1, hour: 16, minute: 55)
        let fireSunsetEnd = date(dayOffset: 1, hour: 18, minute: 15)
        let fireSunsetBaseScore = scoringService.scoreLandscapeWindow(
            weather: southBankWeather,
            timeRange: fireSunsetStart...fireSunsetEnd
        )
        let fireSunsetScore = scoringService.applyEventImportance(
            baseScore: fireSunsetBaseScore,
            events: [fireSunsetEvent]
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
                id: UUID(uuidString: "FDC9D23D-BB4F-4E88-AF1B-9C765200A111") ?? UUID(),
                category: .astro,
                location: darkSky,
                startTime: poorAstroStart,
                endTime: poorAstroEnd,
                windowTitle: "今晚银河不推荐窗口",
                score: poorAstroScore,
                scoreLevel: .from(score: poorAstroScore),
                reasonSummary: "云量和月光都偏高，降雨概率也不低，今晚不适合拍银河。",
                reasonTags: ["云量高", "月光强", "降雨概率较高", "能见度一般"],
                scoreBreakdown: makeScoreBreakdown(for: .astro, score: poorAstroScore),
                notRecommendedReason: "云量 82%，月亮照明 76%，降雨概率较高，银河主体很可能被云层和月光削弱。",
                weatherSnapshot: astroPoorWeather,
                eventRefs: [],
                recommendationText: "今晚建议先不跑远郊，等低月光和低云量窗口再出发。",
                isBookmarked: false,
                alertEnabled: false
            ),
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
                reasonTags: ["云量低", "月光弱", "能见度高", "光污染低", "降雨概率低"],
                scoreBreakdown: makeScoreBreakdown(for: .astro, score: astroScore),
                notRecommendedReason: nil,
                weatherSnapshot: darkSkyWeather,
                eventRefs: [astroEvent],
                recommendationText: "建议提前到达完成构图，预留 20 分钟适应黑暗环境。",
                isBookmarked: true,
                alertEnabled: false
            ),
            ShootingWindow(
                id: UUID(uuidString: "9A1F5A15-8A47-4374-91D6-3D879D883111") ?? UUID(),
                category: .astro,
                location: darkSky,
                startTime: meteorStart,
                endTime: meteorEnd,
                windowTitle: "Lake Moogerah 流星雨必拍窗口",
                score: meteorScore,
                scoreLevel: .from(score: meteorScore),
                reasonSummary: "低月光与暗空地点叠加流星雨峰值，是本周最值得盯的夜间事件。",
                reasonTags: ["流星雨", "必拍事件", "月光弱", "光污染低", "暗空地点"],
                scoreBreakdown: makeScoreBreakdown(for: .astro, score: meteorScore),
                notRecommendedReason: nil,
                weatherSnapshot: darkSkyWeather,
                eventRefs: [meteorEvent],
                recommendationText: "建议提前完成构图和对焦，保留足够电量连续拍摄。",
                isBookmarked: false,
                alertEnabled: false
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
                reasonTags: ["日落时段", "高云适中", "降雨概率低", "风速可控"],
                scoreBreakdown: makeScoreBreakdown(for: .landscape, score: sunsetScore),
                notRecommendedReason: nil,
                weatherSnapshot: landscapeWeather,
                eventRefs: [],
                recommendationText: "优先选择开阔湖岸机位，保留前景层次。",
                isBookmarked: false,
                alertEnabled: false
            ),
            ShootingWindow(
                id: UUID(uuidString: "CA2EA869-F6B2-4D9C-B845-1D495A449111") ?? UUID(),
                category: .landscape,
                location: southBank,
                startTime: fireSunsetStart,
                endTime: fireSunsetEnd,
                windowTitle: "South Bank 火烧云可能性窗口",
                score: fireSunsetScore,
                scoreLevel: .from(score: fireSunsetScore),
                reasonSummary: "日落前云层结构较好，河岸视野开阔，有机会出现火烧云。",
                reasonTags: ["Fire Sunset", "日落时段", "高云适中", "河岸机位"],
                scoreBreakdown: makeScoreBreakdown(for: .landscape, score: fireSunsetScore),
                notRecommendedReason: nil,
                weatherSnapshot: southBankWeather,
                eventRefs: [fireSunsetEvent],
                recommendationText: "建议提前到河岸找前景，优先保留天空层次和水面反光。",
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
                reasonTags: ["特殊涂装", "能见度好", "傍晚光线", "降雨概率低"],
                scoreBreakdown: makeScoreBreakdown(for: .aviation, score: aviationScore),
                notRecommendedReason: nil,
                weatherSnapshot: airportWeather,
                eventRefs: [aviationEvent],
                recommendationText: "建议提前 45 分钟到达公开安全拍摄点，留意航班变更。",
                isBookmarked: true,
                alertEnabled: true
            ),
            ShootingWindow(
                id: UUID(uuidString: "21F8D772-3DB2-4DEB-A380-5E348C880111") ?? UUID(),
                category: .aviation,
                location: airport,
                startTime: a380Start,
                endTime: a380End,
                windowTitle: "A380 傍晚抵达观察窗口",
                score: a380Score,
                scoreLevel: .from(score: a380Score),
                reasonSummary: "A380 机型值得关注，预计傍晚抵达，能见度和降雨条件可接受。",
                reasonTags: ["A380", "值得关注", "能见度好", "傍晚光线"],
                scoreBreakdown: makeScoreBreakdown(for: .aviation, score: a380Score),
                notRecommendedReason: nil,
                weatherSnapshot: airportWeather,
                eventRefs: [a380Event],
                recommendationText: "建议提前查看跑道方向，预留停车和步行时间。",
                isBookmarked: false,
                alertEnabled: false
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
                reasonTags: ["阴天柔光", "风小", "少雨", "温度舒适", "接近黄金时刻"],
                scoreBreakdown: makeScoreBreakdown(for: .graduation, score: graduationScore),
                notRecommendedReason: nil,
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
                reasonTags: ["蓝调时刻", "能见度好", "城市灯光", "降雨概率低"],
                scoreBreakdown: makeScoreBreakdown(for: .cityscape, score: cityScore),
                notRecommendedReason: nil,
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
                reasonTags: ["自然柔光", "风小", "少雨", "温度舒适"],
                scoreBreakdown: makeScoreBreakdown(for: .portrait, score: portraitScore),
                notRecommendedReason: nil,
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
                remindBeforeMinutes: 1_500,
                isEnabled: false,
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

    private func makeWatchlistItems(user: UserProfile) -> [EventWatchlistItem] {
        [
            watchlistItem("D23EA570-85E1-4B67-A380-000000000001", user, .aviation, "A380", "A380"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000002", user, .aviation, "B747", "B747"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000003", user, .aviation, "Special Livery", "Special Livery"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000004", user, .aviation, "Retro Livery", "Retro Livery"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000005", user, .aviation, "Qantas", "Qantas"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000006", user, .aviation, "Cargo", "Cargo"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000007", user, .aviation, "Rare Aircraft", "Rare Aircraft"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000008", user, .astro, "Meteor Shower", "Meteor Shower"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000009", user, .graduation, "Graduation Season", "Graduation Season"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000010", user, .landscape, "Fog", "Fog"),
            watchlistItem("D23EA570-85E1-4B67-A380-000000000011", user, .landscape, "Fire Sunset", "Fire Sunset")
        ]
    }

    private func watchlistItem(
        _ id: String,
        _ user: UserProfile,
        _ category: PhotographyCategory,
        _ keyword: String,
        _ displayName: String
    ) -> EventWatchlistItem {
        EventWatchlistItem(
            id: UUID(uuidString: id) ?? UUID(),
            userId: user.id,
            category: category,
            keyword: keyword,
            displayName: displayName,
            isEnabled: true,
            createdAt: date(dayOffset: -1, hour: 9, minute: 0)
        )
    }

    private func makeScoreBreakdown(for category: PhotographyCategory, score: Int) -> [ScoreBreakdownItem] {
        let specs: [(String, Int)]
        switch category {
        case .astro:
            specs = [("天气", 35), ("月相", 20), ("光污染", 20), ("能见度", 15), ("地点条件", 10)]
        case .aviation:
            specs = [("航班稀缺度", 35), ("能见度", 20), ("降雨", 15), ("风速", 15), ("到场准备", 15)]
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
    var userPreference: UserPreference
    var locations: [ShootingLocation]
    var events: [ShootingEvent]
    var windows: [ShootingWindow]
    var alertRules: [AlertRule]
    var watchlistItems: [EventWatchlistItem]
}
