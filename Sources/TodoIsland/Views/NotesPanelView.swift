import SwiftUI
import TodoIslandCore

/// A single scratchpad note that saves as you type.
struct NotesPanelView: View {
    @ObservedObject var store: NotesStore
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(get: { store.text }, set: { store.update($0) }))
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)

            if store.text.isEmpty {
                Text(language.pick(en: "Jot something down…", zh: "随手记点什么…"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
