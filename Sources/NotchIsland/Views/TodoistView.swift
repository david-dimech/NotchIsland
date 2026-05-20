import SwiftUI

struct TodoistView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var manager: TodoistManager
    @ObservedObject private var settings = SettingsManager.shared

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        self.manager   = viewModel.todoistManager
    }

    var body: some View {
        if settings.todoistAPIToken.isEmpty {
            noTokenView
        } else {
            mainView
        }
    }

    // MARK: – No token

    private var noTokenView: some View {
        VStack(spacing: 6) {
            Image(systemName: "key.fill")
                .font(.system(size: 18)).foregroundStyle(.white.opacity(0.25))
            Text("Add Todoist API token in Settings")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center).padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Main

    private var mainView: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().background(Color.white.opacity(0.07))
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: – Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TodoistTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer(minLength: 0)
            if manager.isLoading {
                ProgressView().progressViewStyle(.circular)
                    .scaleEffect(0.5).frame(width: 18, height: 18)
                    .padding(.trailing, 10)
            } else {
                Button { manager.refreshAll() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain).padding(.trailing, 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func tabButton(_ tab: TodoistTab) -> some View {
        let active  = manager.activeTab == tab
        let count   = taskCount(tab)
        return Button { withAnimation(.easeInOut(duration: 0.15)) { manager.activeTab = tab } } label: {
            HStack(spacing: 3) {
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? .white : .white.opacity(0.4))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(active ? .white.opacity(0.7) : .white.opacity(0.25))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(active ? 0.15 : 0.06)))
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(active ? 0.1 : 0))
            )
        }
        .buttonStyle(.plain)
    }

    private func taskCount(_ tab: TodoistTab) -> Int {
        switch tab {
        case .today:    return manager.todayTasks.count
        case .upcoming: return manager.upcomingGrouped.reduce(0) { $0 + $1.tasks.count }
        case .inbox:    return manager.inboxTasks.count
        }
    }

    // MARK: – Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch manager.activeTab {
        case .today:    TodayTabView(manager: manager)
        case .upcoming: UpcomingTabView(manager: manager)
        case .inbox:    InboxTabView(manager: manager)
        }
    }
}

// MARK: – Today tab

private struct TodayTabView: View {
    @ObservedObject var manager: TodoistManager
    @State private var newTaskText = ""
    @FocusState private var addFocused: Bool

    private var overdue: [TodoistTask] { manager.todayTasks.filter { $0.isOverdue } }
    private var dueToday: [TodoistTask] { manager.todayTasks.filter { !$0.isOverdue } }

    var body: some View {
        VStack(spacing: 0) {
            if manager.todayTasks.isEmpty {
                allDoneView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !overdue.isEmpty {
                            sectionHeader("Overdue", color: .red)
                            ForEach(overdue) { TaskRow(task: $0, manager: manager) }
                        }
                        if !dueToday.isEmpty {
                            if !overdue.isEmpty { sectionHeader("Today", color: .white.opacity(0.3)) }
                            ForEach(dueToday) { TaskRow(task: $0, manager: manager) }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            addBar(placeholder: "Add to today…", tab: .today)
        }
    }

    private var allDoneView: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20)).foregroundStyle(.green.opacity(0.6))
            Text("All done for today")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addBar(placeholder: String, tab: TodoistTab) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
            TextField(placeholder, text: $newTaskText)
                .font(.system(size: 10)).foregroundStyle(.white)
                .textFieldStyle(.plain).focused($addFocused)
                .onSubmit {
                    manager.addTask(newTaskText, tab: tab)
                    newTaskText = ""
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }
}

// MARK: – Upcoming tab

private struct UpcomingTabView: View {
    @ObservedObject var manager: TodoistManager
    @State private var newTaskText = ""

    var body: some View {
        VStack(spacing: 0) {
            if manager.upcomingGrouped.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(manager.upcomingGrouped) { group in
                            sectionHeader(group.label, color: .white.opacity(0.3))
                            ForEach(group.tasks) { TaskRow(task: $0, manager: manager) }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            addBar(placeholder: "Add task…", tab: .upcoming)
        }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18)).foregroundStyle(.white.opacity(0.2))
            Text("Nothing upcoming")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addBar(placeholder: String, tab: TodoistTab) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
            TextField(placeholder, text: $newTaskText)
                .font(.system(size: 10)).foregroundStyle(.white)
                .textFieldStyle(.plain)
                .onSubmit {
                    manager.addTask(newTaskText, tab: tab)
                    newTaskText = ""
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }
}

// MARK: – Inbox tab

private struct InboxTabView: View {
    @ObservedObject var manager: TodoistManager
    @State private var newTaskText = ""

    var body: some View {
        VStack(spacing: 0) {
            if manager.inboxTasks.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(manager.inboxTasks) { TaskRow(task: $0, manager: manager) }
                    }
                    .padding(.vertical, 3)
                }
            }
            addBar
        }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray")
                .font(.system(size: 18)).foregroundStyle(.white.opacity(0.2))
            Text("Inbox is empty")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
            TextField("Add to inbox…", text: $newTaskText)
                .font(.system(size: 10)).foregroundStyle(.white)
                .textFieldStyle(.plain)
                .onSubmit {
                    manager.addTask(newTaskText, tab: .inbox)
                    newTaskText = ""
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }
}

// MARK: – Shared task row

private struct TaskRow: View {
    let task: TodoistTask
    @ObservedObject var manager: TodoistManager
    @State private var completing = false
    @State private var expanded   = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { completing = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { manager.complete(task) }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(priorityColor.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                        if completing {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold)).foregroundStyle(priorityColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(task.content)
                    .font(.system(size: 11))
                    .foregroundStyle(task.isOverdue ? .red.opacity(0.9) : .white.opacity(0.85))
                    .lineLimit(1).strikethrough(completing)

                Spacer(minLength: 0)

                if let dueDate = task.dueDate, task.hasDueTime {
                    Text(timeString(dueDate))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(task.isOverdue ? .red.opacity(0.6) : .white.opacity(0.28))
                }
                if task.priority >= 3 {
                    Circle().fill(priorityColor).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }

            // Inline edit bar — appears on tap
            if expanded {
                HStack(spacing: 6) {
                    // Priority chips
                    ForEach([4, 3, 2, 1], id: \.self) { p in
                        Button {
                            manager.updateTask(task, priority: p)
                            withAnimation { expanded = false }
                        } label: {
                            Text("P\(5 - p)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(chipColor(p))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(chipColor(p).opacity(task.priority == p ? 0.25 : 0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().frame(height: 10).background(Color.white.opacity(0.15))
                    // Reschedule chips
                    scheduleChip("Today",  due: "today")
                    scheduleChip("Tmrw",   due: "tomorrow")
                    Spacer(minLength: 0)
                    // Delete
                    Button {
                        withAnimation { expanded = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { manager.deleteTask(task) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9)).foregroundStyle(.red.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(completing ? 0 : 1)
    }

    private func scheduleChip(_ label: String, due: String) -> some View {
        Button {
            manager.updateTask(task, dueString: due)
            withAnimation { expanded = false }
        } label: {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private var priorityColor: Color { chipColor(task.priority) }
    private func chipColor(_ p: Int) -> Color {
        switch p {
        case 4: return .red
        case 3: return .orange
        case 2: return .blue
        default: return .white.opacity(0.35)
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

// MARK: – Shared section header

private func sectionHeader(_ label: String, color: Color) -> some View {
    Text(label.uppercased())
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 2)
}
