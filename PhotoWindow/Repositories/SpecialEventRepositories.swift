import Foundation

@MainActor
final class MockSpecialEventRepository: SpecialEventRepository {
    private var events: [SpecialEvent]
    private let deduplicationService: SpecialEventDeduplicationService

    init(
        events: [SpecialEvent] = [],
        deduplicationService: SpecialEventDeduplicationService = SpecialEventDeduplicationService()
    ) {
        self.events = events
        self.deduplicationService = deduplicationService
    }

    func fetchSpecialEvents() async throws -> [SpecialEvent] {
        deduplicationService
            .deduplicated(events)
            .filter(\.isFuture)
            .sorted { $0.startTime < $1.startTime }
    }

    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent] {
        try await fetchSpecialEvents()
            .filter { $0.locationId == location.id || $0.locationName == location.name }
    }

    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent] {
        try await fetchSpecialEvents()
            .filter { $0.category == category }
    }
}

@MainActor
final class LocalJSONSpecialEventRepository: SpecialEventRepository {
    private let bundle: Bundle
    private let fileName: String
    private let fileExtension: String
    private let fallbackURL: URL?
    private let deduplicationService: SpecialEventDeduplicationService
    private let calendar: Calendar
    private var cachedEvents: [SpecialEvent]?

    init(
        bundle: Bundle = .main,
        fileName: String = "special_events_seed",
        fileExtension: String = "json",
        fallbackURL: URL? = nil,
        deduplicationService: SpecialEventDeduplicationService = SpecialEventDeduplicationService(),
        calendar: Calendar = .current
    ) {
        self.bundle = bundle
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.fallbackURL = fallbackURL
        self.deduplicationService = deduplicationService
        self.calendar = calendar
    }

    func fetchSpecialEvents() async throws -> [SpecialEvent] {
        if let cachedEvents {
            return cachedEvents
        }

        guard let url = seedURL() else {
            throw RepositoryError.notFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([SpecialEvent].self, from: data)
        let rolled = rollForwardExpiredEvents(decoded)
        let events = deduplicationService
            .deduplicated(rolled)
            .filter(\.isFuture)
            .sorted { $0.startTime < $1.startTime }
        cachedEvents = events
        return events
    }

    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent] {
        try await fetchSpecialEvents()
            .filter { $0.locationId == location.id || $0.locationName == location.name }
    }

    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent] {
        try await fetchSpecialEvents()
            .filter { $0.category == category }
    }

    private func seedURL() -> URL? {
        if let url = bundle.url(forResource: fileName, withExtension: fileExtension) {
            return url
        }

        if let fallbackURL, FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            currentDirectory
                .appendingPathComponent("PhotoWindow")
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(fileName).\(fileExtension)"),
            currentDirectory
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(fileName).\(fileExtension)"),
            currentDirectory
                .appendingPathComponent("\(fileName).\(fileExtension)")
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func rollForwardExpiredEvents(_ events: [SpecialEvent]) -> [SpecialEvent] {
        let now = Date()
        let week: TimeInterval = 7 * 24 * 60 * 60

        return events.map { event in
            var rolled = event
            while rolled.endTime < now {
                rolled.startTime = rolled.startTime.addingTimeInterval(week)
                rolled.endTime = rolled.endTime.addingTimeInterval(week)
            }
            return rolled
        }
    }
}

@MainActor
final class RemoteSpecialEventRepository: SpecialEventRepository {
    struct SpecialEventsPage {
        var events: [SpecialEvent]
        var meta: APIMeta?
        var skippedInvalidEventCount: Int
        var validationMessages: [String]
    }

    struct SpecialEventsSyncPage {
        var updated: [SpecialEvent]
        var deleted: [UUID]
        var meta: APIMeta?
        var skippedInvalidEventCount: Int
        var validationMessages: [String]
    }

    struct Metadata: Hashable {
        var eventDataVersion: String?
        var lastUpdated: Date?
        var eventCount: Int
        var publishedEventCount: Int
        var serverTime: Date?
    }

    private struct SpecialEventDTO: Decodable {
        var id: String
        var title: String
        var category: String
        var eventType: String
        var locationId: String
        var locationName: String
        var latitude: Double
        var longitude: Double
        var startTime: String
        var endTime: String
        var importanceLevel: String
        var confidenceLevel: String
        var description: String
        var tags: [String]
        var sourceType: String
        var sourceName: String
        var sourceURL: String?
        var lastUpdated: String
        var createdAt: String
    }

    private struct LossySpecialEventDTO: Decodable {
        var value: SpecialEventDTO?
        var decodeError: String?

        init(from decoder: Decoder) throws {
            do {
                value = try SpecialEventDTO(from: decoder)
                decodeError = nil
            } catch {
                value = nil
                decodeError = error.localizedDescription
            }
        }
    }

    private struct SyncPayloadDTO: Decodable {
        var updated: [LossySpecialEventDTO]
        var deleted: [UUID]
    }

    private struct MetadataDTO: Decodable {
        var eventDataVersion: String?
        var lastUpdated: Date?
        var eventCount: Int
        var publishedEventCount: Int
        var serverTime: Date?
    }

    private var networkClient: NetworkClient
    private let deduplicationService: SpecialEventDeduplicationService

    init(
        baseURL: URL,
        session: URLSession = .shared,
        deduplicationService: SpecialEventDeduplicationService = SpecialEventDeduplicationService()
    ) {
        self.networkClient = NetworkClient(baseURL: baseURL, session: session)
        self.deduplicationService = deduplicationService
    }

    func updateBaseURL(_ baseURL: URL) {
        networkClient = NetworkClient(baseURL: baseURL)
    }

    func fetchSpecialEvents() async throws -> [SpecialEvent] {
        try await fetchSpecialEventsPage().events
    }

    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent] {
        try await fetchSpecialEventsPage(
            queryItems: [
                URLQueryItem(name: "locationId", value: location.id.uuidString)
            ]
        ).events
    }

    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent] {
        try await fetchSpecialEventsPage(
            queryItems: [
                URLQueryItem(name: "category", value: category.rawValue)
            ]
        ).events
    }

    func fetchSpecialEventsPage(queryItems: [URLQueryItem] = []) async throws -> SpecialEventsPage {
        let response: APIResponse<[LossySpecialEventDTO]> = try await networkClient.get(
            APIRequest(
                path: "api/v1/special-events",
                queryItems: queryItems + [URLQueryItem(name: "sort", value: "startTime")]
            )
        )

        guard let items = response.data else {
            throw APIError.noData
        }

        let decoded = decodeEvents(items)
        return SpecialEventsPage(
            events: deduplicationService
                .deduplicated(decoded.events)
                .sorted { $0.startTime < $1.startTime },
            meta: response.meta,
            skippedInvalidEventCount: decoded.skippedCount,
            validationMessages: decoded.reasons
        )
    }

    func syncSpecialEvents(since: Date) async throws -> SpecialEventsSyncPage {
        let response: APIResponse<SyncPayloadDTO> = try await networkClient.get(
            APIRequest(
                path: "api/v1/special-events/sync",
                queryItems: [
                    URLQueryItem(name: "since", value: iso8601String(from: since))
                ]
            )
        )

        guard let payload = response.data else {
            throw APIError.noData
        }

        let decoded = decodeEvents(payload.updated)
        return SpecialEventsSyncPage(
            updated: decoded.events.sorted { $0.startTime < $1.startTime },
            deleted: payload.deleted,
            meta: response.meta,
            skippedInvalidEventCount: decoded.skippedCount,
            validationMessages: decoded.reasons
        )
    }

    func fetchMetadata() async throws -> Metadata {
        let response: APIResponse<MetadataDTO> = try await networkClient.get(
            APIRequest(path: "api/v1/metadata")
        )

        guard let data = response.data else {
            throw APIError.noData
        }

        return Metadata(
            eventDataVersion: data.eventDataVersion,
            lastUpdated: data.lastUpdated,
            eventCount: data.eventCount,
            publishedEventCount: data.publishedEventCount,
            serverTime: data.serverTime
        )
    }

    private func decodeEvents(_ items: [LossySpecialEventDTO]) -> SpecialEventValidationResult {
        var events: [SpecialEvent] = []
        var reasons: [String] = []

        for item in items {
            guard let value = item.value else {
                reasons.append(item.decodeError ?? "event decode failed")
                continue
            }

            do {
                events.append(try makeEvent(from: value))
            } catch {
                reasons.append("\(value.id): \(error.localizedDescription)")
            }
        }

        return SpecialEventValidationResult(
            events: events,
            skippedCount: items.count - events.count,
            reasons: reasons
        )
    }

    private func makeEvent(from dto: SpecialEventDTO) throws -> SpecialEvent {
        var errors: [String] = []

        guard let id = UUID(uuidString: dto.id) else {
            errors.append("invalid id")
            throw APIError.validationFailed(errors)
        }
        guard !dto.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.validationFailed(["title is empty"])
        }
        guard let category = PhotographyCategory(rawValue: dto.category) else {
            throw APIError.validationFailed(["invalid category \(dto.category)"])
        }
        guard let eventType = ShootingEventType(rawValue: dto.eventType) else {
            throw APIError.validationFailed(["invalid eventType \(dto.eventType)"])
        }
        guard let locationId = UUID(uuidString: dto.locationId) else {
            throw APIError.validationFailed(["invalid locationId"])
        }
        guard let importanceLevel = EventImportanceLevel(rawValue: dto.importanceLevel) else {
            throw APIError.validationFailed(["invalid importanceLevel \(dto.importanceLevel)"])
        }
        guard let confidenceLevel = SpecialEventConfidenceLevel(rawValue: dto.confidenceLevel) else {
            throw APIError.validationFailed(["invalid confidenceLevel \(dto.confidenceLevel)"])
        }
        guard let sourceType = SpecialEventSourceType(rawValue: dto.sourceType) else {
            throw APIError.validationFailed(["invalid sourceType \(dto.sourceType)"])
        }
        guard let startTime = parseDate(dto.startTime),
              let endTime = parseDate(dto.endTime),
              let lastUpdated = parseDate(dto.lastUpdated),
              let createdAt = parseDate(dto.createdAt) else {
            throw APIError.validationFailed(["invalid ISO 8601 date"])
        }
        guard startTime < endTime else {
            throw APIError.validationFailed(["startTime must be earlier than endTime"])
        }
        guard (-90...90).contains(dto.latitude), (-180...180).contains(dto.longitude) else {
            throw APIError.validationFailed(["invalid latitude or longitude"])
        }

        return SpecialEvent(
            id: id,
            title: dto.title,
            category: category,
            eventType: eventType,
            locationId: locationId,
            locationName: dto.locationName,
            latitude: dto.latitude,
            longitude: dto.longitude,
            startTime: startTime,
            endTime: endTime,
            importanceLevel: importanceLevel,
            confidenceLevel: confidenceLevel,
            description: dto.description,
            tags: dto.tags,
            sourceType: sourceType,
            sourceName: dto.sourceName,
            sourceURL: dto.sourceURL,
            lastUpdated: lastUpdated,
            createdAt: createdAt
        )
    }

    private func parseDate(_ value: String) -> Date? {
        if let date = Self.iso8601.date(from: value) {
            return date
        }
        return Self.iso8601WithFractions.date(from: value)
    }

    private func iso8601String(from date: Date) -> String {
        Self.iso8601.string(from: date)
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601WithFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

@MainActor
final class RemoteJSONSpecialEventRepository: SpecialEventRepository {
    private let repository: RemoteSpecialEventRepository

    init(baseURL: URL = APIConfig.current.baseURL) {
        self.repository = RemoteSpecialEventRepository(baseURL: baseURL)
    }

    func fetchSpecialEvents() async throws -> [SpecialEvent] {
        try await repository.fetchSpecialEvents()
    }

    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent] {
        try await repository.fetchSpecialEvents(for: location)
    }

    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent] {
        try await repository.fetchSpecialEvents(for: category)
    }

    func syncSpecialEvents(since: Date) async throws -> RemoteSpecialEventRepository.SpecialEventsSyncPage {
        try await repository.syncSpecialEvents(since: since)
    }

    func fetchMetadata() async throws -> RemoteSpecialEventRepository.Metadata {
        try await repository.fetchMetadata()
    }
}

@MainActor
final class APISpecialEventRepository: SpecialEventRepository {
    func fetchSpecialEvents() async throws -> [SpecialEvent] {
        throw RepositoryError.notFound
    }

    func fetchSpecialEvents(for location: ShootingLocation) async throws -> [SpecialEvent] {
        throw RepositoryError.notFound
    }

    func fetchSpecialEvents(for category: PhotographyCategory) async throws -> [SpecialEvent] {
        throw RepositoryError.notFound
    }
}
