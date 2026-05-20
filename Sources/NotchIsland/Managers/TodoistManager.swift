import Foundation
import Combine
import os.log

// MARK: – Models

struct TodoistTask: Identifiable, Codable {
    let id: String
    let content: String
    let priority: Int       // API: 1=p4 (normal) … 4=p1 (urgent)
    let due: TodoistDue?
    let projectId: String?

    enum CodingKeys: String, CodingKey {
        case id, content, priority, due
        case projectId = "project_id"
    }

    // Resolved absolute due date (handles both date-only and datetime)
    var dueDate: Date? {
        guard let due else { return nil }
        if let dtStr = due.datetime {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: dtStr) { return d }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: dtStr)
        }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: due.date)
    }

    var hasDueTime: Bool { due?.datetime != nil }

    var isOverdue: Bool {
        guard let d = dueDate else { return false }
        return d < Date()
    }
}

struct TodoistDue: Codable {
    let date: String
    let datetime: String?
    let string: String?
}

struct TodoistProject: Identifiable, Codable {
    let id: String
    let name: String
    let isInboxProject: Bool
    enum CodingKeys: String, CodingKey {
        case id, name
        case isInboxProject = "is_inbox_project"
    }
}

enum TodoistTab: String, CaseIterable {
    case today    = "Today"
    case upcoming = "Upcoming"
    case inbox    = "Inbox"
}

struct TodoistTaskGroup: Identifiable {
    let id = UUID()
    let label: String
    let tasks: [TodoistTask]
}

struct TodoistError {
    let httpStatus: Int?
    let message: String
    let responseSnippet: String?
}

// MARK: – Manager

@MainActor
final class TodoistManager: ObservableObject {
    @Published private(set) var todayTasks:    [TodoistTask]    = []
    @Published private(set) var upcomingTasks: [TodoistTask]    = []
    @Published private(set) var inboxTasks:    [TodoistTask]    = []
    @Published private(set) var projects:      [TodoistProject] = []
    @Published private(set) var isLoading:     Bool             = false
    @Published private(set) var lastError:     TodoistError?    = nil
    @Published var activeTab: TodoistTab = .today

    var onOverdueAlert: ((TodoistTask) -> Void)?

    private var refreshCancellable: AnyCancellable?
    private var alertedIDs: Set<String> = []
    private static let log = Logger(subsystem: "com.notchisland.app", category: "Todoist")

    // MARK: – Focus task (drives hover preview)

    /// The single most important task to surface right now.
    var focusTask: TodoistTask? {
        let today = todayTasks
        // 1 – overdue P1
        if let t = today.first(where: { $0.isOverdue && $0.priority == 4 }) { return t }
        // 2 – P1 today
        if let t = today.first(where: { $0.priority == 4 }) { return t }
        // 3 – due within 2 hours (has a time set)
        let soon = Date().addingTimeInterval(7200)
        if let t = today.first(where: { $0.hasDueTime && ($0.dueDate ?? .distantFuture) <= soon }) { return t }
        // 4 – any overdue
        if let t = today.first(where: { $0.isOverdue }) { return t }
        // 5 – highest priority today task (list is already sorted desc)
        if let t = today.first { return t }
        // 6 – earliest upcoming
        return upcomingTasks.first
    }

    // MARK: – Upcoming grouped by date

    var upcomingGrouped: [TodoistTaskGroup] {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
        let eligible = upcomingTasks.filter {
            guard let d = $0.dueDate else { return false }
            return cal.startOfDay(for: d) >= tomorrow
        }
        let byDay = Dictionary(grouping: eligible) { cal.startOfDay(for: $0.dueDate ?? .distantFuture) }
        return byDay.sorted { $0.key < $1.key }.map { (date, tasks) in
            let label: String
            if cal.isDateInTomorrow(date) {
                label = "Tomorrow"
            } else {
                let fmt = DateFormatter()
                let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: date).day ?? 0
                fmt.dateFormat = days < 7 ? "EEEE" : "EEEE, MMM d"
                label = fmt.string(from: date)
            }
            return TodoistTaskGroup(label: label, tasks: tasks.sorted { $0.priority > $1.priority })
        }
    }

    // MARK: – Lifecycle

    func start() {
        refreshAll()
        refreshCancellable = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshAll() }
    }

    func refreshAll() {
        let token = SettingsManager.shared.todoistAPIToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            todayTasks = []; upcomingTasks = []; inboxTasks = []; lastError = nil; return
        }
        isLoading = true; lastError = nil
        Self.log.info("Todoist: full refresh")

        Task { [weak self] in
            guard let self else { return }

            // Projects (needed for inbox ID)
            if let projs = await self.fetchProjects(token: token) {
                self.projects = projs
            }

            let inboxID = self.projects.first(where: { $0.isInboxProject })?.id

            // Parallel fetches
            async let td = self.fetchTasks(token: token, filter: "today | overdue")
            async let up = self.fetchTasks(token: token, filter: "next 14 days")
            async let ib = inboxID != nil
                ? self.fetchTasks(token: token, projectID: inboxID!)
                : [TodoistTask]()

            let (today, upcoming, inbox) = await (td, up, ib)

            self.todayTasks    = today.sorted    { $0.priority > $1.priority }
            self.upcomingTasks = upcoming.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            self.inboxTasks    = inbox.sorted    { $0.priority > $1.priority }
            self.isLoading     = false
            self.fireOverdueAlerts()
        }
    }

    // MARK: – Task operations

    func complete(_ task: TodoistTask) {
        todayTasks.removeAll    { $0.id == task.id }
        upcomingTasks.removeAll { $0.id == task.id }
        inboxTasks.removeAll    { $0.id == task.id }
        alertedIDs.remove(task.id)
        let token = SettingsManager.shared.todoistAPIToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        Task {
            guard let url = URL(string: "https://api.todoist.com/api/v1/tasks/\(task.id)/close") else { return }
            var req = URLRequest(url: url); req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    func addTask(_ content: String, tab: TodoistTab) {
        let c = content.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        let token = SettingsManager.shared.todoistAPIToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            guard let url = URL(string: "https://api.todoist.com/api/v1/tasks") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 10

            var body: [String: Any] = ["content": c]
            switch tab {
            case .today:    body["due_string"] = "today"
            case .upcoming: break
            case .inbox:
                if let id = self.projects.first(where: { $0.isInboxProject })?.id {
                    body["project_id"] = id
                }
            }
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (_, resp) = (try? await URLSession.shared.data(for: req)) ?? (nil, nil)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            Self.log.info("Todoist: addTask → HTTP \(status)")
            self.refreshAll()
        }
    }

    // MARK: – Network helpers

    private func fetchProjects(token: String) async -> [TodoistProject]? {
        guard let url = URL(string: "https://api.todoist.com/api/v1/projects") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        // v1 might return wrapped or plain array
        if let wrapped = try? JSONDecoder().decode(TodoistProjectsResponse.self, from: data) {
            return wrapped.results
        }
        return try? JSONDecoder().decode([TodoistProject].self, from: data)
    }

    private func fetchTasks(token: String, filter: String) async -> [TodoistTask] {
        let encoded = filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filter
        let urlStr  = "https://api.todoist.com/api/v1/tasks?filter=\(encoded)"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url); req.timeoutInterval = 15
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else {
            let body = String(data: (try? await URLSession.shared.data(for: req).0) ?? Data(), encoding: .utf8) ?? ""
            let http  = try? await URLSession.shared.data(for: req)  // already fetched above — skip re-fetch
            Self.log.error("Todoist: fetchTasks(\(filter)) failed")
            return []
        }

        if let wrapped = try? JSONDecoder().decode(TodoistTasksResponse.self, from: data) { return wrapped.results }
        return (try? JSONDecoder().decode([TodoistTask].self, from: data)) ?? []
    }

    private func fetchTasks(token: String, projectID: String) async -> [TodoistTask] {
        let urlStr = "https://api.todoist.com/api/v1/tasks?project_id=\(projectID)"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url); req.timeoutInterval = 15
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }

        if let wrapped = try? JSONDecoder().decode(TodoistTasksResponse.self, from: data) { return wrapped.results }
        return (try? JSONDecoder().decode([TodoistTask].self, from: data)) ?? []
    }

    // MARK: – Overdue alerts

    private func fireOverdueAlerts() {
        guard SettingsManager.shared.todoistAlertsEnabled else { return }
        for task in todayTasks where !alertedIDs.contains(task.id) && task.isOverdue {
            alertedIDs.insert(task.id)
            onOverdueAlert?(task)
        }
    }
}

// MARK: – Private response wrappers

private struct TodoistTasksResponse: Codable    { let results: [TodoistTask] }
private struct TodoistProjectsResponse: Codable { let results: [TodoistProject] }
