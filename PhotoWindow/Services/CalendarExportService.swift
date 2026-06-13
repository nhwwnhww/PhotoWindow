import EventKit
import Foundation

struct CalendarExportItem {
    var title: String
    var startTime: Date
    var endTime: Date
    var location: String
    var notes: String
}

struct CalendarShareDebugSnapshot: Codable, Hashable {
    var lastCalendarExportResult: String? = nil
    var lastCalendarExportAt: Date? = nil
    var lastShareURLFetchResult: String? = nil
    var lastShareURLFetchAt: Date? = nil
}

enum CalendarShareDebugStateStore {
    private static let key = "PhotoWindow.calendarShareDebugState.v1"

    static func snapshot(userDefaults: UserDefaults = .standard) -> CalendarShareDebugSnapshot {
        guard let data = userDefaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(CalendarShareDebugSnapshot.self, from: data) else {
            return CalendarShareDebugSnapshot()
        }
        return snapshot
    }

    static func recordCalendarExportResult(_ result: String, userDefaults: UserDefaults = .standard) {
        var snapshot = snapshot(userDefaults: userDefaults)
        snapshot.lastCalendarExportResult = result
        snapshot.lastCalendarExportAt = Date()
        save(snapshot, userDefaults: userDefaults)
    }

    static func recordShareURLResult(_ result: String, userDefaults: UserDefaults = .standard) {
        var snapshot = snapshot(userDefaults: userDefaults)
        snapshot.lastShareURLFetchResult = result
        snapshot.lastShareURLFetchAt = Date()
        save(snapshot, userDefaults: userDefaults)
    }

    private static func save(_ snapshot: CalendarShareDebugSnapshot, userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }
}

enum CalendarExportError: LocalizedError {
    case permissionDenied(String)
    case noWritableCalendar

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let status):
            return "日历权限未开启（\(status)）。请在系统设置中允许 photochaser 写入日历。"
        case .noWritableCalendar:
            return "没有可写入的系统日历。请先在 Calendar 中启用一个日历账户。"
        }
    }
}

@MainActor
final class CalendarExportService {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    static var authorizationStatusDescription: String {
        authorizationStatusDescription(for: EKEventStore.authorizationStatus(for: .event))
    }

    func addEvent(_ item: CalendarExportItem) async throws -> String {
        let granted = try await requestCalendarWriteAccess()
        guard granted else {
            let status = Self.authorizationStatusDescription
            let message = CalendarExportError.permissionDenied(status).localizedDescription
            CalendarShareDebugStateStore.recordCalendarExportResult("failed · \(message)")
            throw CalendarExportError.permissionDenied(status)
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            let message = CalendarExportError.noWritableCalendar.localizedDescription
            CalendarShareDebugStateStore.recordCalendarExportResult("failed · \(message)")
            throw CalendarExportError.noWritableCalendar
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = item.title
        event.startDate = item.startTime
        event.endDate = max(item.endTime, item.startTime.addingTimeInterval(30 * 60))
        event.location = item.location
        event.notes = item.notes
        event.calendar = calendar
        event.availability = .busy

        try eventStore.save(event, span: .thisEvent)
        let eventId = event.eventIdentifier ?? item.title
        CalendarShareDebugStateStore.recordCalendarExportResult("success · \(item.title)")
        return eventId
    }

    private func requestCalendarWriteAccess() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .writeOnly:
            return true
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestWriteOnlyAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func authorizationStatusDescription(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .fullAccess:
            return "fullAccess"
        case .writeOnly:
            return "writeOnly"
        @unknown default:
            return "unknown"
        }
    }
}
