import XCTest
@testable import PhotoWindow

final class ShootingWindowScoringServiceTests: XCTestCase {
    private let service = ShootingWindowScoringService()

    func testAstroScoreRewardsLowCloudAndLowMoonlight() {
        let location = makeLocation(lightPollution: 2)
        let excellentWeather = makeWeather(cloudCover: 8, rain: 3, moon: 4, wind: 8, visibility: 22, temperature: 18)
        let poorWeather = makeWeather(cloudCover: 92, rain: 70, moon: 91, wind: 20, visibility: 5, temperature: 18)
        let range = Date()...Date().addingTimeInterval(7_200)

        let excellentScore = service.scoreAstroWindow(weather: excellentWeather, location: location, timeRange: range)
        let poorScore = service.scoreAstroWindow(weather: poorWeather, location: location, timeRange: range)

        XCTAssertGreaterThan(excellentScore, poorScore)
        XCTAssertGreaterThanOrEqual(excellentScore, 80)
    }

    func testLandscapeScorePenalizesHighRain() {
        let dryWeather = makeWeather(cloudCover: 45, rain: 5, moon: 20, wind: 8, visibility: 18, temperature: 22)
        let rainyWeather = makeWeather(cloudCover: 45, rain: 85, moon: 20, wind: 8, visibility: 18, temperature: 22)
        let range = dryWeather.goldenHourStart...dryWeather.goldenHourEnd

        let dryScore = service.scoreLandscapeWindow(weather: dryWeather, timeRange: range)
        let rainyScore = service.scoreLandscapeWindow(weather: rainyWeather, timeRange: range)

        XCTAssertGreaterThan(dryScore, rainyScore)
    }

    func testAviationImportanceScoreMatters() {
        let weather = makeWeather(cloudCover: 35, rain: 10, moon: 20, wind: 12, visibility: 20, temperature: 23)
        var importantEvent = makeEvent(importance: 92)
        var ordinaryEvent = importantEvent
        ordinaryEvent.importanceScore = 35

        let importantScore = service.scoreAviationWindow(event: importantEvent, weather: weather)
        let ordinaryScore = service.scoreAviationWindow(event: ordinaryEvent, weather: weather)

        XCTAssertGreaterThan(importantScore, ordinaryScore)
    }

    func testPortraitScorePenalizesWindAndExtremeTemperature() {
        let pleasant = makeWeather(cloudCover: 62, rain: 6, moon: 25, wind: 7, visibility: 16, temperature: 23)
        let harsh = makeWeather(cloudCover: 62, rain: 6, moon: 25, wind: 42, visibility: 16, temperature: 36)
        let range = pleasant.goldenHourStart...pleasant.goldenHourEnd

        let pleasantScore = service.scorePortraitOrGraduationWindow(weather: pleasant, timeRange: range)
        let harshScore = service.scorePortraitOrGraduationWindow(weather: harsh, timeRange: range)

        XCTAssertGreaterThan(pleasantScore, harshScore)
    }

    private func makeLocation(lightPollution: Int) -> ShootingLocation {
        ShootingLocation(
            id: UUID(),
            name: "Test Location",
            latitude: 0,
            longitude: 0,
            city: "Brisbane",
            country: "Australia",
            lightPollutionLevel: lightPollution,
            locationType: .darkSky,
            notes: ""
        )
    }

    private func makeEvent(importance: Int) -> ShootingEvent {
        let location = makeLocation(lightPollution: 5)
        return ShootingEvent(
            id: UUID(),
            title: "Special Aircraft",
            category: .aviation,
            eventType: .specialAircraft,
            location: location,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3_600),
            importanceScore: importance,
            description: "Test event",
            tags: [],
            sourceType: .mock
        )
    }

    private func makeWeather(
        cloudCover: Double,
        rain: Double,
        moon: Double,
        wind: Double,
        visibility: Double,
        temperature: Double
    ) -> WeatherSnapshot {
        let now = Date()
        return WeatherSnapshot(
            temperature: temperature,
            cloudCover: cloudCover,
            precipitationProbability: rain,
            windSpeed: wind,
            visibility: visibility,
            humidity: 55,
            moonPhase: "Test",
            moonIllumination: moon,
            sunriseTime: now,
            sunsetTime: now.addingTimeInterval(43_200),
            goldenHourStart: now,
            goldenHourEnd: now.addingTimeInterval(3_600),
            blueHourStart: now.addingTimeInterval(3_600),
            blueHourEnd: now.addingTimeInterval(5_400)
        )
    }
}
