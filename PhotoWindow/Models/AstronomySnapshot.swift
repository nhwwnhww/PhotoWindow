import Foundation

struct AstronomySnapshot: Codable, Hashable {
    var date: Date
    var sunriseTime: Date
    var sunsetTime: Date
    var goldenHourStart: Date
    var goldenHourEnd: Date
    var blueHourStart: Date
    var blueHourEnd: Date
    var moonPhase: String
    var moonIllumination: Double
}
