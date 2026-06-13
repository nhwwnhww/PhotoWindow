import Foundation

struct LocationCoordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double

    static let brisbane = LocationCoordinate(latitude: -27.4705, longitude: 153.0260)

    var coordinateText: String {
        "\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))"
    }
}

struct LocationDebugSnapshot: Codable, Hashable {
    var selectedCoordinate: LocationCoordinate?
    var lastReverseGeocodeResult: String?
    var lastReverseGeocodeSucceeded: Bool?
    var lastReverseGeocodeCheckedAt: Date?
    var lastLocationAPIError: String?
}

enum LocationDebugStateStore {
    private static let key = "PhotoWindow.locationDebugState.v1"

    static func snapshot(userDefaults: UserDefaults = .standard) -> LocationDebugSnapshot {
        guard let data = userDefaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(LocationDebugSnapshot.self, from: data) else {
            return LocationDebugSnapshot()
        }
        return snapshot
    }

    static func recordSelectedCoordinate(
        _ coordinate: LocationCoordinate,
        userDefaults: UserDefaults = .standard
    ) {
        var snapshot = snapshot(userDefaults: userDefaults)
        snapshot.selectedCoordinate = coordinate
        save(snapshot, userDefaults: userDefaults)
    }

    static func recordReverseSuccess(
        _ location: ShootingLocation,
        coordinate: LocationCoordinate,
        userDefaults: UserDefaults = .standard
    ) {
        var snapshot = snapshot(userDefaults: userDefaults)
        snapshot.selectedCoordinate = coordinate
        snapshot.lastReverseGeocodeResult = summary(for: location)
        snapshot.lastReverseGeocodeSucceeded = true
        snapshot.lastReverseGeocodeCheckedAt = Date()
        snapshot.lastLocationAPIError = nil
        save(snapshot, userDefaults: userDefaults)
    }

    static func recordReverseFallback(
        _ location: ShootingLocation,
        coordinate: LocationCoordinate,
        error: Error,
        userDefaults: UserDefaults = .standard
    ) {
        var snapshot = snapshot(userDefaults: userDefaults)
        snapshot.selectedCoordinate = coordinate
        snapshot.lastReverseGeocodeResult = summary(for: location)
        snapshot.lastReverseGeocodeSucceeded = false
        snapshot.lastReverseGeocodeCheckedAt = Date()
        snapshot.lastLocationAPIError = error.localizedDescription
        save(snapshot, userDefaults: userDefaults)
    }

    static func recordReverseError(
        _ error: Error,
        coordinate: LocationCoordinate,
        userDefaults: UserDefaults = .standard
    ) {
        var snapshot = snapshot(userDefaults: userDefaults)
        snapshot.selectedCoordinate = coordinate
        snapshot.lastReverseGeocodeResult = nil
        snapshot.lastReverseGeocodeSucceeded = false
        snapshot.lastReverseGeocodeCheckedAt = Date()
        snapshot.lastLocationAPIError = error.localizedDescription
        save(snapshot, userDefaults: userDefaults)
    }

    private static func summary(for location: ShootingLocation) -> String {
        [
            location.name,
            "\(location.city), \(location.country)",
            location.locationType.displayName,
            LocationCoordinate(latitude: location.latitude, longitude: location.longitude).coordinateText
        ].joined(separator: " · ")
    }

    private static func save(_ snapshot: LocationDebugSnapshot, userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }
}
