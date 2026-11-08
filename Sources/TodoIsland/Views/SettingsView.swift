import AppKit
import ServiceManagement
import SwiftUI
import TodoIslandCore

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: SettingsModel, todos: TodoStore, language: AppLanguage) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings, todos: todos, language: language))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = language.pick(en: "Todo Island Settings", zh: "Todo Island 设置")
            newWindow.styleMask = [.titled, .closable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var todos: TodoStore
    let language: AppLanguage

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    private static let repoURL = URL(string: "https://github.com/MIDJUG3Nine/Macos-todo-island")!

    var body: some View {
        Form {
            Section(language.pick(en: "Panels", zh: "面板")) {
                Picker(language.pick(en: "Open with", zh: "默认打开"), selection: $settings.settings.defaultPanel) {
                    ForEach(settings.settings.enabledPanels) { panel in
                        Label(panel.title(language), systemImage: panel.symbolName).tag(panel)
                    }
                }
                ForEach(PanelID.allCases) { panel in
                    Toggle(isOn: panelBinding(panel)) {
                        Label(panel.title(language), systemImage: panel.symbolName)
                    }
                }
                Toggle(
                    language.pick(en: "Reopen the last panel I used", zh: "打开时回到上次的面板"),
                    isOn: $settings.settings.rememberLastPanel
                )
            }

            Section(language.pick(en: "Todo source", zh: "待办来源")) {
                Picker(language.pick(en: "Todos come from", zh: "待办来自"), selection: $settings.settings.todoSource) {
                    ForEach(TodoSource.allCases) { source in
                        Text(source.title(language)).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                if settings.settings.todoSource == .reminders {
                    if todos.reminderLists.isEmpty {
                        Text(todos.problem ?? language.pick(en: "Connecting to Reminders…", zh: "正在连接提醒事项…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(language.pick(en: "List", zh: "列表"), selection: $settings.settings.remindersListID) {
                            Text(language.pick(en: "Default list", zh: "默认列表")).tag(String?.none)
                            ForEach(todos.reminderLists) { list in
                                Text(list.title).tag(Optional(list.id))
                            }
                        }
                    }
                    Text(language.pick(
                        en: "Adding, ticking, editing and deleting change your Reminders. \"Clear completed\" only hides them here.",
                        zh: "在 Island 里添加、打勾、修改、删除都会同步到提醒事项；「清除已完成」只在这里隐藏，不会删掉提醒事项。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section(language.pick(en: "Behaviour", zh: "行为")) {
                Picker(language.pick(en: "Size", zh: "大小"), selection: $settings.settings.panelSize) {
                    ForEach(PanelSize.allCases) { size in
                        Text(size.title(language)).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                delaySlider(
                    title: language.pick(en: "Open after hovering", zh: "悬停多久展开"),
                    value: $settings.settings.hoverDelay,
                    range: IslandSettings.hoverDelayRange
                )
                delaySlider(
                    title: language.pick(en: "Close after leaving", zh: "离开多久收起"),
                    value: $settings.settings.collapseDelay,
                    range: IslandSettings.collapseDelayRange
                )
                Toggle(
                    language.pick(en: "Show a pill on screens without a notch", zh: "没有刘海的屏幕显示一个小胶囊"),
                    isOn: $settings.settings.showOnScreensWithoutNotch
                )
            }

            Section(language.pick(en: "General", zh: "通用")) {
                Toggle(language.pick(en: "Open at login", zh: "开机自动启动"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin, perform: setLaunchAtLogin)
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(language.pick(en: "Show data folder", zh: "打开数据文件夹")) {
                        let folder = AppPaths.supportDirectory()
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    Spacer()
                    Link("GitHub", destination: Self.repoURL)
                }
            }

            Section {
                Text(language.pick(
                    en: "Hover the notch to peek. Click inside to keep it open, click anywhere else or press Esc to close.",
                    zh: "指针放到刘海上就能看一眼。点进去会保持展开，点别处或按 Esc 收起。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func panelBinding(_ panel: PanelID) -> Binding<Bool> {
        Binding(
            get: { settings.settings.enabledPanels.contains(panel) },
            set: { settings.settings.setPanel(panel, enabled: $0) }
        )
    }

    private func delaySlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: language.pick(en: "%.2f s", zh: "%.2f 秒"), value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.05)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = language.pick(
                en: "Couldn't change the login item. This works only from the bundled Todo Island.app.",
                zh: "设置失败。这个功能只在打包好的 Todo Island.app 里可用。"
            )
            let actual = SMAppService.mainApp.status == .enabled
            if actual != launchAtLogin {
                launchAtLogin = actual
            }
        }
    }
}
