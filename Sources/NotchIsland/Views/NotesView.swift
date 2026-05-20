import SwiftUI

// Quick Notes — a persistent scratch pad that saves to UserDefaults.
// Notes survive across app restarts and sessions.
struct NotesView: View {
    @StateObject private var store = NotesStore.shared
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.07))
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "note.text")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            Text("Quick Notes")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text("\(store.text.count) chars")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
            if !store.text.isEmpty {
                Button {
                    withAnimation { store.text = "" }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: – Editor

    private var editor: some View {
        TextEditor(text: $store.text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.85))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .focused($focused)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(alignment: .topLeading) {
                if store.text.isEmpty {
                    Text("Start typing…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }
}

// MARK: – Persistent store

final class NotesStore: ObservableObject {
    static let shared = NotesStore()
    private static let key = "ni.quickNotes"

    @Published var text: String {
        didSet { UserDefaults.standard.set(text, forKey: Self.key) }
    }

    private init() {
        text = UserDefaults.standard.string(forKey: Self.key) ?? ""
    }
}
