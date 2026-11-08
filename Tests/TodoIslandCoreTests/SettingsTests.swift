import XCTest
@testable import TodoIslandCore

final class SettingsTests: XCTestCase {
    func testDefaultsOpenTodo() {
        let settings = IslandSettings()
        XCTAssertEqual(settings.defaultPanel, .todo)
        XCTAssertEqual(settings.panelToOpen(last: .notes), .todo)
    }

    func testRememberLastPanel() {
        var settings = IslandSettings()
        settings.rememberLastPanel = true
        XCTAssertEqual(settings.panelToOpen(last: .notes), .notes)
        XCTAssertEqual(settings.panelToOpen(last: nil), .todo)
        settings.setPanel(.notes, enabled: false)
        XCTAssertEqual(settings.panelToOpen(last: .notes), .todo)
    }

    func testCannotTurnOffEveryPanel() {
        var settings = IslandSettings()
        settings.setPanel(.todo, enabled: false)
        XCTAssertEqual(settings.enabledPanels, [.notes])
        XCTAssertEqual(settings.defaultPanel, .notes, "default moves to a panel that is still on")
        settings.setPanel(.notes, enabled: false)
        XCTAssertEqual(settings.enabledPanels, [.todo])
        XCTAssertEqual(settings.defaultPanel, .todo)
    }

    func testNormalizedOrdersDedupesAndClamps() {
        let settings = IslandSettings(
            enabledPanels: [.notes, .todo, .notes],
            hoverDelay: 99,
            collapseDelay: -3
        ).normalized()
        XCTAssertEqual(settings.enabledPanels, [.todo, .notes])
        XCTAssertEqual(settings.hoverDelay, IslandSettings.hoverDelayRange.upperBound)
        XCTAssertEqual(settings.collapseDelay, 0)
    }

    func testDecodingOldOrPartialJSONKeepsDefaults() throws {
        let json = Data(#"{"defaultPanel":"notes","enabledPanels":["notes","calendar"]}"#.utf8)
        let settings = try JSONDecoder().decode(IslandSettings.self, from: json)
        XCTAssertEqual(settings.defaultPanel, .notes)
        XCTAssertEqual(settings.enabledPanels, [.notes], "unknown panels are dropped")
        XCTAssertEqual(settings.hoverDelay, IslandSettings().hoverDelay)
        XCTAssertEqual(settings.panelSize, .regular)
        XCTAssertEqual(settings.todoSource, .local)
        XCTAssertNil(settings.remindersListID)
    }

    func testTodoSourceRoundTrip() throws {
        var settings = IslandSettings()
        settings.todoSource = .reminders
        settings.remindersListID = "ABC-123"
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(IslandSettings.self, from: data), settings)

        let unknown = Data(#"{"todoSource":"notion"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(IslandSettings.self, from: unknown).todoSource, .local)
    }

    func testStoreRoundTripAndGarbage() throws {
        let suite = "TodoIslandTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), IslandSettings())

        var settings = IslandSettings()
        settings.panelSize = .large
        settings.hoverDelay = 0.5
        store.save(settings)
        XCTAssertEqual(store.load(), settings)

        defaults.set(Data("garbage".utf8), forKey: SettingsStore.key)
        XCTAssertEqual(store.load(), IslandSettings())
    }

    func testLanguageDetection() {
        XCTAssertEqual(AppLanguage.detect(from: ["zh-Hans-CN", "en"]), .chinese)
        XCTAssertEqual(AppLanguage.detect(from: ["en-MY", "zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.detect(from: []), .english)
        XCTAssertEqual(AppLanguage.chinese.pick(en: "Todo", zh: "待办"), "待办")
        XCTAssertEqual(PanelID.notes.title(.english), "Notes")
    }
}
