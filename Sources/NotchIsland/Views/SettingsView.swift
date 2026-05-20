import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                Text("NotchIsland")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)

            Divider().background(Color.white.opacity(0.12))

            List {
                // MARK: Widgets section
                Section {
                    ForEach(settings.moduleOrder, id: \.self) { mod in
                        ModuleRow(
                            module: mod,
                            enabled: settings.isEnabled(mod)
                        ) { settings.toggle(mod) }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))
                    }
                    .onMove { settings.move(from: $0, to: $1) }
                } header: {
                    Text("WIDGETS  ·  drag to reorder")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                // MARK: Google Calendar section
                Section {
                    GoogleCalendarSection()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))
                } header: {
                    Text("GOOGLE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                // MARK: Todoist section
                Section {
                    TodoistTokenRow(settings: settings)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))

                    SettingsToggleRow(
                        icon: "bell.badge",
                        label: "Overdue alerts",
                        isOn: Binding(
                            get:  { settings.todoistAlertsEnabled },
                            set:  { settings.setTodoistAlerts($0) }
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))
                } header: {
                    Text("TODOIST")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                // MARK: Notifications section
                Section {
                    SettingsToggleRow(
                        icon: "bell.fill",
                        label: "Route notifications to notch",
                        isOn: Binding(
                            get:  { settings.notifInterceptEnabled },
                            set:  { v in
                                settings.setNotifIntercept(v)
                                if v {
                                    NotificationInterceptor.requestPermission()
                                    IslandViewModel.shared.notificationInterceptor.start()
                                }
                            }
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))

                    SettingsToggleRow(
                        icon: "moon.fill",
                        label: "Show alerts during Focus / DND",
                        isOn: Binding(
                            get:  { settings.notifBypassDND },
                            set:  { settings.setNotifBypassDND($0) }
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))
                } header: {
                    Text("NOTIFICATIONS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                // MARK: Timer section
                Section {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        Text("Alert Sound")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Picker("", selection: Binding(
                            get:  { settings.timerSoundName },
                            set:  { settings.setTimerSound($0) }
                        )) {
                            ForEach(SettingsManager.availableSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 110)
                        .onChange(of: settings.timerSoundName) { _, name in
                            NSSound(named: .init(name))?.play()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 2, leading: 12, bottom: 2, trailing: 12))
                } header: {
                    Text("TIMER")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 6)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .preferredColorScheme(.dark)
    }
}

// MARK: – Google section (Calendar + Gmail, one sign-in)

private struct GoogleCalendarSection: View {
    @ObservedObject private var gcal = IslandViewModel.shared.googleCalendarManager

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: gcal.isAuthenticated ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 13))
                    .foregroundStyle(gcal.isAuthenticated ? .green : .white.opacity(0.3))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(gcal.isAuthenticated ? "Connected to Google" : "Not connected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(gcal.isAuthenticated ? .white : .white.opacity(0.45))
                    if gcal.isAuthenticated {
                        Text("Calendar · Gmail")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
                    }
                }
                Spacer()
                if gcal.isAuthenticated {
                    Button("Disconnect") { gcal.signOut() }
                        .font(.system(size: 11)).foregroundStyle(.red.opacity(0.8)).buttonStyle(.plain)
                } else {
                    Button("Connect with Google") { gcal.startSignIn() }
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.blue).buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))

            if let msg = gcal.statusMessage {
                Text(msg)
                    .font(.system(size: 9)).foregroundStyle(.orange.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
            }
        }
    }
}

// MARK: – Todoist token row

private struct TodoistTokenRow: View {
    @ObservedObject var settings: SettingsManager
    @State private var draft: String = ""
    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)

            Group {
                if revealed {
                    TextField("API token", text: $draft)
                        .focused($focused)
                } else {
                    SecureField("API token", text: $draft)
                        .focused($focused)
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.white)
            .textFieldStyle(.plain)
            .onChange(of: draft) { _, v in settings.setTodoistToken(v.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .onAppear { draft = settings.todoistAPIToken }

            Button { revealed.toggle() } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}

// MARK: – Generic toggle row

private struct SettingsToggleRow: View {
    let icon: String
    let label: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isOn.wrappedValue ? .white : .white.opacity(0.25))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isOn.wrappedValue ? .white : .white.opacity(0.35))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
        .animation(.easeInOut(duration: 0.15), value: isOn.wrappedValue)
    }
}

// MARK: – Module row

private struct ModuleRow: View {
    let module: IslandModule
    let enabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.icon)
                .font(.system(size: 13))
                .foregroundColor(enabled ? .white : .white.opacity(0.25))
                .frame(width: 20)

            Text(module.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(enabled ? .white : .white.opacity(0.35))

            Spacer()

            Toggle("", isOn: Binding(get: { enabled }, set: { _ in onToggle() }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .animation(.easeInOut(duration: 0.15), value: enabled)
    }
}
