import XCTest
@testable import TodoIslandCore

final class ExternalTodosTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testIDsAreStableAcrossRefreshes() {
        var ids = ExternalIDMap()
        let first = ids.uuid(for: "r1")
        XCTAssertEqual(ids.uuid(for: "r1"), first)
        XCTAssertNotEqual(ids.uuid(for: "r2"), first)
        XCTAssertEqual(ids.externalID(for: first), "r1")
        XCTAssertNil(ids.externalID(for: UUID()))
    }

    func testMappingSortsNewestFirstAndKeepsIdentity() {
        var ids = ExternalIDMap()
        let todos = [
            ExternalTodo(externalID: "old", title: "Old", isDone: false, createdAt: t0),
            ExternalTodo(externalID: "new", title: "New", isDone: false, createdAt: t0.addingTimeInterval(60)),
            ExternalTodo(externalID: "done", title: "Done", isDone: true, createdAt: t0, completedAt: t0.addingTimeInterval(5)),
        ]
        let list = ExternalTodoMapping.list(from: todos, ids: &ids)
        XCTAssertEqual(list.displayItems.map(\.title), ["New", "Old", "Done"])
        XCTAssertEqual(list.openCount, 2)

        let again = ExternalTodoMapping.list(from: todos.reversed(), ids: &ids)
        XCTAssertEqual(again.items.map(\.id), list.items.map(\.id))
    }

    func testBlankTitleAndMissingDates() {
        var ids = ExternalIDMap()
        let list = ExternalTodoMapping.list(
            from: [ExternalTodo(externalID: "x", title: "  ", isDone: true)],
            ids: &ids,
            untitled: "无标题"
        )
        let item = list.items[0]
        XCTAssertEqual(item.title, "无标题")
        XCTAssertEqual(item.createdAt, .distantPast)
        XCTAssertEqual(item.completedAt, .distantPast, "done items always get a completion date")
    }

    func testHiddenDoneItemsAreFilteredButOpenOnesStay() {
        var ids = ExternalIDMap()
        let todos = [
            ExternalTodo(externalID: "a", title: "A", isDone: true, createdAt: t0),
            ExternalTodo(externalID: "b", title: "B", isDone: false, createdAt: t0),
        ]
        let list = ExternalTodoMapping.list(from: todos, ids: &ids, hiddenDone: ["a", "b"])
        XCTAssertEqual(list.items.map(\.title), ["B"], "only finished items can be hidden")
    }

    func testCompletedSinceIsStartOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kuala_Lumpur"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 17, minute: 30)))
        let start = ExternalTodoMapping.completedSince(now: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start),
                       DateComponents(year: 2026, month: 11, day: 8, hour: 0, minute: 0))
    }
}
