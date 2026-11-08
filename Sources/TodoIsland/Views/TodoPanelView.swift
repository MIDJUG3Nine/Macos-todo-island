import SwiftUI
import TodoIslandCore

struct TodoPanelView: View {
    @ObservedObject var store: TodoStore
    let language: AppLanguage

    @State private var draft = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            addField

            if store.list.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(store.list.displayItems) { item in
                            TodoRow(item: item, store: store, language: language)
                        }
                    }
                }
            }

            if let problem = store.problem {
                Text(problem)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.orange)
                    .lineLimit(2)
            }

            footer
        }
    }

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            TextField(language.pick(en: "Add a todo, press Return", zh: "添加待办，按回车"), text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($addFieldFocused)
                .onSubmit(add)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(addFieldFocused ? 0.12 : 0.07))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 22))
                .foregroundStyle(Color.white.opacity(0.35))
            Text(language.pick(en: "Nothing to do. Nice.", zh: "没有待办，轻松一下。"))
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(remainingText)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.45))
            Spacer()
            if store.list.doneCount > 0 {
                Button(language.pick(en: "Clear completed", zh: "清除已完成")) {
                    withAnimation(.easeOut(duration: 0.2)) { store.clearCompleted() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
            }
        }
    }

    private var remainingText: String {
        let open = store.list.openCount
        return language == .chinese ? "还剩 \(open) 项" : (open == 1 ? "1 left" : "\(open) left")
    }

    private func add() {
        if store.add(draft) {
            draft = ""
        }
        addFieldFocused = true
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: TodoStore
    let language: AppLanguage

    @State private var hovering = false
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    private static let doneColor = Color(red: 0.42, green: 0.86, blue: 0.6)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { store.toggle(item.id) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isDone ? Self.doneColor : Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help(item.isDone
                ? language.pick(en: "Mark as not done", zh: "标记为未完成")
                : language.pick(en: "Mark as done", zh: "标记为完成"))

            if isEditing {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($editFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand { isEditing = false }
            } else {
                Text(item.title)
                    .font(.system(size: 13))
                    .strikethrough(item.isDone, color: Color.white.opacity(0.4))
                    .foregroundStyle(item.isDone ? Color.white.opacity(0.4) : Color.white.opacity(0.92))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: startEdit)
            }

            if hovering && !isEditing {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { store.remove(item.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(language.pick(en: "Delete", zh: "删除"))
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.06 : 0))
        )
        .onHover { hovering = $0 }
        .onChange(of: editFocused) { focused in
            if !focused && isEditing { commitEdit() }
        }
        .contextMenu {
            Button(language.pick(en: "Edit", zh: "编辑"), action: startEdit)
            Button(item.isDone
                ? language.pick(en: "Mark as not done", zh: "标记为未完成")
                : language.pick(en: "Mark as done", zh: "标记为完成")) {
                store.toggle(item.id)
            }
            Divider()
            Button(language.pick(en: "Delete", zh: "删除")) { store.remove(item.id) }
        }
    }

    private func startEdit() {
        editText = item.title
        isEditing = true
        DispatchQueue.main.async { editFocused = true }
    }

    private func commitEdit() {
        store.rename(item.id, to: editText)
        isEditing = false
    }
}
