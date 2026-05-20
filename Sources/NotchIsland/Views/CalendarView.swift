import SwiftUI

private enum CalSource: String, CaseIterable {
    case local  = "Local"
    case google = "Google"
}

struct CalendarView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var cal:   CalendarManager
    @ObservedObject private var gcal:  GoogleCalendarManager
    @State private var source: CalSource = .local
    @State private var quickText = ""
    @State private var quickFeedback: QuickFeedback? = nil
    @FocusState private var quickFocused: Bool

    enum QuickFeedback { case success, failure }

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        self.cal   = viewModel.calendarManager
        self.gcal  = viewModel.googleCalendarManager
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.07))
            content
            quickAddBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 6) {
            // Source toggle
            HStack(spacing: 0) {
                ForEach(CalSource.allCases, id: \.self) { s in
                    sourceTab(s)
                }
            }

            Spacer()

            // Day nav (local only)
            if source == .local {
                Button { cal.prevDay() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }.buttonStyle(.plain)

                Text(dateLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button { cal.nextDay() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }.buttonStyle(.plain)
            } else {
                // Google: auth status + refresh
                if gcal.isAuthenticated {
                    Button { Task { await gcal.fetchEvents() } } label: {
                        Image(systemName: gcal.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .rotationEffect(gcal.isLoading ? .degrees(360) : .zero)
                            .animation(gcal.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: gcal.isLoading)
                    }.buttonStyle(.plain)
                } else {
                    Text("Not connected")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func sourceTab(_ s: CalSource) -> some View {
        let active = source == s
        let showDot = s == .google && gcal.isAuthenticated
        return Button { withAnimation(.easeInOut(duration: 0.12)) { source = s } } label: {
            HStack(spacing: 3) {
                if showDot {
                    Circle().fill(Color.blue).frame(width: 4, height: 4)
                }
                Text(s.rawValue)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? .white : .white.opacity(0.38))
            }
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(active ? 0.1 : 0)))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Content

    @ViewBuilder
    private var content: some View {
        switch source {
        case .local:  localContent
        case .google: googleContent
        }
    }

    private var localContent: some View {
        Group {
            if viewModel.calendarEvents.isEmpty {
                emptyState("No events", icon: "calendar")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.calendarEvents) { ev in
                            EventRow(title: ev.title, start: ev.startDate, end: ev.endDate,
                                     source: .local, hangoutLink: nil)
                            if ev.id != viewModel.calendarEvents.last?.id {
                                Divider().background(Color.white.opacity(0.07)).padding(.leading, 18)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var googleContent: some View {
        Group {
            if !gcal.isAuthenticated {
                notConnectedView
            } else if gcal.events.isEmpty && !gcal.isLoading {
                emptyState("No upcoming events", icon: "calendar.badge.checkmark")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(gcal.events) { ev in
                            EventRow(title: ev.title, start: ev.start, end: ev.end,
                                     source: .google, hangoutLink: ev.hangoutLink)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notConnectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 20)).foregroundStyle(.white.opacity(0.2))
            Text("Google Calendar not connected")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35))
            Button("Connect in Settings →") {
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.blue).buttonStyle(.plain)
            if let msg = gcal.statusMessage {
                Text(msg).font(.system(size: 9)).foregroundStyle(.orange.opacity(0.7))
                    .multilineTextAlignment(.center).padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(_ label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(.white.opacity(0.2))
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Quick-add

    private var quickAddBar: some View {
        HStack(spacing: 6) {
            Image(systemName: quickFeedback == .success ? "checkmark" :
                              quickFeedback == .failure  ? "xmark"    : "plus")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(quickFeedback == .success ? Color.green :
                                 quickFeedback == .failure  ? Color.red   : Color.white.opacity(0.3))
                .animation(.easeInOut(duration: 0.15), value: quickFeedback)

            TextField(quickAddPlaceholder, text: $quickText)
                .font(.system(size: 10)).foregroundStyle(.white)
                .textFieldStyle(.plain).focused($quickFocused)
                .onSubmit { submitQuickAdd() }

            if source == .google, gcal.isAuthenticated {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 9)).foregroundStyle(.blue.opacity(0.6))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }

    private var quickAddPlaceholder: String {
        switch source {
        case .local:  return "New event…"
        case .google: return gcal.isAuthenticated ? "e.g. \"Team standup tomorrow 9am\"" : "Connect Google Calendar first"
        }
    }

    private func submitQuickAdd() {
        let text = quickText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        quickText = ""

        switch source {
        case .google where gcal.isAuthenticated:
            Task {
                let ok = await gcal.quickAdd(text)
                withAnimation { quickFeedback = ok ? .success : .failure }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { self.quickFeedback = nil }
                }
            }
        case .local, .google:
            // Create a local EK event starting in 1 hour for 1 hour as a placeholder
            // The user enters free-form text — we use it as the title
            let start = Date().addingTimeInterval(3600)
            let end   = start.addingTimeInterval(3600)
            _ = viewModel.calendarManager
            // Just call create via EK — CalendarManager can add this method
            // For now use a simple notification
            alertBrief("Event '\(text)' — use Calendar app for details")
        }
    }

    private func alertBrief(_ msg: String) {
        withAnimation { quickFeedback = .failure }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.quickFeedback = nil }
        }
    }

    // MARK: – Date label

    private var dateLabel: String {
        let c = Calendar.current
        if c.isDateInToday(cal.selectedDate)     { return "Today" }
        if c.isDateInYesterday(cal.selectedDate) { return "Yesterday" }
        if c.isDateInTomorrow(cal.selectedDate)  { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: cal.selectedDate)
    }
}

// MARK: – Shared event row

private struct EventRow: View {
    let title: String
    let start: Date
    let end: Date
    let source: CalSource
    let hangoutLink: String?

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(source == .google ? Color(red: 0.26, green: 0.52, blue: 0.96) : Color.blue)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Text(Self.fmt.string(from: start))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                    if let link = hangoutLink {
                        Button {
                            if let url = URL(string: link) { NSWorkspace.shared.open(url) }
                        } label: {
                            Label("Meet", systemImage: "video.fill")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
    }
}
