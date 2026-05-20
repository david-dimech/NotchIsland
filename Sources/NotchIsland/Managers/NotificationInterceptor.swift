import AppKit
import ApplicationServices

// MARK: – Intercepted notification payload

struct InterceptedNotification {
    let appName: String
    let title:   String
    let body:    String
}

// MARK: – Interceptor

/// Uses the Accessibility API to watch the macOS notification-banner process for
/// new windows, then scrapes their text tree to extract app / title / body.
///
/// Requires "Accessibility" permission in System Settings → Privacy & Security.
/// Call `requestPermission()` once at launch; call `start()` after it is granted.
@MainActor
final class NotificationInterceptor {

    /// Fired on the main thread for every new notification banner.
    var onNotification: ((InterceptedNotification) -> Void)?

    private var axObserver:   AXObserver?
    private var watchedPID:   pid_t = 0
    private var retryTimer:   Timer?

    // Bundle IDs used by the notification-banner process across macOS versions.
    private static let candidateBundleIDs = [
        "com.apple.notificationcenterui",
        "com.apple.UserNotificationsUIService",
    ]

    // MARK: – Public

    static func requestPermission() {
        let key  = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    func start() {
        guard AXIsProcessTrusted() else { return }
        if attachToRunningProcess() == nil { scheduleRetry() }
    }

    // MARK: – Process lookup

    @discardableResult
    private func attachToRunningProcess() -> Bool? {
        let running = NSWorkspace.shared.runningApplications
        for bundleID in Self.candidateBundleIDs {
            if let app = running.first(where: { $0.bundleIdentifier == bundleID }) {
                attach(to: app.processIdentifier)
                return true
            }
        }
        return nil
    }

    private func scheduleRetry() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.attachToRunningProcess() == nil { self.scheduleRetry() }
            }
        }
        // Also watch for the process launching later.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
    }

    @objc private func appLaunched(_ note: Notification) {
        guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              Self.candidateBundleIDs.contains(info.bundleIdentifier ?? "")
        else { return }
        retryTimer?.invalidate()
        attach(to: info.processIdentifier)
    }

    // MARK: – AXObserver attachment

    private func attach(to pid: pid_t) {
        guard pid != watchedPID else { return }

        // Tear down any previous observer.
        if let old = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(old), .defaultMode)
            axObserver = nil
        }

        var obs: AXObserver?
        let callback: AXObserverCallback = { _, element, _, refcon in
            guard let refcon else { return }
            let self_ = Unmanaged<NotificationInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            // Allow the banner window to fully populate before we read it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self_.bannerWindowCreated(element)
            }
        }
        guard AXObserverCreate(pid, callback, &obs) == .success, let obs else { return }

        let appElem = AXUIElementCreateApplication(pid)
        let selfPtr  = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(obs, appElem, kAXWindowCreatedNotification as CFString, selfPtr)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        axObserver  = obs
        watchedPID  = pid
    }

    // MARK: – AX tree parsing

    private func bannerWindowCreated(_ window: AXUIElement) {
        let texts = collectTexts(window)
        guard texts.count >= 1 else { return }

        // Heuristic layout (consistent across macOS 13/14):
        //   texts[0]  — app name
        //   texts[1]  — notification title  (may equal app name when absent)
        //   texts[2…] — body lines
        let appName = texts[0]
        let title   = texts.count > 1 ? texts[1] : ""
        let body    = texts.count > 2 ? texts[2...].joined(separator: " ") : ""

        let notification = InterceptedNotification(appName: appName, title: title, body: body)
        onNotification?(notification)
    }

    // Depth-first collection of all AXStaticText values in the element tree.
    private func collectTexts(_ element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < 10 else { return [] }
        var results: [String] = []

        var roleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        if let role = roleVal as? String, role == (kAXStaticTextRole as String) {
            var val: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &val)
            if let text = val as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        var childrenVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal)
        if let children = childrenVal as? [AXUIElement] {
            for child in children {
                results.append(contentsOf: collectTexts(child, depth: depth + 1))
            }
        }
        return results
    }
}
