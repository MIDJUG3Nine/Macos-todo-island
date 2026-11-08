import Foundation

/// One item on the todo list.
public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// The todo list as a plain value. All editing rules live here so they can be tested
/// without any UI.
public struct TodoList: Codable, Equatable, Sendable {
    /// Longest title we accept. Longer input is cut, not rejected.
    public static let maxTitleLength = 500

    /// Items in the order the user arranged them. New items go to the top.
    public private(set) var items: [TodoItem]

    public init(items: [TodoItem] = []) {
        self.items = items
    }

    // MARK: Reading

    /// Open items first (in list order), then finished items, most recently finished first.
    public var displayItems: [TodoItem] {
        let open = items.filter { !$0.isDone }
        let done = items.filter(\.isDone).sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
        return open + done
    }

    public var openCount: Int { items.lazy.filter { !$0.isDone }.count }
    public var doneCount: Int { items.count - openCount }
    public var isEmpty: Bool { items.isEmpty }

    public func item(id: UUID) -> TodoItem? {
        items.first { $0.id == id }
    }

    // MARK: Editing

    /// Adds a new open item at the top. Returns nil (and changes nothing) for blank input.
    @discardableResult
    public mutating func add(_ title: String, now: Date = Date()) -> TodoItem? {
        guard let clean = Self.cleanTitle(title) else { return nil }
        let item = TodoItem(title: clean, createdAt: now)
        items.insert(item, at: 0)
        return item
    }

    /// Flips an item between open and done.
    public mutating func toggle(id: UUID, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
        items[index].completedAt = items[index].isDone ? now : nil
    }

    /// Renames an item. Blank input is ignored so a stray Enter never wipes a title.
    public mutating func rename(id: UUID, to title: String) {
        guard let clean = Self.cleanTitle(title),
              let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = clean
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Removes every finished item and returns how many were removed.
    @discardableResult
    public mutating func clearCompleted() -> Int {
        let before = items.count
        items.removeAll(where: \.isDone)
        return before - items.count
    }

    /// Moves the item with `id` so that it sits just before the item with `beforeID`
    /// (or at the end when `beforeID` is nil).
    public mutating func move(id: UUID, before beforeID: UUID?) {
        guard id != beforeID, let from = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: from)
        if let beforeID, let to = items.firstIndex(where: { $0.id == beforeID }) {
            items.insert(item, at: to)
        } else {
            items.append(item)
        }
    }

    // MARK: Helpers

    /// Trims whitespace, joins lines and caps the length. Returns nil when nothing is left.
    public static func cleanTitle(_ raw: String) -> String? {
        let oneLine = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !oneLine.isEmpty else { return nil }
        return String(oneLine.prefix(maxTitleLength))
    }
}
