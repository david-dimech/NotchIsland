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

    private static let log = Logger(subsystem: "com.notchisland.app", category: "Gmail")

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
