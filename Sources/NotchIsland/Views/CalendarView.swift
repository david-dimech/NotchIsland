import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: IslandViewModel

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
                Text(todayLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            if viewModel.calendarEvents.isEmpty {
                Spacer()
                Text("No upcoming events")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.calendarEvents) { ev in
                        EventRow(event: ev)
                        if ev.id != viewModel.calendarEvents.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.07))
                                .padding(.leading, 18)
                        }
                    }
                }
                .padding(.top, 6)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

private struct EventRow: View {
    let event: CalendarEventInfo

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Color stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(Self.fmt.string(from: event.startDate))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}
