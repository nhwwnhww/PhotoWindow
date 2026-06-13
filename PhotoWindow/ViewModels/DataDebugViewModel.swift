import Foundation
import Combine

struct APIDiagnosticResult: Identifiable, Hashable {
    var endpointName: String
    var path: String
    var isSuccess: Bool
    var statusCode: Int?
    var summary: String
    var checkedAt: Date

    var id: String { path }
}

private enum APIDiagnosticEndpoint: CaseIterable {
    case health
    case metadata
    case specialEvents
    case locationSearch
    case locationReverse

    var name: String {
        switch self {
        case .health:
            return "Health"
        case .metadata:
            return "Metadata"
        case .specialEvents:
            return "Special Events"
        case .locationSearch:
            return "Location Search"
        case .locationReverse:
            return "Location Reverse"
        }
    }

    var path: String {
        switch self {
        case .health:
            return "health"
        case .metadata:
            return "api/v1/metadata"
        case .specialEvents:
            return "api/v1/special-events"
        case .locationSearch:
            return "api/v1/locations/search"
        case .locationReverse:
            return "api/v1/locations/reverse"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .locationSearch:
            return [URLQueryItem(name: "q", value: "Brisbane")]
        case .locationReverse:
            return [
                URLQueryItem(name: "lat", value: "-27.47"),
                URLQueryItem(name: "lon", value: "153.02")
            ]
        case .health, .metadata, .specialEvents:
            return []
        }
    }

    var displayPath: String {
        guard !queryItems.isEmpty else {
            return "/\(path)"
        }

        var components = URLComponents()
        components.path = "/\(path)"
        components.queryItems = queryItems
        return components.string ?? "/\(path)"
    }
}

@MainActor
final class DataDebugViewModel: ObservableObject {
    @Published var selectedEnvironment: APIEnvironment
    @Published var customBaseURL: String
    @Published private(set) var dataSource: SpecialEventDataSource = .bundledJSON
    @Published private(set) var syncState: SpecialEventSyncState = .loading
    @Published private(set) var dataVersion: String?
    @Published private(set) var cacheInfo: SpecialEventCacheInfo?
    @Published private(set) var lastRemoteFetchTime: Date?
    @Published private(set) var lastSuccessfulFetchTime: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var skippedInvalidEventCount = 0
    @Published private(set) var eventCount = 0
    @Published private(set) var aviationEventCount = 0
    @Published private(set) var aviationLastUpdated: Date?
    @Published private(set) var aviationLastError: String?
    @Published private(set) var scoringConfigLoaded = false
    @Published private(set) var scoringConfigError: String?
    @Published private(set) var notificationQualityRules: NotificationQualityRulesSnapshot?
    @Published private(set) var skippedNotificationRecords: [SkippedNotificationRecord] = []
    @Published private(set) var onboardingPreferenceSummary = "-"
    @Published private(set) var minScoreForNotification = NotificationPreference.defaultValue.minScoreForNotification
    @Published private(set) var message: String?
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isCheckingAPI = false
    @Published private(set) var apiDiagnostics: [APIDiagnosticResult] = []

    private let specialEventDataService: SpecialEventDataService
    private let notificationService: any NotificationServicing
    private let userPreferenceRepository: any UserPreferenceRepository
    private let scoringRuleConfigService: ScoringRuleConfigService

    init(
        specialEventDataService: SpecialEventDataService,
        notificationService: any NotificationServicing,
        userPreferenceRepository: any UserPreferenceRepository,
        scoringRuleConfigService: ScoringRuleConfigService = ScoringRuleConfigService()
    ) {
        self.specialEventDataService = specialEventDataService
        self.notificationService = notificationService
        self.userPreferenceRepository = userPreferenceRepository
        self.scoringRuleConfigService = scoringRuleConfigService
        let config = specialEventDataService.apiConfig
        self.selectedEnvironment = config.environment
        self.customBaseURL = config.environment == .custom ? config.baseURL.absoluteString : ""
        updateDiagnostics()
    }

    var currentBaseURL: String {
        APIConfig.config(for: selectedEnvironment).baseURL.absoluteString
    }

    var activeBaseURL: String {
        specialEventDataService.apiConfig.baseURL.absoluteString
    }

    func load() {
        if let cached = specialEventDataService.cachedEvents() {
            apply(cached, message: "Loaded cached events.")
        } else {
            updateDiagnostics()
        }
        Task { await loadPreferenceDiagnostics() }
    }

    func saveAPISettings() {
        APIConfig.save(environment: selectedEnvironment, customBaseURL: customBaseURL)
        let defaultConfig = APIConfig.config(for: selectedEnvironment)
        let baseURLString = selectedEnvironment == .custom ? customBaseURL : defaultConfig.baseURL.absoluteString
        let nextConfig = APIConfig(
            environment: selectedEnvironment,
            baseURL: URL(string: baseURLString) ?? defaultConfig.baseURL,
            useRemoteSpecialEvents: true
        )
        specialEventDataService.updateAPIConfig(nextConfig)
        message = "API environment saved."
        updateDiagnostics()
    }

    func refresh() async {
        isLoading = true
        apply(await specialEventDataService.refreshEvents(), message: "Refresh finished.")
        isLoading = false
    }

    func clearCache() {
        specialEventDataService.clearCache()
        message = "Cache cleared."
        updateDiagnostics()
    }

    func clearCacheAndRefresh() async {
        isLoading = true
        specialEventDataService.clearCache()
        apply(await specialEventDataService.refreshEvents(), message: "Cache cleared. Remote refresh finished.")
        isLoading = false
    }

    func reloadBundledJSON() async {
        isLoading = true
        apply(await specialEventDataService.loadBundledJSON(), message: "Loaded bundled JSON.")
        isLoading = false
    }

    func runAPIDiagnostics() async {
        isCheckingAPI = true
        defer { isCheckingAPI = false }

        var results: [APIDiagnosticResult] = []
        for endpoint in APIDiagnosticEndpoint.allCases {
            let result = await check(endpoint)
            if endpoint == .specialEvents, !result.isSuccess {
                aviationLastError = result.summary
            }
            results.append(result)
        }

        apiDiagnostics = results
        if let failure = results.first(where: { !$0.isSuccess }) {
            lastError = "\(failure.endpointName): \(failure.summary)"
            errorMessage = lastError
            message = "API diagnostics finished with errors."
        } else {
            lastError = nil
            errorMessage = nil
            message = "API diagnostics passed."
        }
    }

    private func apply(_ result: SpecialEventLoadResult, message: String?) {
        dataSource = result.dataSource
        syncState = result.status
        dataVersion = result.dataVersion
        cacheInfo = result.cacheInfo
        lastError = result.errorMessage ?? specialEventDataService.lastError
        skippedInvalidEventCount = result.skippedInvalidEventCount
        eventCount = result.events.count
        applyAviationStats(from: result.events, lastError: result.errorMessage ?? specialEventDataService.lastError)
        self.message = message ?? result.warningMessage
        errorMessage = result.errorMessage
        updateDiagnostics()
    }

    private func updateDiagnostics() {
        cacheInfo = specialEventDataService.cacheInfo()
        lastRemoteFetchTime = specialEventDataService.lastRemoteFetchTime
        lastSuccessfulFetchTime = specialEventDataService.lastSuccessfulFetchTime
        lastError = specialEventDataService.lastError ?? lastError
        skippedInvalidEventCount = specialEventDataService.skippedInvalidEventCount
        _ = scoringRuleConfigService.loadConfig()
        scoringConfigLoaded = scoringRuleConfigService.lastLoadSucceeded
        scoringConfigError = scoringRuleConfigService.lastLoadError
        notificationQualityRules = notificationService.notificationQualityRules()
        skippedNotificationRecords = notificationService.recentSkippedNotifications()
    }

    private func loadPreferenceDiagnostics() async {
        do {
            let preference = try await userPreferenceRepository.fetchPreference()
            let notificationPreference = preference.effectiveNotificationPreference
            onboardingPreferenceSummary = [
                "类别 \(preference.selectedCategories.count)",
                "地点 \(preference.favoriteLocationIds.count)",
                "最低评分 \(preference.defaultMinScore)",
                preference.onboardingCompletedAt == nil ? "未完成 onboarding" : "已完成 onboarding"
            ].joined(separator: " / ")
            minScoreForNotification = notificationPreference.minScoreForNotification
            notificationQualityRules = notificationService.notificationQualityRules()
        } catch {
            onboardingPreferenceSummary = "偏好读取失败：\(error.localizedDescription)"
        }
    }

    private func check(_ endpoint: APIDiagnosticEndpoint) async -> APIDiagnosticResult {
        let checkedAt = Date()

        do {
            var request = URLRequest(url: url(for: endpoint.path, queryItems: endpoint.queryItems))
            request.httpMethod = HTTPMethod.get.rawValue
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return diagnosticResult(endpoint, checkedAt: checkedAt, isSuccess: false, statusCode: nil, summary: "Invalid HTTP response.")
            }

            let statusCode = httpResponse.statusCode
            guard (200..<300).contains(statusCode) else {
                return diagnosticResult(endpoint, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "HTTP \(statusCode).")
            }

            return parseDiagnosticResponse(endpoint, data: data, statusCode: statusCode, checkedAt: checkedAt)
        } catch {
            return diagnosticResult(endpoint, checkedAt: checkedAt, isSuccess: false, statusCode: nil, summary: error.localizedDescription)
        }
    }

    private func parseDiagnosticResponse(
        _ endpoint: APIDiagnosticEndpoint,
        data: Data,
        statusCode: Int,
        checkedAt: Date
    ) -> APIDiagnosticResult {
        switch endpoint {
        case .health:
            return diagnosticResult(endpoint, checkedAt: checkedAt, isSuccess: true, statusCode: statusCode, summary: "OK")
        case .metadata:
            return parseMetadataDiagnostic(data: data, statusCode: statusCode, checkedAt: checkedAt)
        case .specialEvents:
            return parseSpecialEventsDiagnostic(data: data, statusCode: statusCode, checkedAt: checkedAt)
        case .locationSearch:
            return parseLocationSearchDiagnostic(data: data, statusCode: statusCode, checkedAt: checkedAt)
        case .locationReverse:
            return parseLocationReverseDiagnostic(data: data, statusCode: statusCode, checkedAt: checkedAt)
        }
    }

    private func parseMetadataDiagnostic(data: Data, statusCode: Int, checkedAt: Date) -> APIDiagnosticResult {
        do {
            let envelope = try diagnosticDecoder.decode(MetadataDiagnosticEnvelope.self, from: data)
            if let error = envelope.error {
                return diagnosticResult(.metadata, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "\(error.code): \(error.message)")
            }

            guard let metadata = envelope.data else {
                return diagnosticResult(.metadata, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "Missing metadata data.")
            }

            dataVersion = metadata.eventDataVersion ?? dataVersion
            eventCount = metadata.publishedEventCount ?? metadata.eventCount ?? eventCount

            let versionText = metadata.eventDataVersion ?? "-"
            let countText = metadata.publishedEventCount.map(String.init) ?? metadata.eventCount.map(String.init) ?? "-"
            return diagnosticResult(.metadata, checkedAt: checkedAt, isSuccess: true, statusCode: statusCode, summary: "dataVersion \(versionText) · published events \(countText)")
        } catch {
            return diagnosticResult(.metadata, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: error.localizedDescription)
        }
    }

    private func parseSpecialEventsDiagnostic(data: Data, statusCode: Int, checkedAt: Date) -> APIDiagnosticResult {
        do {
            let envelope = try diagnosticDecoder.decode(SpecialEventsDiagnosticEnvelope.self, from: data)
            if let error = envelope.error {
                return diagnosticResult(.specialEvents, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "\(error.code): \(error.message)")
            }

            let rows = envelope.data ?? []
            let nonPublishedCount = rows.filter { !$0.isPublished }.count
            let aviationRows = rows.filter { $0.isPublished && $0.isAviationAPI }
            let count = envelope.meta?.count ?? rows.count
            let total = envelope.meta?.total
            dataVersion = envelope.meta?.dataVersion ?? dataVersion
            eventCount = total ?? count
            aviationEventCount = aviationRows.count
            aviationLastUpdated = aviationRows.compactMap { parseDate($0.lastUpdated) }.max()
            aviationLastError = nil

            if nonPublishedCount > 0 {
                aviationLastError = "Contains \(nonPublishedCount) non-published events."
                return diagnosticResult(.specialEvents, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "Contains \(nonPublishedCount) non-published events.")
            }

            let totalText = total.map { " / total \($0)" } ?? ""
            return diagnosticResult(.specialEvents, checkedAt: checkedAt, isSuccess: true, statusCode: statusCode, summary: "published events \(count)\(totalText)")
        } catch {
            aviationLastError = error.localizedDescription
            return diagnosticResult(.specialEvents, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: error.localizedDescription)
        }
    }

    private func parseLocationSearchDiagnostic(data: Data, statusCode: Int, checkedAt: Date) -> APIDiagnosticResult {
        do {
            let envelope = try diagnosticDecoder.decode(LocationSearchDiagnosticEnvelope.self, from: data)
            if let error = envelope.error {
                return diagnosticResult(.locationSearch, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "\(error.code): \(error.message)")
            }

            let locations = envelope.data?.locations ?? []
            let sample = locations.first.map { "\($0.name) · \($0.coordinateText) · \($0.locationTypeText)" } ?? "no sample"
            return diagnosticResult(.locationSearch, checkedAt: checkedAt, isSuccess: !locations.isEmpty, statusCode: statusCode, summary: "\(locations.count) results · \(sample)")
        } catch {
            return diagnosticResult(.locationSearch, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: error.localizedDescription)
        }
    }

    private func parseLocationReverseDiagnostic(data: Data, statusCode: Int, checkedAt: Date) -> APIDiagnosticResult {
        do {
            let envelope = try diagnosticDecoder.decode(LocationReverseDiagnosticEnvelope.self, from: data)
            if let error = envelope.error {
                return diagnosticResult(.locationReverse, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "\(error.code): \(error.message)")
            }

            guard let location = envelope.data?.location else {
                return diagnosticResult(.locationReverse, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: "Missing reverse location.")
            }

            return diagnosticResult(.locationReverse, checkedAt: checkedAt, isSuccess: true, statusCode: statusCode, summary: "\(location.name) · \(location.coordinateText) · \(location.locationTypeText)")
        } catch {
            return diagnosticResult(.locationReverse, checkedAt: checkedAt, isSuccess: false, statusCode: statusCode, summary: error.localizedDescription)
        }
    }

    private func applyAviationStats(from events: [SpecialEvent], lastError: String?) {
        let aviationEvents = events.filter { $0.sourceType == .aviationAPI }
        aviationEventCount = aviationEvents.count
        aviationLastUpdated = aviationEvents.map(\.lastUpdated).max()
        aviationLastError = lastError
    }

    private func diagnosticResult(
        _ endpoint: APIDiagnosticEndpoint,
        checkedAt: Date,
        isSuccess: Bool,
        statusCode: Int?,
        summary: String
    ) -> APIDiagnosticResult {
        APIDiagnosticResult(
            endpointName: endpoint.name,
            path: endpoint.displayPath,
            isSuccess: isSuccess,
            statusCode: statusCode,
            summary: summary,
            checkedAt: checkedAt
        )
    }

    private func url(for path: String, queryItems: [URLQueryItem]) -> URL {
        var normalizedPath = path
        if normalizedPath.hasPrefix("/") {
            normalizedPath.removeFirst()
        }
        let url = specialEventDataService.apiConfig.baseURL.appendingPathComponent(normalizedPath)
        guard !queryItems.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.queryItems = queryItems
        return components.url ?? url
    }

    private var diagnosticDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = Self.iso8601.date(from: value) {
            return date
        }
        return Self.iso8601WithFractions.date(from: value)
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

private struct MetadataDiagnosticEnvelope: Decodable {
    var data: MetadataDiagnosticData?
    var error: APIResponseErrorBody?
}

private struct MetadataDiagnosticData: Decodable {
    var eventDataVersion: String?
    var eventCount: Int?
    var publishedEventCount: Int?
}

private struct SpecialEventsDiagnosticEnvelope: Decodable {
    var data: [SpecialEventDiagnosticRow]?
    var meta: SpecialEventsDiagnosticMeta?
    var error: APIResponseErrorBody?
}

private struct SpecialEventsDiagnosticMeta: Decodable {
    var count: Int?
    var total: Int?
    var dataVersion: String?
}

private struct SpecialEventDiagnosticRow: Decodable {
    var status: String?
    var sourceType: String?
    var lastUpdated: String?

    var isPublished: Bool {
        guard let status = status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty else {
            return true
        }
        return status.lowercased() == "published"
    }

    var isAviationAPI: Bool {
        sourceType?.trimmingCharacters(in: .whitespacesAndNewlines) == SpecialEventSourceType.aviationAPI.rawValue
    }
}

private struct LocationSearchDiagnosticEnvelope: Decodable {
    var data: LocationSearchDiagnosticData?
    var error: APIResponseErrorBody?
}

private struct LocationReverseDiagnosticEnvelope: Decodable {
    var data: LocationReverseDiagnosticData?
    var error: APIResponseErrorBody?
}

private struct LocationSearchDiagnosticData: Decodable {
    var locations: [LocationDiagnosticRow]

    init(from decoder: Decoder) throws {
        if let locations = try? decoder.singleValueContainer().decode([LocationDiagnosticRow].self) {
            self.locations = locations
            return
        }

        let container = try decoder.container(keyedBy: LocationDiagnosticCollectionCodingKey.self)
        for key in LocationDiagnosticCollectionCodingKey.collectionKeys {
            if let locations = try? container.decode([LocationDiagnosticRow].self, forKey: key) {
                self.locations = locations
                return
            }
        }

        for key in LocationDiagnosticCollectionCodingKey.singleLocationKeys {
            if let location = try? container.decode(LocationDiagnosticRow.self, forKey: key) {
                self.locations = [location]
                return
            }
        }

        self.locations = []
    }
}

private struct LocationReverseDiagnosticData: Decodable {
    var location: LocationDiagnosticRow?

    init(from decoder: Decoder) throws {
        if let location = try? decoder.singleValueContainer().decode(LocationDiagnosticRow.self) {
            self.location = location
            return
        }

        if let collection = try? LocationSearchDiagnosticData(from: decoder) {
            self.location = collection.locations.first
            return
        }

        self.location = nil
    }
}

private struct LocationDiagnosticCollectionCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    static let collectionKeys = [
        LocationDiagnosticCollectionCodingKey(stringValue: "locations")!,
        LocationDiagnosticCollectionCodingKey(stringValue: "results")!,
        LocationDiagnosticCollectionCodingKey(stringValue: "items")!,
        LocationDiagnosticCollectionCodingKey(stringValue: "data")!
    ]

    static let singleLocationKeys = [
        LocationDiagnosticCollectionCodingKey(stringValue: "location")!,
        LocationDiagnosticCollectionCodingKey(stringValue: "result")!
    ]
}

private struct LocationDiagnosticRow: Decodable {
    var name: String
    var latitude: Double?
    var longitude: Double?
    var locationType: String?

    var coordinateText: String {
        guard let latitude, let longitude else {
            return "coordinate missing"
        }
        return "\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"
    }

    var locationTypeText: String {
        guard let locationType,
              let type = ShootingLocationType(rawValue: locationType) else {
            return "type missing"
        }
        return type.displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LocationDiagnosticCodingKey.self)
        name = container.trimmedString(for: ["name", "displayName", "title"]) ?? "-"
        latitude = container.double(for: ["latitude", "lat"])
        longitude = container.double(for: ["longitude", "lon", "lng"])
        locationType = container.trimmedString(for: ["locationType", "suggestedLocationType", "type"])
    }
}

private struct LocationDiagnosticCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == LocationDiagnosticCodingKey {
    func trimmedString(for keys: [String]) -> String? {
        for key in keys {
            guard let codingKey = LocationDiagnosticCodingKey(stringValue: key) else { continue }
            if let value = try? decode(String.self, forKey: codingKey) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    func double(for keys: [String]) -> Double? {
        for key in keys {
            guard let codingKey = LocationDiagnosticCodingKey(stringValue: key) else { continue }
            if let value = try? decode(Double.self, forKey: codingKey) {
                return value
            }
            if let value = try? decode(String.self, forKey: codingKey),
               let doubleValue = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return doubleValue
            }
        }
        return nil
    }
}
