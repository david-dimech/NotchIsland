import AppKit
import Foundation
import os.log

struct GmailMessage: Identifiable {
    let id: String
    let threadId: String
    let from: String        // raw "Name <email>"
    let fromName: String    // display name extracted
    let subject: String
    let date: Date
    let snippet: String
    let isUnread: Bool
}

@MainActor
final class GmailManager: ObservableObject {
    @Published private(set) var messages: [GmailMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var unreadCount = 0

    // Injected by IslandViewModel — shares auth with GoogleCalendarManager
    weak var authProvider: GoogleCalendarManager?

    var onNewMessage: ((GmailMessage) -> Void)?
    private var knownMessageIDs: Set<String>? = nil  // nil = first fetch, skip alerts
    private var pollTimer: Timer?

    private static let log = Logger(subsystem: "com.notchisland.app", category: "Gmail")

    // Call once after authProvider is set. Polls every 60 s for new messages.
    func startPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchMessages() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    func fetchMessages() async {
        guard let token = await authProvider?.validToken() else { return }
        isLoading = true
        defer { isLoading = false }

        // category:primary excludes Promotions, Updates, Social, Forums
        let qs = "q=category%3Aprimary&labelIds=INBOX&maxResults=20"
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?\(qs)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        Self.log.info("Gmail: list HTTP \(status)")
        guard status == 200,
              let list = try? JSONDecoder().decode(GmailListResponse.self, from: data),
              let items = list.messages else { return }

        // Fetch details in batches of 5 to stay snappy
        var fetched: [GmailMessage] = []
        for item in items.prefix(20) {
            if let msg = await fetchDetail(id: item.id, token: token) {
                fetched.append(msg)
            }
        }
        let fetchedIDs = Set(fetched.map(\.id))
        if let known = knownMessageIDs {
            let newIDs = fetchedIDs.subtracting(known)
            for msg in fetched.filter({ newIDs.contains($0.id) }).prefix(3) {
                onNewMessage?(msg)
            }
        }
        knownMessageIDs = fetchedIDs
        messages    = fetched
        unreadCount = fetched.filter(\.isUnread).count
        Self.log.info("Gmail: loaded \(fetched.count) messages, \(fetched.filter(\.isUnread).count) unread")
    }

    private func fetchDetail(id: String, token: String) async -> GmailMessage? {
        let qs = "format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date"
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?\(qs)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let raw = try? JSONDecoder().decode(GmailRawMessage.self, from: data) else { return nil }
        return raw.toMessage()
    }

    func markAsRead(id: String) async {
        guard let token = await authProvider?.validToken() else { return }
        await modifyMessage(id: id, token: token, removeLabelIds: ["UNREAD"])
        // Update local state optimistically
        if let i = messages.firstIndex(where: { $0.id == id }) {
            let m = messages[i]
            messages[i] = GmailMessage(id: m.id, threadId: m.threadId, from: m.from,
                                        fromName: m.fromName, subject: m.subject,
                                        date: m.date, snippet: m.snippet, isUnread: false)
            unreadCount = messages.filter(\.isUnread).count
        }
    }

    func archive(id: String) async {
        guard let token = await authProvider?.validToken() else { return }
        await modifyMessage(id: id, token: token, removeLabelIds: ["INBOX"])
        messages.removeAll { $0.id == id }
        unreadCount = messages.filter(\.isUnread).count
    }

    private func modifyMessage(id: String, token: String, removeLabelIds: [String]) async {
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)/modify") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["removeLabelIds": removeLabelIds])
        let (_, resp) = (try? await URLSession.shared.data(for: req)) ?? (nil, nil)
        Self.log.info("Gmail: modifyMessage \(id) remove:\(removeLabelIds) → HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
    }

    func openMessage(id: String) {
        if let url = URL(string: "https://mail.google.com/mail/u/0/#inbox/\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInbox() {
        if let url = URL(string: "https://mail.google.com/mail/u/0/#inbox") {
            NSWorkspace.shared.open(url)
        }
    }

    // Returns plain text body of a message. Tries text/plain first, falls back to
    // stripping tags from text/html. Returns snippet on failure.
    func fetchBody(id: String) async -> String? {
        guard let token = await authProvider?.validToken() else { return nil }
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let raw = try? JSONDecoder().decode(GmailFullMessage.self, from: data) else { return nil }
        return raw.extractedText
    }
}

// MARK: – Private decodable helpers

private struct GmailListResponse: Decodable {
    let messages: [GmailListItem]?
    let resultSizeEstimate: Int?
}
private struct GmailListItem: Decodable {
    let id: String
    let threadId: String
}
private struct GmailRawMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailPayload?

    func toMessage() -> GmailMessage {
        let headers  = payload?.headers ?? []
        let fromRaw  = headers.first(where: { $0.name == "From"    })?.value ?? ""
        let subject  = headers.first(where: { $0.name == "Subject" })?.value ?? "(no subject)"
        let dateStr  = headers.first(where: { $0.name == "Date"    })?.value ?? ""
        let fromName = extractName(fromRaw)
        let date     = parseRFC2822(dateStr) ?? Date()
        let isUnread = labelIds?.contains("UNREAD") ?? false
        return GmailMessage(id: id, threadId: threadId,
                            from: fromRaw, fromName: fromName,
                            subject: subject, date: date,
                            snippet: snippet ?? "", isUnread: isUnread)
    }

    private func extractName(_ from: String) -> String {
        if let lt = from.firstIndex(of: "<") {
            let name = String(from[from.startIndex..<lt])
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\"", with: "")
            return name.isEmpty ? from : name
        }
        return from
    }

    private func parseRFC2822(_ str: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z"] {
            f.dateFormat = fmt
            if let d = f.date(from: str) { return d }
        }
        return nil
    }
}
private struct GmailPayload: Decodable {
    let headers: [GmailHeader]?
}
private struct GmailHeader: Decodable {
    let name: String
    let value: String
}

// MARK: – Full-message body decoder (for inline preview)

private struct GmailFullMessage: Decodable {
    let payload: GmailFullPayload?

    var extractedText: String? {
        guard let p = payload else { return nil }
        return extractPlain(p) ?? extractHtml(p).map { stripHTML($0) }
    }

    private func extractPlain(_ part: GmailFullPayload) -> String? {
        if part.mimeType?.hasPrefix("text/plain") == true,
           let text = part.body?.decodedString(), !text.isEmpty { return text }
        for child in part.parts ?? [] {
            if let t = extractPlain(child) { return t }
        }
        return nil
    }

    private func extractHtml(_ part: GmailFullPayload) -> String? {
        if part.mimeType?.hasPrefix("text/html") == true,
           let html = part.body?.decodedString(), !html.isEmpty { return html }
        for child in part.parts ?? [] {
            if let h = extractHtml(child) { return h }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String {
        var s = html
        for pattern in ["<style[^>]*>[\\s\\S]*?</style>", "<script[^>]*>[\\s\\S]*?</script>"] {
            s = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        s = s
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GmailFullPayload: Decodable {
    let mimeType: String?
    let body: GmailBodyData?
    let parts: [GmailFullPayload]?
}

private struct GmailBodyData: Decodable {
    let data: String?
    func decodedString() -> String? {
        guard let d = data else { return nil }
        var b64 = d.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let bytes = Data(base64Encoded: b64) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }
}
