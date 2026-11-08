import Foundation

/// Where the todo panel reads and writes its items.
public enum TodoSource: String, CaseIterable, Codable, Identifiable, Sendable {
    /// `todos.json` on this Mac.
    case local
    /// A list in Apple Reminders (syncs with iPhone through iCloud).
    case reminders

    public var id: String { rawValue }

    public func title(_ language: AppLanguage) -> String {
        switch self {
        case .local: return language.pick(en: "On this Mac", zh: "本机")
        case .reminders: return language.pick(en: "Apple Reminders", zh: "Apple 提醒事项")
        }
    }
}

/// A plain copy of one item from an outside source such as Apple Reminders.
public struct ExternalTodo: Equatable, Sendable {
    public var externalID: String
    public var title: String
    public var isDone: Bool
    public var createdAt: Date?
    public var completedAt: Date?

    public init(externalID: String, title: String, isDone: Bool, createdAt: Date? = nil, completedAt: Date? = nil) {
        self.externalID = externalID
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Gives each outside item a UUID that stays the same for the life of the app, so SwiftUI
/// rows keep their identity across refreshes.
public struct ExternalIDMap: Sendable {
    private var uuids: [String: UUID] = [:]
    private var externals: [UUID: String] = [:]

    public init() {}

    public mutating func uuid(for externalID: String) -> UUID {
        if let existing = uuids[externalID] { return existing }
        let id = UUID()
        uuids[externalID] = id
        externals[id] = externalID
        return id
    }

    public func externalID(for uuid: UUID) -> String? {
        externals[uuid]
    }
}

public enum ExternalTodoMapping {
    /// Builds the panel's list from outside items: newest open items first (like the local
    /// list), blank titles shown as a placeholder, and finished items the user cleared hidden.
    public static func list(
        from todos: [ExternalTodo],
        ids: inout ExternalIDMap,
        hiddenDone: Set<String> = [],
        untitled: String = "Untitled"
    ) -> TodoList {
        let visible = todos.filter { !($0.isDone && hiddenDone.contains($0.externalID)) }
        let sorted = visible.sorted { a, b in
            let da = a.createdAt ?? .distantPast
            let db = b.createdAt ?? .distantPast
            if da != db { return da > db }
            return a.externalID < b.externalID
        }
        let items = sorted.map { todo in
            TodoItem(
                id: ids.uuid(for: todo.externalID),
                title: TodoList.cleanTitle(todo.title) ?? untitled,
                isDone: todo.isDone,
                createdAt: todo.createdAt ?? .distantPast,
                completedAt: todo.isDone ? (todo.completedAt ?? todo.createdAt ?? .distantPast) : nil
            )
        }
        return TodoList(items: items)
    }

    /// Finished items are fetched from this moment on (start of today), so the panel shows
    /// what you ticked off today without pulling in years of history.
    public static func completedSince(now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }
}
