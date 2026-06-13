import Foundation

@MainActor
struct SpecialEventIngestionService {
    private let repository: any SpecialEventRepository
    private let deduplicationService: SpecialEventDeduplicationService

    init(
        repository: any SpecialEventRepository,
        deduplicationService: SpecialEventDeduplicationService = SpecialEventDeduplicationService()
    ) {
        self.repository = repository
        self.deduplicationService = deduplicationService
    }

    func fetchSpecialEvents() async throws -> [SpecialEvent] {
        deduplicationService
            .deduplicated(try await repository.fetchSpecialEvents())
            .sorted { $0.startTime < $1.startTime }
    }

    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent] {
        deduplicationService
            .deduplicated(try await repository.fetchSpecialEvents(for: location))
            .sorted { $0.startTime < $1.startTime }
    }

    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent] {
        deduplicationService
            .deduplicated(try await repository.fetchSpecialEvents(for: category))
            .sorted { $0.startTime < $1.startTime }
    }

    func fetchSpecialEvents(
        for location: ShootingLocation,
        category: PhotographyCategory,
        timeRange: ClosedRange<Date>? = nil
    ) async throws -> [SpecialEvent] {
        filter(
            try await fetchSpecialEvents(),
            location: location,
            category: category,
            timeRange: timeRange
        )
    }

    func shootingEvents(
        for location: ShootingLocation,
        category: PhotographyCategory,
        timeRange: ClosedRange<Date>? = nil,
        knownLocations: [ShootingLocation]
    ) async throws -> [ShootingEvent] {
        try await fetchSpecialEvents(
            for: location,
            category: category,
            timeRange: timeRange
        )
        .map { $0.shootingEvent(knownLocations: knownLocations) }
    }

    func shootingEvents(
        from events: [SpecialEvent],
        knownLocations: [ShootingLocation],
        location: ShootingLocation? = nil,
        category: PhotographyCategory? = nil,
        timeRange: ClosedRange<Date>? = nil
    ) -> [ShootingEvent] {
        filter(events, location: location, category: category, timeRange: timeRange)
            .map { $0.shootingEvent(knownLocations: knownLocations) }
    }

    func eventLocations(
        from events: [SpecialEvent],
        knownLocations: [ShootingLocation]
    ) -> [ShootingLocation] {
        var locations = knownLocations
        var seen = Set(knownLocations.map(\.id))

        for event in events.sorted(by: { $0.startTime < $1.startTime }) {
            guard seen.insert(event.locationId).inserted else { continue }
            locations.append(event.resolvedLocation(knownLocations: knownLocations))
        }

        return locations
    }

    func specialEvents(
        from events: [SpecialEvent],
        for location: ShootingLocation,
        category: PhotographyCategory,
        timeRange: ClosedRange<Date>? = nil
    ) -> [SpecialEvent] {
        filter(events, location: location, category: category, timeRange: timeRange)
    }

    private func filter(
        _ events: [SpecialEvent],
        location: ShootingLocation? = nil,
        category: PhotographyCategory? = nil,
        timeRange: ClosedRange<Date>? = nil
    ) -> [SpecialEvent] {
        events
            .filter { event in
                if let location {
                    guard event.locationId == location.id || event.locationName == location.name else {
                        return false
                    }
                }

                if let category {
                    guard event.category == category else {
                        return false
                    }
                }

                if let timeRange {
                    guard event.startTime <= timeRange.upperBound && timeRange.lowerBound <= event.endTime else {
                        return false
                    }
                }

                return true
            }
            .sorted {
                if $0.importanceLevel.scoreWeight == $1.importanceLevel.scoreWeight {
                    return $0.startTime < $1.startTime
                }
                return $0.importanceLevel.scoreWeight > $1.importanceLevel.scoreWeight
            }
    }
}
