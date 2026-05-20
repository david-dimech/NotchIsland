import Foundation

// MARK: – Alert model

struct AlertInfo: Equatable, Identifiable {
    let id:             UUID
    let icon:           String   // SF Symbol name
    let text:           String   // enforced ≤ 25 characters at init
    let source:         String   // display name of the originating app / subsystem
    let actionURL:      URL?     // optional URL-based CTA (opens in browser)
    let actionLabel:    String?  // button label for either URL or callback action
    let actionCallback: (() -> Void)?  // non-URL action (e.g. copy to clipboard)

    init(icon: String, text: String, source: String,
         actionURL: URL? = nil,
         actionLabel: String? = nil,
         actionCallback: (() -> Void)? = nil) {
        self.id             = UUID()
        self.icon           = icon
        self.text           = String(text.prefix(25))
        self.source         = source
        self.actionURL      = actionURL
        self.actionLabel    = actionLabel
        self.actionCallback = actionCallback
    }

    static func == (lhs: AlertInfo, rhs: AlertInfo) -> Bool { lhs.id == rhs.id }
}

// MARK: – Manager

/// Maintains a chronological queue of `AlertInfo` items and cycles through
/// them every 4 seconds until the queue drains or the user interacts.
///
/// All mutations are main-actor-isolated so SwiftUI subscribers never need
/// explicit `receive(on: RunLoop.main)`.
@MainActor
final class AlertManager: ObservableObject {

    @Published private(set) var current: AlertInfo? = nil

    private var queue:     [AlertInfo]        = []
    private var cycleTask: Task<Void, Never>? = nil

    // MARK: – Public API

    /// Enqueue a new alert. Immediately visible if the queue is empty.
    func post(icon: String, text: String, source: String,
              actionURL: URL? = nil,
              actionLabel: String? = nil,
              actionCallback: (() -> Void)? = nil) {
        queue.append(AlertInfo(icon: icon, text: text, source: source,
                               actionURL: actionURL,
                               actionLabel: actionLabel,
                               actionCallback: actionCallback))
        if current == nil { advance() }
    }

    /// Dismiss the current alert and show the next one (or clear if none).
    func dismiss() {
        cycleTask?.cancel()
        advance()
    }

    /// Immediately clear all pending alerts.
    func clearAll() {
        cycleTask?.cancel()
        queue.removeAll()
        current = nil
    }

    // MARK: – Internal cycling

    private func advance() {
        cycleTask?.cancel()
        guard !queue.isEmpty else { current = nil; return }

        current = queue.removeFirst()

        // Auto-advance after 4 s so multiple alerts rotate without user interaction.
        cycleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }
}
