import Foundation

struct WeatherSnapshot: Codable, Hashable {
    var temperature: Double
    var cloudCover: Double
    var precipitationProbability: Double
    var windSpeed: Double
    var visibility: Double
    var humidity: Double
    var moonPhase: String
    var moonIllumination: Double
    var sunriseTime: Date
    var sunsetTime: Date
    var goldenHourStart: Date
    var goldenHourEnd: Date
    var blueHourStart: Date
    var blueHourEnd: Date
}
