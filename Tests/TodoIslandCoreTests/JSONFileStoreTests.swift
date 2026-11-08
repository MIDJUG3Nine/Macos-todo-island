import XCTest
@testable import TodoIslandCore

final class JSONFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TodoIslandTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileOnFirstLaunch() {
        let store = JSONFileStore<TodoDocument>(fileName: "todos.json", directory: directory)
        guard case .missing = store.load() else {
            return XCTFail("expected .missing")
        }
        XCTAssertEqual(store.loadValue(or: TodoDocument()), TodoDocument())
    }

    func testRoundTripCreatesDirectory() throws {
        let store = JSONFileStore<TodoDocument>(fileName: "todos.json", directory: directory)
        var list = TodoList()
        // Whole seconds: the file stores ISO 8601 dates without fractions.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        list.add("ship v0.1", now: now)
        let item = try XCTUnwrap(list.add("write README", now: now))
        list.toggle(id: item.id, now: now.addingTimeInterval(5))

        try store.save(TodoDocument(list: list))
        guard case .loaded(let doc) = store.load() else {
            return XCTFail("expected .loaded")
        }
        XCTAssertEqual(doc.list, list)
        XCTAssertEqual(doc.version, TodoDocument.currentVersion)
    }

    func testCorruptFileIsMovedAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("todos.json")
        try Data("{ not json".utf8).write(to: url)

        let store = JSONFileStore<TodoDocument>(url: url)
        guard case .recovered(let backup) = store.load() else {
            return XCTFail("expected .recovered")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "{ not json")
        XCTAssertTrue(backup.lastPathComponent.hasPrefix("todos.corrupt-"))
    }

    func testNotesRoundTrip() throws {
        let store = JSONFileStore<NotesDocument>(fileName: "notes.json", directory: directory)
        let doc = NotesDocument(text: "line 1\n第二行", updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        try store.save(doc)
        XCTAssertEqual(store.loadValue(or: NotesDocument()), doc)
    }
}
