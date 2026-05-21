import SwiftUI

/// Hover peek panel (380×120 pt) — shown on every hover over the compact notch.
/// When a timer is running it leads with a progress ring; otherwise it shows a
/// rich snapshot of the most relevant live context.
struct PeekView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        Group {
            if viewModel.timerState.isRunning {
                timerLayout
            } else {
                contextLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.expand(to: viewModel.peekTargetModule) }
    }

    // MARK: – Timer layout (existing behaviour)

    private var timerLayout: some View {
        HStack(spacing: 14) {
            timerRing.frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)))

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.timerState.isBreak ? "Break" : "Focus")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text("\(viewModel.timerState.displayString) remaining")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: viewModel.timerState.displayString)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
    }

    private var timerRing: some View {
        let t = viewModel.timerState
        return ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 3).frame(width: 30, height: 30)
            Circle().trim(from: 0, to: t.progress)
                .stroke(t.isBreak ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30).rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: t.progress)
            Image(systemName: t.isBreak ? "leaf.fill" : "timer")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(t.isBreak ? .green : .orange)
        }
    }

    // MARK: – Context layout (Glance — hover without active timer)

    private var contextLayout: some View {
        VStack(spacing: 0) {
            // Pending email notifications (dismissable, not mark-as-read)
            if !viewModel.pendingEmailNotifications.isEmpty {
                pendingEmailsRow
                Divider().background(Color.white.opacity(0.07))
            }

            // Now Playing row — prominent if music is playing
            if viewModel.nowPlaying.isPlaying {
                nowPlayingRow
                if hasSecondRow { Divider().background(Color.white.opacity(0.07)) }
            }
            // Secondary info rows
            if let task = todoistFocusTask { taskRow(task) }
            else if let ev = nextEvent { calendarRow(ev) }
            if viewModel.weather.isLoaded && !viewModel.nowPlaying.isPlaying { weatherRow }
        }
        .padding(.horizontal, 14)
        .padding(.top, viewModel.notchHeight + 4)   // clear the physical notch hardware
        .padding(.bottom, 8)
    }

    private var hasSecondRow: Bool {
        todoistFocusTask != nil || nextEvent != nil
    }

    // Pending email notifications — show most recent, with per-email dismiss
    private var pendingEmailsRow: some View {
        let msg = viewModel.pendingEmailNotifications[0]
        return HStack(spacing: 8) {
            // Tappable area → open that email inside the Gmail widget
            Button {
                viewModel.dismissPendingEmail(msg)
                viewModel.openEmailInGmailWidget(id: msg.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue.opacity(0.8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(msg.fromName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white).lineLimit(1)
                        Text(msg.subject)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    }
                    Spacer()
                    // Badge for additional pending
                    if viewModel.pendingEmailNotifications.count > 1 {
                        Text("+\(viewModel.pendingEmailNotifications.count - 1)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Dismiss only — does not navigate
            Button {
                withAnimation { viewModel.dismissPendingEmail(msg) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 14, height: 14)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var todoistFocusTask: TodoistTask? {
        guard !SettingsManager.shared.todoistAPIToken.isEmpty else { return nil }
        return viewModel.todoistManager.focusTask
    }

    // Soonest upcoming event from local or Google calendar
    private var nextEvent: (title: String, date: Date, meetURL: URL?)? {
        let now = Date()
        var candidates: [(title: String, date: Date, meetURL: URL?)] = []

        if let ev = viewModel.calendarManager.nextUpcoming {
            candidates.append((ev.title, ev.startDate, nil))
        }
        if let gev = viewModel.googleCalendarManager.events.first(where: { $0.start > now }) {
            let url = gev.hangoutLink.flatMap(URL.init(string:))
            candidates.append((gev.title, gev.start, url))
        }
        return candidates.min(by: { $0.date < $1.date })
    }

    // Now Playing — artwork + title + artist + mini controls
    private var nowPlayingRow: some View {
        HStack(spacing: 10) {
            if let img = viewModel.nowPlaying.artwork {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.3)))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.nowPlaying.title)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(viewModel.nowPlaying.artist)
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
            }
            Spacer()
            // Mini transport controls
            HStack(spacing: 10) {
                miniBtn("backward.fill", size: 10) { viewModel.previousTrack() }
                miniBtn(viewModel.nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 13) { viewModel.togglePlayPause() }
                miniBtn("forward.fill",  size: 10) { viewModel.nextTrack() }
            }
        }
        .padding(.vertical, 4)
    }

    private func miniBtn(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size, weight: .medium))
                .foregroundStyle(.white).frame(width: size + 8, height: size + 8)
        }.buttonStyle(.plain)
    }

    // Todoist task row
    private func taskRow(_ task: TodoistTask) -> some View {
        HStack(spacing: 8) {
            let c: Color = task.priority == 4 ? .red : task.priority == 3 ? .orange : .blue
            Image(systemName: "checkmark.circle").font(.system(size: 11)).foregroundStyle(c)
            Text(task.content).font(.system(size: 11)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            Spacer()
            if task.isOverdue {
                Text("overdue").font(.system(size: 9)).foregroundStyle(.red.opacity(0.7))
            } else if let d = task.dueDate, task.hasDueTime {
                Text(timeFmt.string(from: d)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }

    // Calendar row (works for both local and Google events)
    private func calendarRow(_ ev: (title: String, date: Date, meetURL: URL?)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(.blue.opacity(0.8))
            Text(ev.title).font(.system(size: 11)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            Spacer()
            if let url = ev.meetURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Join")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.7)))
                }
                .buttonStyle(.plain)
            } else {
                Text(timeFmt.string(from: ev.date)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }

    // Weather row
    private var weatherRow: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.weather.sfSymbol).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            Text("\(Int(viewModel.weather.temperature))°  \(viewModel.weather.condition)")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            Spacer()
            if !viewModel.weather.city.isEmpty {
                Text(viewModel.weather.city).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3)).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
}
