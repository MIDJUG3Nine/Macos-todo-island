import AppKit
import TodoIslandCore

/// The menu bar icon: a way to open the island without hovering, reach settings, and quit.
@MainActor
final class StatusItemController: NSObject {
    var onToggleIsland: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let language: AppLanguage

    init(language: AppLanguage) {
        self.language = language
        super.init()

        if let button = item.button {
            let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Todo Island")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Todo Island"
        }

        let menu = NSMenu()
        menu.addItem(makeItem(language.pick(en: "Open Island", zh: "展开 Island"), #selector(toggleIsland), key: ""))
        menu.addItem(makeItem(language.pick(en: "Settings…", zh: "设置…"), #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem(language.pick(en: "Quit Todo Island", zh: "退出 Todo Island"), #selector(quit), key: "q"))
        item.menu = menu
    }

    private func makeItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func toggleIsland() { onToggleIsland() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { onQuit() }
}
