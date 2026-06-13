import Foundation

enum FeedbackRating: String, CaseIterable, Identifiable, Codable, Hashable {
    case useful
    case okay
    case notUseful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .useful:
            return "有用"
        case .okay:
            return "一般"
        case .notUseful:
            return "没用"
        }
    }
}

struct Feedback: Identifiable, Codable, Hashable {
    let id: UUID
    var windowId: UUID
    var userId: UUID
    var rating: FeedbackRating
    var comment: String?
    var createdAt: Date
}
