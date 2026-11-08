import EventKit
import Foundation
import TodoIslandCore

/// A Reminders list the user can pick in Settings.
struct ReminderListInfo: Identifiable, Equatable {
    let id: String
    let title: String
}

/// Reads and writes Apple Reminders through EventKit.
@MainActor
final class RemindersSource {
    enum AccessError: Error {
        /// Running outside the bundled app: macOS would kill the process on the permission prompt.
        case notBundled
        case denied
    }

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    /// Called when Reminders changes anywhere (this app, the Reminders app, another device).
    var onExternalChange: () -> Void = {}

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onExternalChange() }
        }
    }

    static var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    /// The permission prompt needs a usage string in Info.plist; `swift run` has none.
    static var canAskForAccess: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSRemindersUsageDescription") != nil
    }

    func requestAccess() async throws {
        if Self.hasAccess { return }
        guard Self.canAskForAccess else { throw AccessError.notBundled }
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await store.requestAccess(to: .reminder)
        }
        guard granted else { throw AccessError.denied }
    }

    func lists() -> [ReminderListInfo] {
        store.calendars(for: .reminder)
            .map { ReminderListInfo(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The chosen list, or the default Reminders list when none is chosen or it was deleted.
    func calendar(listID: String?) -> EKCalendar? {
        if let listID, let chosen = store.calendar(withIdentifier: listID) {
            return chosen
        }
        return store.defaultCalendarForNewReminders()
    }

    func listTitle(listID: String?) -> String? {
        calendar(listID: listID)?.title
    }

    /// Open reminders plus the ones finished today, from one list.
    func fetch(listID: String?, now: Date = Date()) async -> [ExternalTodo] {
        guard let calendar = calendar(listID: listID) else { return [] }
        let open = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [calendar]
        )
        let done = store.predicateForCompletedReminders(
            withCompletionDateStarting: ExternalTodoMapping.completedSince(now: now),
            ending: nil,
            calendars: [calendar]
        )
        let openItems = await fetch(open)
        let doneItems = await fetch(done)
        return openItems + doneItems
    }

    private func fetch(_ predicate: NSPredicate) async -> [ExternalTodo] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).map { reminder in
                    ExternalTodo(
                        externalID: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "",
                        isDone: reminder.isCompleted,
                        createdAt: reminder.creationDate,
                        completedAt: reminder.completionDate
                    )
                }
                continuation.resume(returning: items)
            }
        }
    }

    // MARK: Editing

    func add(_ title: String, listID: String?) throws {
        guard let calendar = calendar(listID: listID) else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        try store.save(reminder, commit: true)
    }

    func setDone(_ externalID: String, _ done: Bool) throws {
        guard let reminder = reminder(externalID) else { return }
        reminder.isCompleted = done
        try store.save(reminder, commit: true)
    }

    func rename(_ externalID: String, to title: String) throws {
        guard let reminder = reminder(externalID) else { return }
        reminder.title = title
        try store.save(reminder, commit: true)
    }

    func remove(_ externalID: String) throws {
        guard let reminder = reminder(externalID) else { return }
        try store.remove(reminder, commit: true)
    }

    private func reminder(_ externalID: String) -> EKReminder? {
        store.calendarItem(withIdentifier: externalID) as? EKReminder
    }
}
