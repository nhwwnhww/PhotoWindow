import Foundation

struct SpecialEventDeduplicationService {
    func deduplicated(_ events: [SpecialEvent]) -> [SpecialEvent] {
        var results: [SpecialEvent] = []

        for event in events.sorted(by: preferredSort) {
            if let index = results.firstIndex(where: { shouldMerge($0, event) }) {
                results[index] = mergedPreferred(results[index], event)
            } else {
                results.append(event)
            }
        }

        return results.sorted {
            if $0.startTime == $1.startTime {
                return preferredSort($0, $1)
            }
            return $0.startTime < $1.startTime
        }
    }

    private func shouldMerge(_ lhs: SpecialEvent, _ rhs: SpecialEvent) -> Bool {
        guard lhs.locationId == rhs.locationId else { return false }
        guard lhs.category == rhs.category else { return false }
        guard overlaps(lhs.startTime...lhs.endTime, rhs.startTime...rhs.endTime) else { return false }

        return hasSimilarTitle(lhs.title, rhs.title) || hasSimilarTags(lhs.tags, rhs.tags)
    }

    private func mergedPreferred(_ lhs: SpecialEvent, _ rhs: SpecialEvent) -> SpecialEvent {
        var preferred = preferredSort(lhs, rhs) ? lhs : rhs
        preferred.tags = (lhs.tags + rhs.tags + [lhs.eventReasonTag, rhs.eventReasonTag]).removingDuplicateStrings()

        if rhs.description.count > preferred.description.count && preferred.id == lhs.id {
            preferred.description = rhs.description
        } else if lhs.description.count > preferred.description.count && preferred.id == rhs.id {
            preferred.description = lhs.description
        }

        return preferred
    }

    private func preferredSort(_ lhs: SpecialEvent, _ rhs: SpecialEvent) -> Bool {
        if lhs.importanceLevel.rank != rhs.importanceLevel.rank {
            return lhs.importanceLevel.rank > rhs.importanceLevel.rank
        }

        if lhs.confidenceLevel.rank != rhs.confidenceLevel.rank {
            return lhs.confidenceLevel.rank > rhs.confidenceLevel.rank
        }

        if lhs.lastUpdated != rhs.lastUpdated {
            return lhs.lastUpdated > rhs.lastUpdated
        }

        return lhs.title < rhs.title
    }

    private func hasSimilarTags(_ lhs: [String], _ rhs: [String]) -> Bool {
        let lhsTags = Set(lhs.map { $0.lowercased() })
        let rhsTags = Set(rhs.map { $0.lowercased() })
        return !lhsTags.intersection(rhsTags).isEmpty
    }

    private func hasSimilarTitle(_ lhs: String, _ rhs: String) -> Bool {
        let lhsTokens = Set(tokens(from: lhs))
        let rhsTokens = Set(tokens(from: rhs))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else {
            return lhs.lowercased().contains(rhs.lowercased()) || rhs.lowercased().contains(lhs.lowercased())
        }

        let overlap = lhsTokens.intersection(rhsTokens).count
        let union = lhsTokens.union(rhsTokens).count
        return Double(overlap) / Double(union) >= 0.35
    }

    private func tokens(from text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    private func overlaps(_ lhs: ClosedRange<Date>, _ rhs: ClosedRange<Date>) -> Bool {
        lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
    }
}

private extension EventImportanceLevel {
    var rank: Int {
        switch self {
        case .normal:
            return 0
        case .worthWatching:
            return 1
        case .rare:
            return 2
        case .mustShoot:
            return 3
        }
    }
}

private extension Array where Element == String {
    func removingDuplicateStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
