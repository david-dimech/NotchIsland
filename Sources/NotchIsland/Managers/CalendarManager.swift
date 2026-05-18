import EventKit
import Foundation

class CalendarManager: ObservableObject {
    @Published var events: [CalendarEventInfo] = []

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    init() {
        requestAccess()
        // Refresh every 5 minutes
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in self?.fetchToday() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    deinit { refreshTimer?.invalidate() }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { self?.fetchToday() }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { self?.fetchToday() }
            }
        }
    }

    func fetchToday() {
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .hour, value: 18, to: now) else { return }
        let pred = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let fetched = store.events(matching: pred)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
        events = fetched.prefix(4).map { ev in
            CalendarEventInfo(title: ev.title ?? "Untitled", startDate: ev.startDate, endDate: ev.endDate)
        }
    }

    // Next event starting within the next 2 hours — used by hover preview
    var nextUpcoming: CalendarEventInfo? {
        let horizon = Date().addingTimeInterval(2 * 3600)
        return events.first { $0.startDate <= horizon }
    }
}
