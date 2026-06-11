import Foundation

struct ShootingWindowScoringService {
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

        return weightedScore([
            (cloudScore, 0.30),
            (rainScore, 0.15),
            (moonScore, 0.25),
            (visibilityScore, 0.15),
            (pollutionScore, 0.15)
        ])
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

        return weightedScore([
            (timeBonus, 0.30),
            (cloudScore, 0.30),
            (rainScore, 0.25),
            (windScore, 0.15)
        ])
    }

    func scoreAviationWindow(event: ShootingEvent, weather: WeatherSnapshot) -> Int {
        let importance = clamp(Double(event.importanceScore))
        let visibilityScore = clamp(weather.visibility / 20.0 * 100.0)
        let rainScore = inversePercent(weather.precipitationProbability)
        let windScore = weather.windSpeed > 38 ? 35.0 : clamp(100.0 - weather.windSpeed * 2.2)

        return weightedScore([
            (importance, 0.45),
            (visibilityScore, 0.25),
            (rainScore, 0.20),
            (windScore, 0.10)
        ])
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

        return weightedScore([
            (softLightScore, 0.35),
            (rainScore, 0.25),
            (windScore, 0.20),
            (temperatureScore, 0.20)
        ])
    }

    private func inversePercent(_ value: Double) -> Double {
        clamp(100.0 - value)
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

    private func overlaps(_ lhs: ClosedRange<Date>, _ rhs: ClosedRange<Date>) -> Bool {
        lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
    }

    private func clamp(_ value: Double) -> Double {
        min(100.0, max(0.0, value))
    }
}
