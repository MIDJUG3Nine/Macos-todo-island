import Foundation

/// What is written to `todos.json`.
public struct TodoDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var list: TodoList

    public init(list: TodoList = TodoList()) {
        self.version = Self.currentVersion
        self.list = list
    }
}

/// What is written to `notes.json`. One free-form scratchpad for now.
public struct NotesDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var text: String
    public var updatedAt: Date?

    public init(text: String = "", updatedAt: Date? = nil) {
        self.version = Self.currentVersion
        self.text = text
        self.updatedAt = updatedAt
    }
}
