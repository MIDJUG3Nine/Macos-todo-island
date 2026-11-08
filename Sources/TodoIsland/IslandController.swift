import AppKit
import Combine
import SwiftUI
import TodoIslandCore

/// State the SwiftUI views read.
@MainActor
final class IslandViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var isPinned = false
    @Published var selectedPanel: PanelID = .todo
    @Published var notchSize = CGSize(width: 180, height: 32)
    @Published var expandedSize = CGSize(width: 440, height: 320)
    @Published var isHardwareNotch = true

    let language: AppLanguage
    var onTogglePin: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    init(language: AppLanguage) {
        self.language = language
    }
}

/// Owns the island window: where it sits, when it opens and closes.
@MainActor
final class IslandController {
    var openSettings: () -> Void = {}

    private let model: IslandViewModel
    private let settings: SettingsModel
    private let window = IslandWindow()
    private var hover: HoverState
    private var layout: NotchLayout?
    private var expandedFrame: CGRect = .zero
    private var lastPanel: PanelID?

    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var deadlineTask: Task<Void, Never>?
    private var shrinkTask: Task<Void, Never>?

    /// How long the close animation runs before the window shrinks back to the notch.
    private static let collapseAnimationTime: UInt64 = 350_000_000

    init(settings: SettingsModel, todos: TodoStore, notes: NotesStore, language: AppLanguage) {
        self.settings = settings
        self.model = IslandViewModel(language: language)
        self.hover = HoverState(
            hoverDelay: settings.settings.hoverDelay,
            collapseDelay: settings.settings.collapseDelay
        )
        model.selectedPanel = settings.settings.defaultPanel

        let root = IslandRootView(model: model, settings: settings, todos: todos, notes: notes)
        let hosting = FirstMouseHostingView(rootView: root)
        hosting.sizingOptions = [] // the controller sets the window size, not SwiftUI
        window.contentView = hosting

        model.onTogglePin = { [weak self] in self?.togglePin() }
        model.onOpenSettings = { [weak self] in self?.openSettings() }

        settings.$settings
            .dropFirst()
            .sink { [weak self] newValue in self?.apply(newValue) }
            .store(in: &cancellables)

        model.$selectedPanel
            .sink { [weak self] panel in self?.lastPanel = panel }
            .store(in: &cancellables)

        installObservers()
        installMonitors()
        reposition()
    }

    // MARK: Public actions

    /// Menu bar icon: open (pinned, ready to type) or close.
    func toggle() {
        if hover.isExpanded {
            collapse()
        } else {
            hover.expand(pinned: true)
            applyPhase()
            window.makeKey()
        }
    }

    func collapse() {
        guard hover.isExpanded else { return }
        hover.collapse()
        applyPhase()
    }

    // MARK: Layout

    private func apply(_ newSettings: IslandSettings) {
        hover.hoverDelay = newSettings.hoverDelay
        hover.collapseDelay = newSettings.collapseDelay
        if !newSettings.enabledPanels.contains(model.selectedPanel) {
            model.selectedPanel = newSettings.defaultPanel
        }
        reposition(using: newSettings)
    }

    private func reposition() {
        reposition(using: settings.settings)
    }

    private func reposition(using current: IslandSettings) {
        guard let screen = Self.targetScreen(showOnPlainScreens: current.showOnScreensWithoutNotch) else {
            layout = nil
            hover.collapse()
            model.isExpanded = false
            window.orderOut(nil)
            return
        }
        let newLayout = NotchLayout(screen: ScreenMetrics(screen))
        let size = current.panelSize.dimensions
        layout = newLayout
        expandedFrame = newLayout.expandedFrame(width: size.width, height: size.height)

        model.notchSize = newLayout.notchRect.size
        model.isHardwareNotch = newLayout.isHardwareNotch
        model.expandedSize = expandedFrame.size

        window.setFrame(hover.isExpanded ? expandedFrame : newLayout.collapsedFrame, display: true)
        window.orderFrontRegardless()
    }

    /// The built-in display with a notch if there is one (lid open); otherwise the primary
    /// display, if the user wants the pill there.
    private static func targetScreen(showOnPlainScreens: Bool) -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return showOnPlainScreens ? NSScreen.screens.first : nil
    }

    // MARK: Hover

    private func evaluate() {
        guard let layout else { return }
        let point = NSEvent.mouseLocation
        // Don't pop open while the user drags something along the top of the screen.
        let dragging = NSEvent.pressedMouseButtons != 0 && !hover.isExpanded
        let inTrigger = !dragging && layout.hoverZone.contains(point)
        let inPanel = expandedFrame.insetBy(dx: -8, dy: -8).contains(point)
            || layout.hoverZone.contains(point)
        let now = ProcessInfo.processInfo.systemUptime

        if hover.update(inTrigger: inTrigger, inPanel: inPanel, now: now) {
            applyPhase()
        }
        scheduleDeadline(now: now)
    }

    private func scheduleDeadline(now: TimeInterval) {
        deadlineTask?.cancel()
        guard let deadline = hover.nextDeadline else { return }
        let wait = max(0, deadline - now)
        deadlineTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    private func togglePin() {
        if hover.isPinned {
            hover.unpin()
            model.isPinned = false
            evaluate()
        } else {
            hover.pin()
            model.isPinned = hover.isPinned
        }
    }

    private func applyPhase() {
        guard let layout else { return }
        shrinkTask?.cancel()
        model.isPinned = hover.isPinned

        if hover.isExpanded {
            guard !model.isExpanded else { return }
            model.selectedPanel = settings.settings.panelToOpen(last: lastPanel)
            // Grow the window first and let SwiftUI re-centre the still-closed shape with no
            // animation (both frames are centred on the notch, so nothing moves on screen).
            // Only on the next run loop turn start the open animation, so the island grows
            // from the middle of the notch outwards instead of sliding in from the left.
            window.setFrame(expandedFrame, display: true)
            window.contentView?.layoutSubtreeIfNeeded()
            window.orderFrontRegardless()
            DispatchQueue.main.async { [weak self] in
                Task { @MainActor in
                    guard let self, self.hover.isExpanded else { return }
                    self.model.isExpanded = true
                }
            }
        } else {
            model.isExpanded = false
            window.makeFirstResponder(nil) // end any editing right away
            shrinkTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: IslandController.collapseAnimationTime)
                guard !Task.isCancelled, let self, !self.hover.isExpanded else { return }
                self.window.setFrame(layout.collapsedFrame, display: true)
                if self.window.isKeyWindow {
                    // Hand the keyboard back to whatever app the user was in.
                    self.window.orderOut(nil)
                    self.window.orderFrontRegardless()
                }
            }
        }
    }

    // MARK: Events

    private func installMonitors() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            Task { @MainActor in self?.evaluate() }
            return event
        }) {
            monitors.append(local)
        }

        // A click anywhere in another app closes the island.
        if let clicks = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] _ in
                Task { @MainActor in self?.collapse() }
            }
        ) {
            monitors.append(clicks)
        }

        // Esc closes it.
        let islandWindow = window
        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53, event.window === islandWindow else { return event }
            Task { @MainActor in self?.collapse() }
            return nil
        }) {
            monitors.append(keys)
        }
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        })

        // Clicking into the panel (to type or tick) keeps it open until the user clicks away.
        observers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.hover.pin()
                self.model.isPinned = self.hover.isPinned
                self.deadlineTask?.cancel()
            }
        })
    }
}
