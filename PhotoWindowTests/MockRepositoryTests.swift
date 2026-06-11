import XCTest
@testable import PhotoWindow

@MainActor
final class MockRepositoryTests: XCTestCase {
    func testFetchWindowsByCategoryFiltersResults() async throws {
        let store = MockRepositoryStore()
        let repository = MockShootingWindowRepository(store: store)

        let astroWindows = try await repository.fetchWindows(for: .astro)

        XCTAssertFalse(astroWindows.isEmpty)
        XCTAssertTrue(astroWindows.allSatisfy { $0.category == .astro })
    }

    func testUpdateWindowPersistsBookmarkChange() async throws {
        let store = MockRepositoryStore()
        let repository = MockShootingWindowRepository(store: store)
        var window = try await repository.fetchWindows().first!
        let originalValue = window.isBookmarked

        window.isBookmarked.toggle()
        try await repository.updateWindow(window)
        let updated = try await repository.fetchWindow(id: window.id)

        XCTAssertNotEqual(originalValue, updated.isBookmarked)
    }

    func testAlertRuleToggleAndDeletePersist() async throws {
        let store = MockRepositoryStore()
        let repository = MockAlertRuleRepository(store: store)
        var rule = try await repository.fetchAlertRules().first!

        rule.isEnabled.toggle()
        try await repository.updateAlertRule(rule)
        let updatedRules = try await repository.fetchAlertRules()

        XCTAssertEqual(updatedRules.first(where: { $0.id == rule.id })?.isEnabled, rule.isEnabled)

        try await repository.deleteAlertRule(id: rule.id)
        let remainingRules = try await repository.fetchAlertRules()

        XCTAssertFalse(remainingRules.contains { $0.id == rule.id })
    }
}
