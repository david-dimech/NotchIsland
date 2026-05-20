import AppKit
import Foundation
import os.log

// MARK: – Data models

struct GCalEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let hangoutLink: String?   // Google Meet URL if present
}

// Raw decodable structs kept private
private struct GCalEventsResponse: Decodable { let items: [GCalRawEvent] }
private struct GCalRawEvent: Decodable {
    let id: String
    let summary: String?
    let location: String?
    let hangoutLink: String?
    let start: GCalRawDT
    let end: GCalRawDT
}
private struct GCalRawDT: Decodable {
    let dateTime: String?   // RFC3339 with offset e.g. "2025-05-20T10:00:00+01:00"
    let date: String?       // Date-only "2025-05-20"
    let timeZone: String?

    var resolved: Date? {
        if let s = dateTime {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: s) { return d }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: s)
        }
        if let s = date {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
            return f.date(from: s)
        }
        return nil
    }
}

private extension GCalRawEvent {
    func toEvent() -> GCalEvent? {
        guard let s = start.resolved, let e = end.resolved else { return nil }
        return GCalEvent(id: id, title: summary ?? "Untitled",
                         start: s, end: e,
                         isAllDay: start.dateTime == nil,
                         location: location, hangoutLink: hangoutLink)
    }
}

// MARK: – Manager

@MainActor
final class GoogleCalendarManager: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var events: [GCalEvent] = []
    @Published private(set) var isLoading = false
    @Published var statusMessage: String? = nil

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date = .distantPast
    private var callbackServer: OAuthCallbackServer?
    private var refreshTimer: Timer?

    private static let log = Logger(subsystem: "com.notchisland.app", category: "GoogleCal")
    private static let accessKey  = "ni.gcal.access"
    private static let refreshKey = "ni.gcal.refresh"
    private static let expiryKey  = "ni.gcal.expiry"

    private let clientID     = Secrets.googleClientID
    private let clientSecret = Secrets.googleClientSecret

    // Combined scope covering Calendar + Gmail
    private static let oauthScope = [
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/gmail.readonly",
    ].joined(separator: " ")

    init() {
        loadStoredTokens()
        if isAuthenticated {
            Task { await fetchEvents() }
            scheduleAutoRefresh()
        }
    }

    // MARK: – Auth: sign in

    func startSignIn() {
        let server = OAuthCallbackServer()
        server.onCode  = { [weak self] code in Task { await self?.exchangeCode(code, redirectURI: "http://localhost:\(server.port)") } }
        server.onError = { [weak self] msg in self?.statusMessage = "OAuth error: \(msg)" }
        server.start()
        callbackServer = server

        let redirect = "http://localhost:\(server.port)"
        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [
            .init(name: "client_id",     value: clientID),
            .init(name: "redirect_uri",  value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: Self.oauthScope),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "consent"),
        ]
        NSWorkspace.shared.open(c.url!)
        statusMessage = "Browser opened — sign in to Google"
        Self.log.info("GoogleCal: opened OAuth browser")
    }

    func signOut() {
        callbackServer?.stop(); callbackServer = nil
        refreshTimer?.invalidate()
        accessToken = nil; refreshToken = nil; tokenExpiry = .distantPast
        let d = UserDefaults.standard
        d.removeObject(forKey: Self.accessKey)
        d.removeObject(forKey: Self.refreshKey)
        d.removeObject(forKey: Self.expiryKey)
        isAuthenticated = false; events = []; statusMessage = nil
        Self.log.info("GoogleCal: signed out")
    }

    // MARK: – Auth: token exchange

    private func exchangeCode(_ code: String, redirectURI: String) async {
        callbackServer?.stop(); callbackServer = nil
        statusMessage = "Authenticating…"
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "code=\(code)&client_id=\(clientID)&client_secret=\(clientSecret)&redirect_uri=\(redirectURI)&grant_type=authorization_code".data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { statusMessage = "Token exchange failed"; return }

        if let access = json["access_token"] as? String,
           let refresh = json["refresh_token"] as? String,
           let expiresIn = json["expires_in"] as? TimeInterval {
            store(access: access, refresh: refresh, expiresIn: expiresIn)
            isAuthenticated = true; statusMessage = nil
            await fetchEvents()
            NotificationCenter.default.post(name: .googleAuthDidComplete, object: nil)
            scheduleAutoRefresh()
        } else {
            let err = (json["error_description"] as? String) ?? (json["error"] as? String) ?? "Unknown error"
            statusMessage = "Auth failed: \(err)"
            Self.log.error("GoogleCal: token exchange error: \(err)")
        }
    }

    private func refreshTokens() async -> Bool {
        guard let refresh = refreshToken, !clientID.isEmpty, !clientSecret.isEmpty else {
            isAuthenticated = false; return false
        }
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "refresh_token=\(refresh)&client_id=\(clientID)&client_secret=\(clientSecret)&grant_type=refresh_token".data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? TimeInterval
        else { return false }

        accessToken  = access
        tokenExpiry  = Date().addingTimeInterval(expiresIn - 60)
        UserDefaults.standard.set(access, forKey: Self.accessKey)
        UserDefaults.standard.set(tokenExpiry, forKey: Self.expiryKey)
        Self.log.info("GoogleCal: token refreshed")
        return true
    }

    func validToken() async -> String? {
        if let t = accessToken, tokenExpiry > Date() { return t }
        return await refreshTokens() ? accessToken : nil
    }

    // MARK: – Events

    func fetchEvents() async {
        guard let token = await validToken() else { isAuthenticated = false; return }
        isLoading = true; Self.log.info("GoogleCal: fetching events")

        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        let now    = iso.string(from: Date())
        let future = iso.string(from: Date().addingTimeInterval(14 * 86400))
        let qs     = "timeMin=\(now)&timeMax=\(future)&singleEvents=true&orderBy=startTime&maxResults=50"
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events?\(qs)") else {
            isLoading = false; return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { isLoading = false; return }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        Self.log.info("GoogleCal: events HTTP \(status)")
        if status == 200,
           let raw = try? JSONDecoder().decode(GCalEventsResponse.self, from: data) {
            events = raw.items.compactMap { $0.toEvent() }
        } else if status == 401 {
            isAuthenticated = false
        }
        isLoading = false
    }

    // Natural-language quick add — Google parses the text on their side
    @discardableResult
    func quickAdd(_ text: String) async -> Bool {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty,
              let token = await validToken(),
              let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/quickAdd?text=\(encoded)")
        else { return false }

        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        let ok = (resp as? HTTPURLResponse)?.statusCode == 200
        Self.log.info("GoogleCal: quickAdd '\(text)' → HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        if ok { await fetchEvents() }
        return ok
    }

    // Structured event creation
    @discardableResult
    func createEvent(title: String, start: Date, end: Date, description: String? = nil) async -> Bool {
        guard let token = await validToken(),
              let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")
        else { return false }

        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        var body: [String: Any] = [
            "summary": title,
            "start": ["dateTime": iso.string(from: start),  "timeZone": TimeZone.current.identifier],
            "end":   ["dateTime": iso.string(from: end),    "timeZone": TimeZone.current.identifier],
        ]
        if let d = description { body["description"] = d }

        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        let ok = (resp as? HTTPURLResponse)?.statusCode == 200
        if ok { await fetchEvents() }
        return ok
    }

    // MARK: – Helpers

    private func scheduleAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { await self?.fetchEvents() }
        }
    }

    private func store(access: String, refresh: String, expiresIn: TimeInterval) {
        accessToken  = access
        refreshToken = refresh
        tokenExpiry  = Date().addingTimeInterval(expiresIn - 60)
        let d = UserDefaults.standard
        d.set(access,       forKey: Self.accessKey)
        d.set(refresh,      forKey: Self.refreshKey)
        d.set(tokenExpiry,  forKey: Self.expiryKey)
    }

    private func loadStoredTokens() {
        let d = UserDefaults.standard
        accessToken  = d.string(forKey: Self.accessKey)
        refreshToken = d.string(forKey: Self.refreshKey)
        tokenExpiry  = d.object(forKey: Self.expiryKey) as? Date ?? .distantPast
        isAuthenticated = accessToken != nil && tokenExpiry > Date()
    }
}
