import Foundation

struct SharePlanCard {
    var title: String
    var timeText: String
    var locationText: String
    var scoreText: String
    var reasonText: String
    var sourceName: String
    var shareURL: String?

    var text: String {
        [
            title,
            "时间：\(timeText)",
            "地点：\(locationText)",
            "推荐：\(scoreText)",
            "原因：\(reasonText)",
            "sourceName：\(sourceName)"
        ].joined(separator: "\n")
    }

    var activityItems: [Any] {
        var items: [Any] = [text]
        if let shareURL,
           let url = URL(string: shareURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
            items.append(url)
        }
        return items
    }

    var shareURLResultText: String {
        if let shareURL,
           !shareURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "available · \(shareURL)"
        }
        return "not provided · shared local text"
    }
}

enum SharePlanComposer {
    static func weatherSummary(_ weather: WeatherSnapshot) -> String {
        "云量 \(Int(weather.cloudCover))%，降雨 \(Int(weather.precipitationProbability))%，能见度 \(Int(weather.visibility)) km，风速 \(Int(weather.windSpeed)) km/h"
    }

    static func sourceName(for window: ShootingWindow) -> String {
        window.primaryEvent?.sourceType.displayName ?? "photochaser local recommendation"
    }

    static func sourceName(for event: SpecialEvent) -> String {
        let sourceName = event.sourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "PhotoWindow", with: "photochaser")
        return sourceName.isEmpty ? event.sourceType.displayName : sourceName
    }

    static func shareURL(for event: SpecialEvent) -> String? {
        let shareURL = event.shareURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let shareURL, !shareURL.isEmpty {
            return shareURL
        }
        return nil
    }
}
