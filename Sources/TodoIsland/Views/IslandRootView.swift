import SwiftUI
import TodoIslandCore

/// Everything drawn in the island window: the black shape and, when open, the panel.
struct IslandRootView: View {
    @ObservedObject var model: IslandViewModel
    @ObservedObject var settings: SettingsModel
    @ObservedObject var todos: TodoStore
    @ObservedObject var notes: NotesStore

    static let shoulder: CGFloat = 12

    var body: some View {
        let expanded = model.isExpanded
        let size = expanded ? model.expandedSize : model.notchSize
        let shoulder = expanded ? Self.shoulder : 0
        let bottomRadius: CGFloat = expanded ? 24 : (model.isHardwareNotch ? 10 : model.notchSize.height / 2)

        ZStack(alignment: .top) {
            IslandShape(shoulder: shoulder, bottomRadius: bottomRadius)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)

            if expanded {
                ExpandedIslandView(model: model, settings: settings, todos: todos, notes: notes)
                    .frame(width: model.expandedSize.width, height: model.expandedSize.height)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.08)),
                            removal: .opacity.animation(.easeIn(duration: 0.1))
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: expanded)
        .environment(\.colorScheme, .dark)
    }
}

/// Header (tabs + buttons) and the selected panel.
struct ExpandedIslandView: View {
    @ObservedObject var model: IslandViewModel
    @ObservedObject var settings: SettingsModel
    @ObservedObject var todos: TodoStore
    @ObservedObject var notes: NotesStore

    private var language: AppLanguage { model.language }
    private var horizontalInset: CGFloat { IslandRootView.shoulder + 16 }

    /// Room on each side of the notch in the top strip.
    private var sideRoom: CGFloat {
        (model.expandedSize.width - 2 * horizontalInset - model.notchSize.width) / 2
    }

    var body: some View {
        // If the tabs fit beside the notch, use that strip; otherwise put them below it.
        let headerBesideNotch = sideRoom >= 76
        VStack(spacing: 0) {
            if headerBesideNotch {
                HStack(spacing: 0) {
                    tabs
                    Spacer(minLength: model.notchSize.width + 8)
                    controls
                }
                .frame(height: max(model.notchSize.height, 26))
            } else {
                Color.clear.frame(height: model.notchSize.height)
                HStack {
                    tabs
                    Spacer()
                    controls
                }
                .frame(height: 28)
            }

            PanelContentView(panel: model.selectedPanel, todos: todos, notes: notes, language: language)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, horizontalInset)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var tabs: some View {
        let panels = settings.settings.enabledPanels
        HStack(spacing: 4) {
            if panels.count > 1 {
                ForEach(panels) { panel in
                    IslandIconButton(
                        symbol: panel.symbolName,
                        help: panel.title(language),
                        isActive: model.selectedPanel == panel
                    ) {
                        model.selectedPanel = panel
                    }
                }
            } else if let only = panels.first {
                Label(only.title(language), systemImage: only.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 4) {
            IslandIconButton(
                symbol: model.isPinned ? "pin.fill" : "pin",
                help: model.isPinned
                    ? language.pick(en: "Unpin (close when the pointer leaves)", zh: "取消固定（指针离开就收起）")
                    : language.pick(en: "Pin open", zh: "固定展开"),
                isActive: model.isPinned
            ) {
                model.onTogglePin()
            }
            IslandIconButton(
                symbol: "gearshape",
                help: language.pick(en: "Settings", zh: "设置"),
                isActive: false
            ) {
                model.onOpenSettings()
            }
        }
    }
}

/// Picks the view for a panel. New panels are added here.
struct PanelContentView: View {
    let panel: PanelID
    @ObservedObject var todos: TodoStore
    @ObservedObject var notes: NotesStore
    let language: AppLanguage

    var body: some View {
        switch panel {
        case .todo:
            TodoPanelView(store: todos, language: language)
        case .notes:
            NotesPanelView(store: notes, language: language)
        }
    }
}

struct IslandIconButton: View {
    let symbol: String
    let help: String
    let isActive: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 22)
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(hovering ? 0.8 : 0.5))
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(isActive ? 0.16 : (hovering ? 0.08 : 0)))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
