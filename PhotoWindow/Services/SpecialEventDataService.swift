import Foundation

enum APIEnvironment: String, CaseIterable, Codable, Hashable, Identifiable {
    case localSimulator
    case localNetwork
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localSimulator:
            return "Local Simulator"
        case .localNetwork:
            return "Local Network"
        case .custom:
            return "Custom"
        }
    }
}

struct APIConfig: Codable, Hashable {
    var environment: APIEnvironment
    var baseURL: URL
    var useRemoteSpecialEvents: Bool

    var localServerBaseURL: URL { baseURL }

    static let localSimulator = APIConfig(
        environment: .localSimulator,
        baseURL: URL(string: "http://localhost:3000")!,
        useRemoteSpecialEvents: true
    )

    static let localNetwork = APIConfig(
        environment: .localNetwork,
        baseURL: URL(string: "http://192.168.1.100:3000")!,
        useRemoteSpecialEvents: true
    )

    static let customFallback = APIConfig(
        environment: .custom,
        baseURL: URL(string: "http://localhost:3000")!,
        useRemoteSpecialEvents: true
    )

    private static let environmentKey = "photowindow.api.environment"
    private static let customBaseURLKey = "photowindow.api.customBaseURL"

    static var current: APIConfig {
        let processEnvironment = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        let selectedEnvironment = APIEnvironment(
            rawValue: processEnvironment["PHOTOWINDOW_API_ENVIRONMENT"]
                ?? defaults.string(forKey: environmentKey)
                ?? ""
        ) ?? .localSimulator
        let defaultConfig = config(for: selectedEnvironment)
        let baseURLString = processEnvironment["PHOTOWINDOW_API_BASE_URL"]
            ?? processEnvironment["PHOTOWINDOW_LOCAL_SERVER_BASE_URL"]
            ?? (selectedEnvironment == .custom ? defaults.string(forKey: customBaseURLKey) : nil)
            ?? defaultConfig.baseURL.absoluteString
        let useRemoteValue = processEnvironment["PHOTOWINDOW_USE_REMOTE_SPECIAL_EVENTS"]?.lowercased()
        let useRemote = useRemoteValue.map { !["0", "false", "no"].contains($0) } ?? true

        return APIConfig(
            environment: selectedEnvironment,
            baseURL: URL(string: baseURLString) ?? defaultConfig.baseURL,
            useRemoteSpecialEvents: useRemote
        )
    }

    static var development: APIConfig { current }

    static func config(for environment: APIEnvironment) -> APIConfig {
        switch environment {
        case .localSimulator:
            return .localSimulator
        case .localNetwork:
            return .localNetwork
        case .custom:
            return .customFallback
        }
    }

    static func save(environment: APIEnvironment, customBaseURL: String?) {
        let defaults = UserDefaults.standard
        defaults.set(environment.rawValue, forKey: environmentKey)

        if let customBaseURL, !customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(customBaseURL, forKey: customBaseURLKey)
        }
    }
}

struct AppEnvironment {
    var apiConfig: APIConfig

    static let development = AppEnvironment(apiConfig: .development)
}

enum SpecialEventDataSource: String, Codable, Hashable {
    case remoteServer
    case localCache
    case bundledJSON
    case mock

    var displayName: String {
        switch self {
        case .remoteServer:
            return "本地服务器"
        case .localCache:
            return "离线缓存"
        case .bundledJSON:
            return "内置示例数据"
        case .mock:
            return "Mock 数据"
        }
    }
}

enum SpecialEventSyncState: String, Codable, Hashable {
    case loading
    case usingCache
    case usingRemote
    case usingBundledJSON
    case failedWithFallback
    case failedNoData

    var displayName: String {
        switch self {
        case .loading:
            return "加载中"
        case .usingCache:
            return "使用缓存"
        case .usingRemote:
            return "使用服务器数据"
        case .usingBundledJSON:
            return "使用内置数据"
        case .failedWithFallback:
            return "失败后 fallback"
        case .failedNoData:
            return "无可用数据"
        }
    }
}

struct SpecialEventCacheInfo: Codable, Hashable {
    var eventCount: Int
    var dataVersion: String?
    var lastUpdated: Date?
    var cachedAt: Date?
    var source: SpecialEventDataSource?
    var filePath: String
}

struct SpecialEventLoadResult {
    var events: [SpecialEvent]
    var dataSource: SpecialEventDataSource
    var status: SpecialEventSyncState
    var lastUpdated: Date?
    var dataVersion: String?
    var cacheInfo: SpecialEventCacheInfo?
    var warningMessage: String?
    var errorMessage: String?
    var skippedInvalidEventCount: Int
}

struct CachedSpecialEvents: Codable {
    var events: [SpecialEvent]
    var dataVersion: String?
    var lastUpdated: Date?
    var cachedAt: Date
    var source: SpecialEventDataSource
}

struct SpecialEventValidationResult {
    var events: [SpecialEvent]
    var skippedCount: Int
    var reasons: [String]
}

final class SpecialEventDataValidator {
    func validate(_ events: [SpecialEvent]) -> SpecialEventValidationResult {
        var validEvents: [SpecialEvent] = []
        var reasons: [String] = []

        for event in events {
            let eventReasons = validationErrors(for: event)
            if eventReasons.isEmpty {
                validEvents.append(event)
            } else {
                reasons.append("\(event.id.uuidString): \(eventReasons.joined(separator: ", "))")
            }
        }

        return SpecialEventValidationResult(
            events: validEvents,
            skippedCount: events.count - validEvents.count,
            reasons: reasons
        )
    }

    private func validationErrors(for event: SpecialEvent) -> [String] {
        var errors: [String] = []

        if event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("title is empty")
        }

        if event.startTime >= event.endTime {
            errors.append("startTime must be earlier than endTime")
        }

        if !(-90...90).contains(event.latitude) {
            errors.append("latitude is invalid")
        }

        if !(-180...180).contains(event.longitude) {
            errors.append("longitude is invalid")
        }

        if event.tags.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append("tags contain empty values")
        }

        return errors
    }
}

final class SpecialEventCacheService {
    private let fileManager: FileManager
    private let cacheDirectoryName = "PhotoWindowCache"
    private let cacheFileName = "special_events_cache.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var cacheFileURL: URL {
        applicationSupportDirectory()
            .appendingPathComponent(cacheDirectoryName, isDirectory: true)
            .appendingPathComponent(cacheFileName)
    }

    func loadCachedEvents() -> CachedSpecialEvents? {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            return try decoder.decode(CachedSpecialEvents.self, from: data)
        } catch {
            return nil
        }
    }

    func saveEvents(
        _ events: [SpecialEvent],
        meta: APIMeta?,
        source: SpecialEventDataSource = .remoteServer
    ) {
        let cache = CachedSpecialEvents(
            events: events,
            dataVersion: meta?.dataVersion,
            lastUpdated: meta?.lastUpdated ?? latestUpdatedDate(in: events),
            cachedAt: Date(),
            source: source
        )

        do {
            try fileManager.createDirectory(
                at: cacheFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(cache)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save special event cache: \(error.localizedDescription)")
        }
    }

    func clearCache() {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else { return }
        try? fileManager.removeItem(at: cacheFileURL)
    }

    func cacheInfo() -> SpecialEventCacheInfo {
        let cache = loadCachedEvents()
        return SpecialEventCacheInfo(
            eventCount: cache?.events.count ?? 0,
            dataVersion: cache?.dataVersion,
            lastUpdated: cache?.lastUpdated,
            cachedAt: cache?.cachedAt,
            source: cache?.source,
            filePath: cacheFileURL.path
        )
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func applicationSupportDirectory() -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls.first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private func latestUpdatedDate(in events: [SpecialEvent]) -> Date? {
        events.map(\.lastUpdated).max()
    }
}

@MainActor
final class SpecialEventSyncService {
    private var config: APIConfig
    private let remoteRepository: RemoteSpecialEventRepository
    private let bundledRepository: any SpecialEventRepository
    private let mockRepository: any SpecialEventRepository
    private let cacheService: SpecialEventCacheService
    private let validator: SpecialEventDataValidator
    private(set) var lastRemoteFetchTime: Date?
    private(set) var lastSuccessfulFetchTime: Date?
    private(set) var lastError: String?
    private(set) var skippedInvalidEventCount = 0

    init(
        config: APIConfig,
        remoteRepository: RemoteSpecialEventRepository,
        bundledRepository: any SpecialEventRepository,
        mockRepository: any SpecialEventRepository,
        cacheService: SpecialEventCacheService,
        validator: SpecialEventDataValidator = SpecialEventDataValidator()
    ) {
        self.config = config
        self.remoteRepository = remoteRepository
        self.bundledRepository = bundledRepository
        self.mockRepository = mockRepository
        self.cacheService = cacheService
        self.validator = validator
    }

    func updateConfig(_ config: APIConfig) {
        self.config = config
        remoteRepository.updateBaseURL(config.baseURL)
    }

    func cachedResult() -> SpecialEventLoadResult? {
        guard let cache = cacheService.loadCachedEvents(), !cache.events.isEmpty else {
            return nil
        }

        let validated = validator.validate(cache.events)
        skippedInvalidEventCount = validated.skippedCount

        return SpecialEventLoadResult(
            events: validated.events,
            dataSource: .localCache,
            status: .usingCache,
            lastUpdated: cache.lastUpdated ?? latestUpdatedDate(in: validated.events) ?? cache.cachedAt,
            dataVersion: cache.dataVersion,
            cacheInfo: cacheService.cacheInfo(),
            warningMessage: nil,
            errorMessage: nil,
            skippedInvalidEventCount: validated.skippedCount
        )
    }

    func refresh() async -> SpecialEventLoadResult {
        guard config.useRemoteSpecialEvents else {
            return await fallback(remoteError: nil)
        }

        lastRemoteFetchTime = Date()

        do {
            let metadata = try await remoteRepository.fetchMetadata()
            let cache = cacheService.loadCachedEvents()

            if let cache,
               cache.dataVersion == metadata.eventDataVersion,
               let cacheLastUpdated = cache.lastUpdated,
               let remoteLastUpdated = metadata.lastUpdated,
               remoteLastUpdated > cacheLastUpdated {
                return try await incrementalRefresh(cache: cache, since: cacheLastUpdated)
            }

            if let cache,
               cache.dataVersion == metadata.eventDataVersion,
               metadata.lastUpdated == nil || metadata.lastUpdated == cache.lastUpdated {
                let validated = validator.validate(cache.events)
                skippedInvalidEventCount = validated.skippedCount
                lastSuccessfulFetchTime = Date()
                lastError = nil
                return SpecialEventLoadResult(
                    events: validated.events,
                    dataSource: .localCache,
                    status: .usingCache,
                    lastUpdated: cache.lastUpdated,
                    dataVersion: cache.dataVersion,
                    cacheInfo: cacheService.cacheInfo(),
                    warningMessage: nil,
                    errorMessage: nil,
                    skippedInvalidEventCount: validated.skippedCount
                )
            }

            return try await fullRefresh()
        } catch {
            return await fallback(remoteError: error)
        }
    }

    func loadBundledJSON() async -> SpecialEventLoadResult {
        do {
            let events = try await bundledRepository.fetchSpecialEvents()
            let validated = validator.validate(events)
            skippedInvalidEventCount = validated.skippedCount
            return SpecialEventLoadResult(
                events: validated.events,
                dataSource: .bundledJSON,
                status: .usingBundledJSON,
                lastUpdated: latestUpdatedDate(in: validated.events),
                dataVersion: nil,
                cacheInfo: cacheService.cacheInfo(),
                warningMessage: nil,
                errorMessage: nil,
                skippedInvalidEventCount: validated.skippedCount
            )
        } catch {
            return await fallback(remoteError: error)
        }
    }

    func clearCache() {
        cacheService.clearCache()
    }

    func cacheInfo() -> SpecialEventCacheInfo {
        cacheService.cacheInfo()
    }

    private func fullRefresh() async throws -> SpecialEventLoadResult {
        let page = try await remoteRepository.fetchSpecialEventsPage()
        let validated = validator.validate(page.events)
        let skipped = page.skippedInvalidEventCount + validated.skippedCount
        skippedInvalidEventCount = skipped
        cacheService.saveEvents(validated.events, meta: page.meta, source: .remoteServer)
        lastSuccessfulFetchTime = Date()
        lastError = nil

        return SpecialEventLoadResult(
            events: validated.events,
            dataSource: .remoteServer,
            status: .usingRemote,
            lastUpdated: page.meta?.lastUpdated ?? latestUpdatedDate(in: validated.events) ?? Date(),
            dataVersion: page.meta?.dataVersion,
            cacheInfo: cacheService.cacheInfo(),
            warningMessage: nil,
            errorMessage: nil,
            skippedInvalidEventCount: skipped
        )
    }

    private func incrementalRefresh(cache: CachedSpecialEvents, since: Date) async throws -> SpecialEventLoadResult {
        let payload = try await remoteRepository.syncSpecialEvents(since: since)
        var merged = Dictionary(uniqueKeysWithValues: cache.events.map { ($0.id, $0) })
        payload.updated.forEach { merged[$0.id] = $0 }
        payload.deleted.forEach { merged.removeValue(forKey: $0) }

        let nextEvents = merged.values.sorted { $0.startTime < $1.startTime }
        let validated = validator.validate(nextEvents)
        let skipped = payload.skippedInvalidEventCount + validated.skippedCount
        skippedInvalidEventCount = skipped
        cacheService.saveEvents(validated.events, meta: payload.meta, source: .remoteServer)
        lastSuccessfulFetchTime = Date()
        lastError = nil

        return SpecialEventLoadResult(
            events: validated.events,
            dataSource: .remoteServer,
            status: .usingRemote,
            lastUpdated: payload.meta?.lastUpdated ?? latestUpdatedDate(in: validated.events) ?? Date(),
            dataVersion: payload.meta?.dataVersion ?? cache.dataVersion,
            cacheInfo: cacheService.cacheInfo(),
            warningMessage: nil,
            errorMessage: nil,
            skippedInvalidEventCount: skipped
        )
    }

    private func fallback(remoteError: Error?) async -> SpecialEventLoadResult {
        if let remoteError {
            lastError = remoteError.localizedDescription
        }

        if let cached = cachedResult(), remoteError != nil {
            return SpecialEventLoadResult(
                events: cached.events,
                dataSource: .localCache,
                status: .failedWithFallback,
                lastUpdated: cached.lastUpdated,
                dataVersion: cached.dataVersion,
                cacheInfo: cached.cacheInfo,
                warningMessage: "无法连接事件服务器，当前使用离线缓存。",
                errorMessage: remoteError?.localizedDescription,
                skippedInvalidEventCount: cached.skippedInvalidEventCount
            )
        }

        do {
            let events = try await bundledRepository.fetchSpecialEvents()
            let validated = validator.validate(events)
            skippedInvalidEventCount = validated.skippedCount
            return SpecialEventLoadResult(
                events: validated.events,
                dataSource: .bundledJSON,
                status: remoteError == nil ? .usingBundledJSON : .failedWithFallback,
                lastUpdated: latestUpdatedDate(in: validated.events),
                dataVersion: nil,
                cacheInfo: cacheService.cacheInfo(),
                warningMessage: remoteError == nil ? nil : "无法连接事件服务器，当前使用内置示例数据。",
                errorMessage: remoteError?.localizedDescription,
                skippedInvalidEventCount: validated.skippedCount
            )
        } catch {
            let events = (try? await mockRepository.fetchSpecialEvents()) ?? []
            let validated = validator.validate(events)
            skippedInvalidEventCount = validated.skippedCount
            return SpecialEventLoadResult(
                events: validated.events,
                dataSource: .mock,
                status: events.isEmpty ? .failedNoData : .failedWithFallback,
                lastUpdated: latestUpdatedDate(in: validated.events),
                dataVersion: nil,
                cacheInfo: cacheService.cacheInfo(),
                warningMessage: "离线事件数据加载失败，当前使用 Mock 数据。",
                errorMessage: remoteError?.localizedDescription ?? error.localizedDescription,
                skippedInvalidEventCount: validated.skippedCount
            )
        }
    }

    private func latestUpdatedDate(in events: [SpecialEvent]) -> Date? {
        events.map(\.lastUpdated).max()
    }
}

@MainActor
final class SpecialEventDataService {
    private var config: APIConfig
    private let syncService: SpecialEventSyncService

    init(
        config: APIConfig,
        syncService: SpecialEventSyncService
    ) {
        self.config = config
        self.syncService = syncService
    }

    convenience init(
        config: APIConfig,
        remoteRepository: RemoteSpecialEventRepository,
        bundledRepository: any SpecialEventRepository,
        mockRepository: any SpecialEventRepository,
        cacheService: SpecialEventCacheService
    ) {
        self.init(
            config: config,
            syncService: SpecialEventSyncService(
                config: config,
                remoteRepository: remoteRepository,
                bundledRepository: bundledRepository,
                mockRepository: mockRepository,
                cacheService: cacheService
            )
        )
    }

    var apiConfig: APIConfig { config }
    var lastRemoteFetchTime: Date? { syncService.lastRemoteFetchTime }
    var lastSuccessfulFetchTime: Date? { syncService.lastSuccessfulFetchTime }
    var lastError: String? { syncService.lastError }
    var skippedInvalidEventCount: Int { syncService.skippedInvalidEventCount }

    func updateAPIConfig(_ config: APIConfig) {
        self.config = config
        syncService.updateConfig(config)
    }

    func cachedEvents() -> SpecialEventLoadResult? {
        syncService.cachedResult()
    }

    func refreshEvents() async -> SpecialEventLoadResult {
        await syncService.refresh()
    }

    func eventsForDisplay() async -> SpecialEventLoadResult {
        if let cached = cachedEvents() {
            return cached
        }

        return await refreshEvents()
    }

    func loadBundledJSON() async -> SpecialEventLoadResult {
        await syncService.loadBundledJSON()
    }

    func clearCache() {
        syncService.clearCache()
    }

    func cacheInfo() -> SpecialEventCacheInfo {
        syncService.cacheInfo()
    }
}
