import SwiftUI

// Shown when compact + hovering — a non-intrusive snapshot of live context.
// The island only grows 15 % wider / 20 % taller, so layout must be tight.
struct HoverPreviewView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        // Show at most 2 items; GeometryReader lets rows share the space evenly
        // without overflowing the island's fixed height.
        let items = rows
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 6) {
                    Image(systemName: row.icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(row.color)
                        .frame(width: 10)
                    Text(row.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if idx < items.count - 1 {
                    Spacer().frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Row model

    private struct Row {
        let icon: String
        let color: Color
        let text: String
    }

    private var rows: [Row] {
        var out: [Row] = []

        // Todoist focus task shown first — most actionable context
        if !SettingsManager.shared.todoistAPIToken.isEmpty,
           let task = viewModel.todoistManager.focusTask {
            let suffix: String
            if task.isOverdue {
                suffix = " · overdue"
            } else if let d = task.dueDate, task.hasDueTime {
                let f = DateFormatter(); f.dateFormat = "HH:mm"
                suffix = " · \(f.string(from: d))"
            } else {
                suffix = ""
            }
            let priorityColor: Color = task.priority == 4 ? .red : task.priority == 3 ? .orange : .blue
            out.append(Row(icon: "checkmark.circle", color: priorityColor,
                           text: task.content + suffix))
        }

        if viewModel.nowPlaying.isPlaying, !viewModel.nowPlaying.title.isEmpty {
            out.append(Row(icon: "music.note", color: .green,
                           text: viewModel.nowPlaying.title))
        }

        if viewModel.timerState.isRunning {
            out.append(Row(icon: "timer", color: .orange,
                           text: viewModel.timerState.displayString + " left"))
        }

        if let ev = viewModel.calendarManager.nextUpcoming {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            out.append(Row(icon: "calendar", color: .blue,
                           text: "\(fmt.string(from: ev.startDate)) · \(ev.title)"))
        }

        if viewModel.weather.isLoaded {
            out.append(Row(icon: viewModel.weather.sfSymbol, color: .white.opacity(0.55),
                           text: "\(Int(viewModel.weather.temperature))° · \(viewModel.weather.condition)"))
        }

        // Cap at 2 so content always fits in the small hover preview height
        return Array(out.prefix(2))
    }
}
