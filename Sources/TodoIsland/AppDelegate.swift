import AppKit
import Combine
import TodoIslandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let language = AppLanguage.current
    private var settings: SettingsModel!
    private var todos: TodoStore!
    private var notes: NotesStore!
    private var island: IslandController!
    private var statusItem: StatusItemController!
    private let settingsWindow = SettingsWindowController()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if quitIfAlreadyRunning() { return }

        settings = SettingsModel()
        todos = TodoStore()
        notes = NotesStore()

        todos.configure(source: settings.settings.todoSource, remindersListID: settings.settings.remindersListID)
        settings.$settings
            .sink { [weak self] newValue in
                self?.todos.configure(source: newValue.todoSource, remindersListID: newValue.remindersListID)
            }
            .store(in: &cancellables)

        island = IslandController(settings: settings, todos: todos, notes: notes, language: language)
        island.openSettings = { [weak self] in self?.showSettings() }

        statusItem = StatusItemController(language: language)
        statusItem.onToggleIsland = { [weak self] in self?.island.toggle() }
        statusItem.onOpenSettings = { [weak self] in self?.showSettings() }
        statusItem.onQuit = { NSApp.terminate(nil) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notes?.flush()
    }

    private func showSettings() {
        island.collapse()
        settingsWindow.show(settings: settings, todos: todos, language: language)
    }

    /// A second copy would put two islands on the notch. Only applies to the bundled app.
    private func quitIfAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0 != NSRunningApplication.current }
        guard let other = others.first else { return false }
        other.activate(options: [])
        NSApp.terminate(nil)
        return true
    }
}
