import EventKit
import Foundation

class CalendarManager: ObservableObject {
    @Published var events: [CalendarEventInfo] = []
    @Published var selectedDate: Date = Date()

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    init() {
        requestAccess()
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in self?.fetchForSelectedDate() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    deinit { refreshTimer?.invalidate() }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { self?.fetchForSelectedDate() }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { self?.fetchForSelectedDate() }
            }
        }
    }

    func fetchToday() { fetchForSelectedDate() }

    func fetchForSelectedDate() {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }

        // For today, only show events from now onwards; for other days, show the full day.
        let start = cal.isDateInToday(selectedDate) ? Date() : dayStart

        let pred = store.predicateForEvents(withStart: start, end: dayEnd, calendars: nil)
        let fetched = store.events(matching: pred)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
        events = fetched.prefix(4).map { ev in
            CalendarEventInfo(title: ev.title ?? "Untitled", startDate: ev.startDate, endDate: ev.endDate)
        }
    }

    func nextDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
        fetchForSelectedDate()
    }

    func prevDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
        fetchForSelectedDate()
    }

    @discardableResult
    func createEvent(title: String, minutesFromNow: Int = 60, durationMinutes: Int = 60) -> Bool {
        let start = Date().addingTimeInterval(TimeInterval(minutesFromNow * 60))
        let end   = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let event = EKEvent(eventStore: store)
        event.title     = title
        event.startDate = start
        event.endDate   = end
        event.calendar  = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            fetchForSelectedDate()
            return true
        } catch {
            return false
        }
    }

    // Next event starting within the next 2 hours — used by hover preview
    var nextUpcoming: CalendarEventInfo? {
        let horizon = Date().addingTimeInterval(2 * 3600)
        return events.first { $0.startDate <= horizon }
    }
}
