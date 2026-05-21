import Foundation

// MARK: – Alert model

public struct AlertInfo: Equatable, Identifiable {
    public let id:             UUID
    public let icon:           String   // SF Symbol name
    public let text:           String   // enforced ≤ 25 characters at init
    public let source:         String   // display name of the originating app / subsystem
    public let actionURL:      URL?     // optional URL-based CTA (opens in browser)
    public let actionLabel:    String?  // button label for either URL or callback action
    public let actionCallback: (() -> Void)?  // non-URL action (e.g. copy to clipboard)

    public init(icon: String, text: String, source: String,
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

    public static func == (lhs: AlertInfo, rhs: AlertInfo) -> Bool { lhs.id == rhs.id }
}

// MARK: – Manager

/// Maintains a chronological queue of `AlertInfo` items and cycles through
/// them every 4 seconds until the queue drains or the user interacts.
///
/// All mutations are main-actor-isolated so SwiftUI subscribers never need
/// explicit `receive(on: RunLoop.main)`.
@MainActor
public final class AlertManager: ObservableObject {

    @Published public private(set) var current: AlertInfo? = nil

    private var queue:     [AlertInfo]        = []
    private var cycleTask: Task<Void, Never>? = nil

    public init() {}

    // MARK: – Public API

    /// Enqueue a new alert. Immediately visible if the queue is empty.
    public func post(icon: String, text: String, source: String,
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
    public func dismiss() {
        cycleTask?.cancel()
        advance()
    }

    /// Immediately clear all pending alerts.
    public func clearAll() {
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
