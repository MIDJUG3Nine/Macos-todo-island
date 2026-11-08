import Foundation
import TodoIslandCore

/// The todo list the panel shows. Backed by `todos.json` (default) or an Apple Reminders
/// list, chosen in Settings. Local edits save after every change.
@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var list: TodoList
    /// Shown in the panel when something went wrong (unreadable file, no Reminders access...).
    @Published private(set) var problem: String? = nil
    @Published private(set) var source: TodoSource = .local
    /// Name of the Reminders list in use, for the panel footer.
    @Published private(set) var remindersListTitle: String? = nil
    /// Lists offered in Settings (filled once Reminders access is granted).
    @Published private(set) var reminderLists: [ReminderListInfo] = []

    private let file: JSONFileStore<TodoDocument>
    private let language = AppLanguage.current
    private var localList: TodoList
    private var localProblem: String?

    private let reminders = RemindersSource()
    private var remindersListID: String?
    private var externalIDs = ExternalIDMap()
    private var hiddenDone = Set<String>()
    private var externalTodos: [ExternalTodo] = []
    private var refreshTask: Task<Void, Never>?

    init(file: JSONFileStore<TodoDocument> = JSONFileStore(fileName: "todos.json")) {
        self.file = file
        let loaded: TodoList
        var loadProblem: String?
        switch file.load() {
        case .missing:
            loaded = TodoList()
        case .loaded(let document):
            loaded = document.list
        case .recovered(let backup):
            loaded = TodoList()
            loadProblem = AppLanguage.current.pick(
                en: "Couldn't read your todos. The old file was kept as \(backup.lastPathComponent).",
                zh: "待办文件读取失败，旧文件已保留为 \(backup.lastPathComponent)。"
            )
        }
        localList = loaded
        localProblem = loadProblem
        list = loaded
        problem = loadProblem
        reminders.onExternalChange = { [weak self] in self?.refreshReminders() }
    }

    // MARK: Source

    /// Switches between the local file and Apple Reminders. Safe to call repeatedly.
    func configure(source newSource: TodoSource, remindersListID newListID: String?) {
        let changed = newSource != source || newListID != remindersListID
        source = newSource
        remindersListID = newListID
        guard changed else { return }

        switch newSource {
        case .local:
            refreshTask?.cancel()
            remindersListTitle = nil
            list = localList
            problem = localProblem
        case .reminders:
            hiddenDone = []
            externalTodos = []
            list = TodoList()
            problem = nil
            connectReminders()
        }
    }

    private func connectReminders() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.reminders.requestAccess()
            } catch {
                guard self.source == .reminders else { return }
                self.problem = self.accessMessage(for: error)
                return
            }
            await self.reloadReminders()
        }
    }

    private func refreshReminders() {
        guard source == .reminders, RemindersSource.hasAccess else { return }
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await self?.reloadReminders()
        }
    }

    private func reloadReminders() async {
        reminderLists = reminders.lists()
        remindersListTitle = reminders.listTitle(listID: remindersListID)
        let fetched = await reminders.fetch(listID: remindersListID)
        guard !Task.isCancelled, source == .reminders else { return }
        externalTodos = fetched
        problem = nil
        rebuildFromReminders()
    }

    private func rebuildFromReminders() {
        list = ExternalTodoMapping.list(
            from: externalTodos,
            ids: &externalIDs,
            hiddenDone: hiddenDone,
            untitled: language.pick(en: "Untitled", zh: "无标题")
        )
    }

    private func accessMessage(for error: Error) -> String {
        if case RemindersSource.AccessError.notBundled = error {
            return language.pick(
                en: "Apple Reminders works only in the bundled Todo Island.app (scripts/bundle.sh).",
                zh: "Apple 提醒事项只在打包好的 Todo Island.app 里可用（scripts/bundle.sh）。"
            )
        }
        return language.pick(
            en: "No access to Reminders. Allow Todo Island in System Settings › Privacy & Security › Reminders.",
            zh: "没有提醒事项权限。请在 系统设置 › 隐私与安全性 › 提醒事项 里允许 Todo Island。"
        )
    }

    // MARK: Editing

    @discardableResult
    func add(_ title: String) -> Bool {
        switch source {
        case .local:
            var added = false
            mutateLocal { added = $0.add(title) != nil }
            return added
        case .reminders:
            guard let clean = TodoList.cleanTitle(title) else { return false }
            return remindersEdit { try $0.add(clean, listID: remindersListID) }
        }
    }

    func toggle(_ id: UUID) {
        switch source {
        case .local:
            mutateLocal { $0.toggle(id: id) }
        case .reminders:
            guard let externalID = externalIDs.externalID(for: id), let item = list.item(id: id) else { return }
            // Show the change at once; the refresh that follows confirms it.
            var copy = list
            copy.toggle(id: id)
            list = copy
            remindersEdit { try $0.setDone(externalID, !item.isDone) }
        }
    }

    func rename(_ id: UUID, to title: String) {
        switch source {
        case .local:
            mutateLocal { $0.rename(id: id, to: title) }
        case .reminders:
            guard let externalID = externalIDs.externalID(for: id),
                  let clean = TodoList.cleanTitle(title) else { return }
            remindersEdit { try $0.rename(externalID, to: clean) }
        }
    }

    func remove(_ id: UUID) {
        switch source {
        case .local:
            mutateLocal { $0.remove(id: id) }
        case .reminders:
            guard let externalID = externalIDs.externalID(for: id) else { return }
            remindersEdit { try $0.remove(externalID) }
        }
    }

    /// Local: deletes finished items. Reminders: only hides them here, never deletes them
    /// from the user's Reminders.
    func clearCompleted() {
        switch source {
        case .local:
            mutateLocal { $0.clearCompleted() }
        case .reminders:
            for item in list.items where item.isDone {
                if let externalID = externalIDs.externalID(for: item.id) {
                    hiddenDone.insert(externalID)
                }
            }
            rebuildFromReminders()
        }
    }

    @discardableResult
    private func remindersEdit(_ change: (RemindersSource) throws -> Void) -> Bool {
        do {
            try change(reminders)
            refreshReminders()
            return true
        } catch {
            problem = language.pick(
                en: "Couldn't update Reminders: \(error.localizedDescription)",
                zh: "更新提醒事项失败：\(error.localizedDescription)"
            )
            refreshReminders()
            return false
        }
    }

    private func mutateLocal(_ change: (inout TodoList) -> Void) {
        var copy = localList
        change(&copy)
        guard copy != localList else { return }
        localList = copy
        list = copy
        do {
            try file.save(TodoDocument(list: copy))
            localProblem = nil
        } catch {
            localProblem = language.pick(
                en: "Couldn't save: \(error.localizedDescription)",
                zh: "保存失败：\(error.localizedDescription)"
            )
        }
        problem = localProblem
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
