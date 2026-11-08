import XCTest
@testable import TodoIslandCore

final class TodoListTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testAddPutsNewItemOnTopAndTrims() {
        var list = TodoList()
        list.add("first", now: t0)
        let second = list.add("  second  ", now: t0)
        XCTAssertEqual(second?.title, "second")
        XCTAssertEqual(list.items.map(\.title), ["second", "first"])
        XCTAssertEqual(list.openCount, 2)
    }

    func testAddRejectsBlankInput() {
        var list = TodoList()
        XCTAssertNil(list.add(""))
        XCTAssertNil(list.add("   \n\t "))
        XCTAssertTrue(list.isEmpty)
    }

    func testCleanTitleJoinsLinesAndCapsLength() {
        XCTAssertEqual(TodoList.cleanTitle("buy\n  milk \n"), "buy milk")
        let long = String(repeating: "a", count: TodoList.maxTitleLength + 50)
        XCTAssertEqual(TodoList.cleanTitle(long)?.count, TodoList.maxTitleLength)
    }

    func testToggleSetsAndClearsCompletedDate() throws {
        var list = TodoList()
        let item = try XCTUnwrap(list.add("write tests", now: t0))
        list.toggle(id: item.id, now: t0.addingTimeInterval(60))
        XCTAssertEqual(list.item(id: item.id)?.isDone, true)
        XCTAssertEqual(list.item(id: item.id)?.completedAt, t0.addingTimeInterval(60))
        XCTAssertEqual(list.openCount, 0)
        XCTAssertEqual(list.doneCount, 1)

        list.toggle(id: item.id)
        XCTAssertEqual(list.item(id: item.id)?.isDone, false)
        XCTAssertNil(list.item(id: item.id)?.completedAt)
    }

    func testToggleUnknownIDDoesNothing() {
        var list = TodoList()
        list.add("a")
        let before = list
        list.toggle(id: UUID())
        XCTAssertEqual(list, before)
    }

    func testDisplayItemsShowOpenFirstThenNewestDone() throws {
        var list = TodoList()
        let a = try XCTUnwrap(list.add("a", now: t0))
        let b = try XCTUnwrap(list.add("b", now: t0))
        let c = try XCTUnwrap(list.add("c", now: t0))
        _ = c
        list.toggle(id: a.id, now: t0.addingTimeInterval(10))
        list.toggle(id: b.id, now: t0.addingTimeInterval(20))
        XCTAssertEqual(list.displayItems.map(\.title), ["c", "b", "a"])

        list.toggle(id: a.id, now: t0.addingTimeInterval(30)) // reopen a
        XCTAssertEqual(list.displayItems.map(\.title), ["c", "a", "b"])
    }

    func testRenameIgnoresBlank() throws {
        var list = TodoList()
        let item = try XCTUnwrap(list.add("old"))
        list.rename(id: item.id, to: "  ")
        XCTAssertEqual(list.item(id: item.id)?.title, "old")
        list.rename(id: item.id, to: " new ")
        XCTAssertEqual(list.item(id: item.id)?.title, "new")
    }

    func testRemoveAndClearCompleted() throws {
        var list = TodoList()
        let a = try XCTUnwrap(list.add("a"))
        let b = try XCTUnwrap(list.add("b"))
        let c = try XCTUnwrap(list.add("c"))
        list.remove(id: b.id)
        XCTAssertEqual(list.items.map(\.title), ["c", "a"])

        list.toggle(id: a.id)
        list.toggle(id: c.id)
        XCTAssertEqual(list.clearCompleted(), 2)
        XCTAssertTrue(list.isEmpty)
    }

    func testMove() throws {
        var list = TodoList()
        let a = try XCTUnwrap(list.add("a"))
        let b = try XCTUnwrap(list.add("b"))
        let c = try XCTUnwrap(list.add("c"))
        // order: c b a
        list.move(id: a.id, before: c.id)
        XCTAssertEqual(list.items.map(\.title), ["a", "c", "b"])
        list.move(id: a.id, before: nil)
        XCTAssertEqual(list.items.map(\.title), ["c", "b", "a"])
        list.move(id: b.id, before: b.id)
        XCTAssertEqual(list.items.map(\.title), ["c", "b", "a"])
    }
}
