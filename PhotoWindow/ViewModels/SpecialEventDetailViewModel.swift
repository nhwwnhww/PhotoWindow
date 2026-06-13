import Foundation
import Combine

@MainActor
final class SpecialEventDetailViewModel: ObservableObject {
    @Published private(set) var event: SpecialEvent?
    @Published private(set) var shootingWindow: ShootingWindow?
    @Published private(set) var isLoading = false
    @Published private(set) var isAlertEnabled = false
    @Published private(set) var isBookmarked = false
    @Published var errorMessage: String?
    @Published private(set) var isExportingCalendar = false
    @Published private(set) var exportMessage: String?

    private let eventID: UUID
    private let specialEventRepository: any SpecialEventRepository
    private let specialEventDataService: SpecialEventDataService
    private let shootingWindowRepository: any ShootingWindowRepository
    private let weatherRepository: any WeatherRepository
    private let astronomyRepository: any AstronomyRepository
    private let alertRuleRepository: any AlertRuleRepository
    private let userRepository: any UserRepository
    private let notificationService: any NotificationServicing
    private let calendarExportService: CalendarExportService
    private let generationService = ShootingWindowGenerationService()

    init(
        eventID: UUID,
        specialEventRepository: any SpecialEventRepository,
        specialEventDataService: SpecialEventDataService,
        shootingWindowRepository: any ShootingWindowRepository,
        weatherRepository: any WeatherRepository,
        astronomyRepository: any AstronomyRepository,
        alertRuleRepository: any AlertRuleRepository,
        userRepository: any UserRepository,
        notificationService: any NotificationServicing,
        calendarExportService: CalendarExportService
    ) {
        self.eventID = eventID
        self.specialEventRepository = specialEventRepository
        self.specialEventDataService = specialEventDataService
        self.shootingWindowRepository = shootingWindowRepository
        self.weatherRepository = weatherRepository
        self.astronomyRepository = astronomyRepository
        self.alertRuleRepository = alertRuleRepository
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.calendarExportService = calendarExportService
    }

    var recommendationText: String {
        shootingWindow?.recommendationText ?? event?.description ?? ""
    }

    var reasonTags: [String] {
        shootingWindow?.reasonTags ?? event.map { [$0.eventReasonTag, $0.importanceLevel.badgeText, "可信度\($0.confidenceLevel.displayName)"] } ?? []
    }

    var sourceUpdatedText: String {
        guard let event else { return "" }
        return event.lastUpdated.formatted(date: .abbreviated, time: .shortened)
    }

    var eventTimeText: String {
        guard let event else { return "" }
        return "\(event.startTime.formatted(date: .abbreviated, time: .shortened)) - \(event.endTime.formatted(date: .omitted, time: .shortened))"
    }

    var reminderLeadText: String {
        guard let shootingWindow else { return "提前 1 小时" }
        return "提前 \(Self.formatReminderLead(minutes: shootingWindow.defaultReminderLeadMinutes))"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let events = await specialEventDataService.eventsForDisplay().events
            guard let fetchedEvent = events.first(where: { $0.id == eventID }) else {
                throw RepositoryError.notFound
            }

            event = fetchedEvent
            let window = try await associatedWindow(for: fetchedEvent)
            shootingWindow = window
            isAlertEnabled = window?.alertEnabled ?? false
            isBookmarked = window?.isBookmarked ?? false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAlert() async {
        guard let event else { return }

        do {
            guard var window = try await associatedWindow(for: event) else {
                throw RepositoryError.notFound
            }
            window.alertEnabled.toggle()
            isAlertEnabled = window.alertEnabled

            if window.alertEnabled {
                let item = notificationItem(for: event, window: window)
                let granted = await notificationService.requestAuthorization()
                if granted {
                    try await notificationService.schedule(notification: item)
                }
            } else {
                notificationService.cancel(notificationId: window.id)
            }

            try await syncAlertRule(for: event, window: window)
            try await persist(window)
            shootingWindow = window
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleBookmark() async {
        do {
            guard var window = shootingWindow else {
                isBookmarked.toggle()
                return
            }

            window.isBookmarked.toggle()
            try await persist(window)
            shootingWindow = window
            isBookmarked = window.isBookmarked
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addToCalendar() async {
        guard let event else { return }

        isExportingCalendar = true
        defer { isExportingCalendar = false }

        do {
            _ = try await calendarExportService.addEvent(calendarItem(for: event))
            exportMessage = "已加入系统日历。"
            errorMessage = nil
        } catch {
            exportMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func shareActivityItems() -> [Any] {
        guard let card = shareCard() else { return [] }
        CalendarShareDebugStateStore.recordShareURLResult(card.shareURLResultText)
        exportMessage = "分享卡片已准备。"
        return card.activityItems
    }

    func copyPlanText() -> String? {
        guard let card = shareCard() else { return nil }
        exportMessage = "拍摄计划已复制。"
        return card.text
    }

    static func formatReminderLead(minutes: Int) -> String {
        if minutes == 1_500 {
            return "1 天 + 1 小时"
        }

        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440) 天"
        }

        if minutes % 60 == 0 {
            return "\(minutes / 60) 小时"
        }

        return "\(minutes) 分钟"
    }

    private func associatedWindow(for event: SpecialEvent) async throws -> ShootingWindow? {
        let existingWindows = try await shootingWindowRepository.fetchWindows()
        if let existing = existingWindows.first(where: { window in
            window.eventRefs.contains { $0.id == event.id }
        }) {
            return existing
        }

        let knownLocations = try await shootingWindowRepository.fetchLocations()
        let location = event.resolvedLocation(knownLocations: knownLocations)
        let weatherSnapshots = try await weatherRepository.fetchWeather(for: location)
        let astronomySnapshot = try await astronomyRepository.fetchAstronomy(for: location, date: event.startTime)
        let generated = generationService.generateWindows(
            location: location,
            weatherSnapshots: weatherSnapshots,
            astronomySnapshots: [astronomySnapshot],
            category: event.category,
            specialEvents: [event]
        )
        .first { window in
            window.eventRefs.contains { $0.id == event.id }
        }

        if let generated {
            try await persist(generated, appendIfMissing: true)
        }

        return generated
    }

    private func calendarItem(for event: SpecialEvent) -> CalendarExportItem {
        CalendarExportItem(
            title: "photochaser：\(event.title)",
            startTime: event.startTime,
            endTime: event.endTime,
            location: event.locationName,
            notes: calendarNotes(for: event)
        )
    }

    private func calendarNotes(for event: SpecialEvent) -> String {
        var lines = [
            "推荐原因：\(recommendationText)",
            "sourceName：\(SharePlanComposer.sourceName(for: event))"
        ]

        if let shootingWindow {
            lines.insert("推荐等级：\(shootingWindow.scoreLevel.displayName) · \(shootingWindow.score)/100", at: 1)
            lines.insert("天气摘要：\(SharePlanComposer.weatherSummary(shootingWindow.weatherSnapshot))", at: 2)
        } else {
            lines.insert("推荐等级：\(event.importanceLevel.displayName) · 可信度\(event.confidenceLevel.displayName)", at: 1)
            lines.insert("天气摘要：暂未生成关联 ShootingWindow。", at: 2)
        }

        return lines.joined(separator: "\n")
    }

    private func shareCard() -> SharePlanCard? {
        guard let event else { return nil }
        return SharePlanCard(
            title: event.title,
            timeText: eventTimeText,
            locationText: event.locationName,
            scoreText: shareScoreText(for: event),
            reasonText: recommendationText,
            sourceName: SharePlanComposer.sourceName(for: event),
            shareURL: SharePlanComposer.shareURL(for: event)
        )
    }

    private func shareScoreText(for event: SpecialEvent) -> String {
        if let shootingWindow {
            return "\(shootingWindow.scoreLevel.displayName) · \(shootingWindow.score)/100"
        }
        return "\(event.importanceLevel.displayName) · 可信度\(event.confidenceLevel.displayName)"
    }

    private func notificationItem(for event: SpecialEvent, window: ShootingWindow) -> NotificationItem {
        let leadMinutes = window.defaultReminderLeadMinutes
        let triggerTime = window.startTime.addingTimeInterval(-Double(60 * leadMinutes))

        return NotificationItem(
            id: window.id,
            title: notificationTitle(for: event),
            body: notificationBody(for: event, window: window, leadMinutes: leadMinutes),
            triggerTime: triggerTime,
            relatedWindow: window,
            isRead: false,
            createdAt: Date()
        )
    }

    private func notificationTitle(for event: SpecialEvent) -> String {
        if event.importanceLevel == .mustShoot {
            return "必拍事件：\(event.title)"
        }

        if event.importanceLevel == .rare {
            return "稀有事件：\(event.title)"
        }

        return "特殊事件：\(event.title)"
    }

    private func notificationBody(
        for event: SpecialEvent,
        window: ShootingWindow,
        leadMinutes: Int
    ) -> String {
        let time = "\(event.startTime.formatted(date: .omitted, time: .shortened))-\(event.endTime.formatted(date: .omitted, time: .shortened))"
        let weather = window.weatherSnapshot
        let lead = Self.formatReminderLead(minutes: leadMinutes)
        return "\(time)，云量 \(Int(weather.cloudCover))%，降雨 \(Int(weather.precipitationProbability))%，能见度 \(Int(weather.visibility)) km。建议提前 \(lead) 到场。"
    }

    private func syncAlertRule(for event: SpecialEvent, window: ShootingWindow) async throws {
        let user = try await userRepository.fetchCurrentUser()
        let rule = AlertRule(
            id: event.id,
            userId: user.id,
            category: event.category,
            location: window.location,
            eventType: event.eventType,
            minScore: min(75, window.score),
            remindBeforeMinutes: window.defaultReminderLeadMinutes,
            isEnabled: window.alertEnabled,
            keywords: ([event.eventReasonTag, event.title] + event.tags).removingDuplicates()
        )
        try await alertRuleRepository.upsertAlertRule(rule)
    }

    private func persist(_ window: ShootingWindow, appendIfMissing: Bool = false) async throws {
        do {
            try await shootingWindowRepository.updateWindow(window)
        } catch {
            guard appendIfMissing else { throw error }
            let existing = try await shootingWindowRepository.fetchWindows()
            if existing.contains(where: { $0.id == window.id }) {
                throw error
            }
            try await shootingWindowRepository.replaceWindows(existing + [window])
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
