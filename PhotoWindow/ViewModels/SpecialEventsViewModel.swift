import Foundation
import Combine

struct SpecialEventSection: Identifiable, Hashable {
    let id: String
    var title: String
    var events: [SpecialEvent]
}

@MainActor
final class SpecialEventsViewModel: ObservableObject {
    @Published private(set) var sections: [SpecialEventSection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var dataSource: SpecialEventDataSource = .bundledJSON
    @Published private(set) var syncState: SpecialEventSyncState = .loading
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var dataVersion: String?
    @Published private(set) var cacheInfo: SpecialEventCacheInfo?
    @Published private(set) var lastError: String?
    @Published private(set) var skippedInvalidEventCount = 0
    @Published private(set) var dataSourceWarningMessage: String?
    @Published var errorMessage: String?

    private let eventWatchlistRepository: any EventWatchlistRepository
    private let specialEventDataService: SpecialEventDataService
    private let deduplicationService = SpecialEventDeduplicationService()
    private let calendar: Calendar
    private var watchlistItems: [EventWatchlistItem] = []

    init(
        specialEventRepository: any SpecialEventRepository,
        specialEventDataService: SpecialEventDataService,
        eventWatchlistRepository: any EventWatchlistRepository,
        calendar: Calendar = .current
    ) {
        self.eventWatchlistRepository = eventWatchlistRepository
        self.specialEventDataService = specialEventDataService
        self.calendar = calendar
    }

    var dataSourceText: String {
        var text = "事件数据来自：\(dataSource.displayName)"

        if let dataVersion {
            text += " · 版本 \(dataVersion)"
        }

        if let lastUpdated {
            text += " · 更新于 \(lastUpdated.formatted(date: .abbreviated, time: .shortened))"
        }

        return text
    }

    var statusText: String {
        [
            dataSourceText,
            "同步状态：\(syncState.displayName)",
            skippedInvalidEventCount > 0 ? "已跳过 \(skippedInvalidEventCount) 条无效事件" : nil
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    func load() async {
        isLoading = true

        do {
            watchlistItems = try await eventWatchlistRepository.fetchWatchlistItems()

            if let cachedResult = specialEventDataService.cachedEvents() {
                apply(cachedResult)
                isLoading = false
                await refreshInBackground()
            } else {
                apply(await specialEventDataService.refreshEvents())
                isLoading = false
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        apply(await specialEventDataService.refreshEvents())
        isLoading = false
    }

    func watchlistHitText(for event: SpecialEvent) -> String? {
        let hits = watchlistItems
            .filter { $0.isEnabled && $0.category == event.category && event.matches(keyword: $0.keyword) }
            .map(\.displayName)
            .removingDuplicates()

        guard !hits.isEmpty else { return nil }
        return "命中关注：\(hits.joined(separator: "、"))"
    }

    private func makeSections(from events: [SpecialEvent]) -> [SpecialEventSection] {
        let sortedEvents = deduplicationService
            .deduplicated(events)
            .sorted { priority(for: $0) > priority(for: $1) }
        let today = sortedEvents.filter { calendar.isDateInToday($0.startTime) }
        let tomorrow = sortedEvents.filter { calendar.isDateInTomorrow($0.startTime) }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(7 * 24 * 60 * 60)
        let thisWeek = sortedEvents.filter {
            !calendar.isDateInToday($0.startTime) &&
            !calendar.isDateInTomorrow($0.startTime) &&
            $0.startTime <= weekEnd
        }

        return [
            SpecialEventSection(id: "today", title: "Today", events: today),
            SpecialEventSection(id: "tomorrow", title: "Tomorrow", events: tomorrow),
            SpecialEventSection(id: "this-week", title: "This Week", events: thisWeek)
        ]
        .filter { !$0.events.isEmpty }
    }

    private func refreshInBackground() async {
        apply(await specialEventDataService.refreshEvents())
    }

    private func apply(_ result: SpecialEventLoadResult) {
        sections = makeSections(from: result.events)
        dataSource = result.dataSource
        syncState = result.status
        lastUpdated = result.lastUpdated
        dataVersion = result.dataVersion
        cacheInfo = result.cacheInfo
        lastError = result.errorMessage
        skippedInvalidEventCount = result.skippedInvalidEventCount
        dataSourceWarningMessage = result.warningMessage
        errorMessage = nil
    }

    private func priority(for event: SpecialEvent) -> Int {
        var priority = Int(event.importanceLevel.scoreWeight) * 5
        priority += event.confidenceLevel.rank * 15

        if event.importanceLevel == .mustShoot || event.importanceLevel == .rare {
            priority += 45
        }

        if watchlistItems.contains(where: { $0.isEnabled && $0.category == event.category && event.matches(keyword: $0.keyword) }) {
            priority += 60
        }

        let hoursAway = max(0, event.startTime.timeIntervalSince(Date()) / 3_600)
        priority += max(0, 72 - Int(hoursAway))
        return priority
    }
}

private extension SpecialEvent {
    func matches(keyword: String) -> Bool {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKeyword.isEmpty else { return false }

        let searchableText = ([title, description] + tags)
            .joined(separator: " ")
            .lowercased()
        return searchableText.contains(normalizedKeyword)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
