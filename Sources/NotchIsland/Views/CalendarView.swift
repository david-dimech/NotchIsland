import SwiftUI

private enum CalSource: String, CaseIterable {
    case local  = "Local"
    case google = "Google"
}

struct CalendarView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var cal:   CalendarManager
    @ObservedObject private var gcal:  GoogleCalendarManager
    @State private var source: CalSource = .google
    @State private var quickText = ""
    @State private var quickFeedback: QuickFeedback? = nil
    @FocusState private var quickFocused: Bool
    @State private var detailEvent: GCalEvent? = nil

    enum QuickFeedback { case success, failure }

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        self.cal   = viewModel.calendarManager
        self.gcal  = viewModel.googleCalendarManager
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.07))
                content
                quickAddBar
            }
            if let ev = detailEvent {
                eventDetailOverlay(ev)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: detailEvent?.id)
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
                                     isAllDay: false, source: .local, hangoutLink: nil)
                            if ev.id != viewModel.calendarEvents.last?.id {
                                Divider().background(Color.white.opacity(0.07)).padding(.leading, 18)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Google grouped by date

    private struct EventGroup: Identifiable {
        var id: Date { date }
        let date: Date
        let events: [GCalEvent]
    }

    private var groupedGoogleEvents: [EventGroup] {
        let cal = Calendar.current
        var dict: [Date: [GCalEvent]] = [:]
        for ev in gcal.events {
            let day = cal.startOfDay(for: ev.start)
            dict[day, default: []].append(ev)
        }
        return dict.keys.sorted().map { day in
            EventGroup(date: day, events: dict[day]!.sorted { $0.start < $1.start })
        }
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
                        ForEach(groupedGoogleEvents) { group in
                            dateSectionHeader(group.date)
                            ForEach(group.events) { ev in
                                EventRow(
                                    title: ev.title, start: ev.start, end: ev.end,
                                    isAllDay: ev.isAllDay, source: .google,
                                    hangoutLink: ev.hangoutLink,
                                    onTap: ev.htmlLink.flatMap(URL.init(string:)).map { url in
                                        { NSWorkspace.shared.open(url) }
                                    },
                                    onLongPress: { withAnimation { detailEvent = ev } }
                                )
                                if ev.id != group.events.last?.id {
                                    Divider().background(Color.white.opacity(0.07)).padding(.leading, 18)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dateSectionHeader(_ date: Date) -> some View {
        let cal = Calendar.current
        let label: String
        if cal.isDateInToday(date)     { label = "Today" }
        else if cal.isDateInTomorrow(date) { label = "Tomorrow" }
        else {
            let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
            label = f.string(from: date)
        }
        let isToday = cal.isDateInToday(date)
        return HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isToday ? Color.blue : Color.white.opacity(0.4))
            Rectangle()
                .fill(isToday ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
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
            let ok = viewModel.calendarManager.createEvent(title: text)
            withAnimation { quickFeedback = ok ? .success : .failure }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { self.quickFeedback = nil }
            }
        }
    }

    // MARK: – Event detail overlay

    private func eventDetailOverlay(_ ev: GCalEvent) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button { withAnimation { detailEvent = nil } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }.buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(ev.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text(eventTimeLabel(ev))
                        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                if let link = ev.hangoutLink, let url = URL(string: link) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("Join")
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.green.opacity(0.75)))
                    }.buttonStyle(.plain)
                }
                if let link = ev.htmlLink, let url = URL(string: link) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11)).foregroundStyle(.blue.opacity(0.7))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.07))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    if let loc = ev.location {
                        detailRow(icon: "mappin.and.ellipse", text: loc)
                    }
                    if let desc = ev.description, !desc.isEmpty {
                        detailRow(icon: "text.alignleft", text: desc)
                    }
                    if !ev.attendees.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("\(ev.attendees.count) guests", systemImage: "person.2")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            ForEach(ev.attendees.prefix(6), id: \.email) { a in
                                attendeeRow(a)
                            }
                            if ev.attendees.count > 6 {
                                Text("+\(ev.attendees.count - 6) more")
                                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .background(Color(white: 0.06))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                .frame(width: 12, alignment: .center).padding(.top, 1)
            Text(text).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                .lineLimit(4).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func attendeeRow(_ a: GCalEventAttendee) -> some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor(a.status)).frame(width: 5, height: 5)
            Text(a.name.isEmpty ? a.email : a.name)
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            if a.isOrganizer {
                Text("organizer").font(.system(size: 7)).foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "accepted":  return .green
        case "declined":  return .red
        case "tentative": return .orange
        default:          return .white.opacity(0.25)
        }
    }

    private func eventTimeLabel(_ ev: GCalEvent) -> String {
        if ev.isAllDay { return "All day" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d · HH:mm"
        let g = DateFormatter(); g.dateFormat = "HH:mm"
        return "\(f.string(from: ev.start)) – \(g.string(from: ev.end))"
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
    let isAllDay: Bool
    let source: CalSource
    let hangoutLink: String?
    var onTap:       (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var timeLabel: String {
        if isAllDay { return "All day" }
        return "\(Self.timeFmt.string(from: start)) – \(Self.timeFmt.string(from: end))"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(source == .google ? Color(red: 0.26, green: 0.52, blue: 0.96) : Color.blue)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeLabel)
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
            if onLongPress != nil {
                Image(systemName: "info.circle")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .contentShape(Rectangle())
        .gesture(
            onLongPress != nil
                ? LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in onLongPress?() }
                    .exclusively(before: TapGesture().onEnded { onTap?() })
                : nil
        )
        .onTapGesture { if onLongPress == nil { onTap?() } }
    }
}
