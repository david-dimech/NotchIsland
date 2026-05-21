import SwiftUI
import AppKit

struct NotesView: View {
    @StateObject private var store = NotesStore.shared

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
            // Markdown shortcuts — B and I wrap selection with ** and _
            formatBtn("B", weight: .bold)  { store.wrapSelection(marker: "**") }
            formatBtn("I", weight: .regular, italic: true) { store.wrapSelection(marker: "_") }
            Divider().frame(height: 10).background(Color.white.opacity(0.12))
            // Font size zoom
            zoomBtn(systemName: "minus", delta: -1)
            Text("\(Int(store.fontSize))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .frame(minWidth: 14)
            zoomBtn(systemName: "plus", delta: 1)
            Divider().frame(height: 10).background(Color.white.opacity(0.12))
            Text("\(store.text.count)")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.18))
                .frame(minWidth: 16)
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

    private func formatBtn(_ label: String, weight: Font.Weight = .regular, italic: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: weight))
                .italic(italic)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func zoomBtn(systemName: String, delta: CGFloat) -> some View {
        Button { store.adjustFontSize(delta) } label: {
            Image(systemName: systemName)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: – Editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            MarkdownTextEditor(text: $store.text, fontSize: store.fontSize)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            if store.text.isEmpty {
                Text("Start typing…")
                    .font(.system(size: store.fontSize))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: – NSViewRepresentable markdown text editor

private struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers  = true
        scrollView.drawsBackground     = false
        scrollView.borderType          = .noBorder

        let textView = NotesNSTextView(frame: .zero)
        textView.autoresizingMask            = [.width]
        textView.isVerticallyResizable       = true
        textView.isHorizontallyResizable     = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate                    = context.coordinator
        textView.isRichText                  = false
        textView.font                        = NSFont.systemFont(ofSize: fontSize)
        textView.textColor                   = NSColor.white.withAlphaComponent(0.85)
        textView.backgroundColor             = .clear
        textView.drawsBackground             = false
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticTextReplacementEnabled    = false
        textView.allowsUndo                  = true
        textView.string                      = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let sel = textView.selectedRange()
            textView.string = text
            let clampedLoc = min(sel.location, text.count)
            textView.setSelectedRange(NSRange(location: clampedLoc, length: 0))
        }
        let target = NSFont.systemFont(ofSize: fontSize)
        if textView.font?.pointSize != fontSize { textView.font = target }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }
    }
}

// MARK: – NSTextView subclass handling markdown + zoom shortcuts

final class NotesNSTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        if cmd {
            switch event.charactersIgnoringModifiers {
            case "b": wrap(with: "**"); return
            case "i": wrap(with: "_");  return
            case "=", "+": NotesStore.shared.adjustFontSize(1);  return
            case "-":      NotesStore.shared.adjustFontSize(-1); return
            default: break
            }
        }
        super.keyDown(with: event)
    }

    func wrap(with marker: String) {
        let range    = selectedRange()
        let selected = (string as NSString).substring(with: range)
        if selected.isEmpty {
            insertText("\(marker)\(marker)", replacementRange: range)
            setSelectedRange(NSRange(location: range.location + marker.count, length: 0))
        } else {
            insertText("\(marker)\(selected)\(marker)", replacementRange: range)
        }
    }
}

// MARK: – Persistent store

final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    private static let textKey     = "ni.quickNotes"
    private static let fontSizeKey = "ni.notesFontSize"

    @Published var text: String {
        didSet { UserDefaults.standard.set(text, forKey: Self.textKey) }
    }

    @Published var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: Self.fontSizeKey) }
    }

    func adjustFontSize(_ delta: CGFloat) {
        fontSize = min(max(fontSize + delta, 9), 22)
    }

    // Wraps the current text-view selection with a markdown marker.
    // Delegates to the active NSTextView first responder so toolbar buttons work too.
    func wrapSelection(marker: String) {
        guard let tv = NSApp.mainWindow?.firstResponder as? NotesNSTextView else { return }
        tv.wrap(with: marker)
    }

    private init() {
        text = UserDefaults.standard.string(forKey: Self.textKey) ?? ""
        let saved = UserDefaults.standard.double(forKey: Self.fontSizeKey)
        fontSize  = saved > 0 ? CGFloat(saved) : 11
    }
}
