import Foundation
import TodoIslandCore

/// Observable wrapper around `TodoList` that saves after every change.
@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var list: TodoList
    /// Shown in the panel when the saved file could not be read or written.
    @Published private(set) var problem: String? = nil

    private let file: JSONFileStore<TodoDocument>

    init(file: JSONFileStore<TodoDocument> = JSONFileStore(fileName: "todos.json")) {
        self.file = file
        switch file.load() {
        case .missing:
            list = TodoList()
        case .loaded(let document):
            list = document.list
        case .recovered(let backup):
            list = TodoList()
            problem = AppLanguage.current.pick(
                en: "Couldn't read your todos. The old file was kept as \(backup.lastPathComponent).",
                zh: "待办文件读取失败，旧文件已保留为 \(backup.lastPathComponent)。"
            )
        }
    }

    @discardableResult
    func add(_ title: String) -> Bool {
        var added = false
        mutate { added = $0.add(title) != nil }
        return added
    }

    func toggle(_ id: UUID) { mutate { $0.toggle(id: id) } }
    func rename(_ id: UUID, to title: String) { mutate { $0.rename(id: id, to: title) } }
    func remove(_ id: UUID) { mutate { $0.remove(id: id) } }
    func clearCompleted() { mutate { $0.clearCompleted() } }

    private func mutate(_ change: (inout TodoList) -> Void) {
        var copy = list
        change(&copy)
        guard copy != list else { return }
        list = copy
        do {
            try file.save(TodoDocument(list: copy))
        } catch {
            problem = AppLanguage.current.pick(
                en: "Couldn't save: \(error.localizedDescription)",
                zh: "保存失败：\(error.localizedDescription)"
            )
        }
    }
}

/// The scratchpad note. Saves shortly after typing stops.
@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var text: String

    private let file: JSONFileStore<NotesDocument>
    private var pendingSave: Task<Void, Never>?

    init(file: JSONFileStore<NotesDocument> = JSONFileStore(fileName: "notes.json")) {
        self.file = file
        text = file.loadValue(or: NotesDocument()).text
    }

    func update(_ newText: String) {
        guard newText != text else { return }
        text = newText
        pendingSave?.cancel()
        pendingSave = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        try? file.save(NotesDocument(text: text, updatedAt: Date()))
    }
}

/// Settings, saved to UserDefaults on every change.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: IslandSettings {
        didSet {
            let fixed = settings.normalized()
            if fixed != settings {
                settings = fixed // runs didSet again, which saves
                return
            }
            store.save(settings)
        }
    }

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        settings = store.load()
    }
}
