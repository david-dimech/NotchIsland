import SwiftUI

struct GmailView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var gmail:  GmailManager
    @ObservedObject private var gcal:   GoogleCalendarManager

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        self.gmail  = viewModel.gmailManager
        self.gcal   = viewModel.googleCalendarManager
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.07))
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            Text("Primary")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            if gmail.unreadCount > 0 {
                Text("\(gmail.unreadCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.blue))
            }
            Spacer()
            if gcal.isAuthenticated {
                Button {
                    Task { await gmail.fetchMessages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .rotationEffect(gmail.isLoading ? .degrees(360) : .zero)
                        .animation(gmail.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: gmail.isLoading)
                }
                .buttonStyle(.plain)

                Button { gmail.openInbox() } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: – Content

    @ViewBuilder
    private var content: some View {
        if !gcal.isAuthenticated {
            notConnectedView
        } else if gmail.messages.isEmpty && !gmail.isLoading {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(gmail.messages) { msg in
                        GmailRow(message: msg) { gmail.openMessage(id: msg.id) }
                        if msg.id != gmail.messages.last?.id {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    private var notConnectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 20)).foregroundStyle(.white.opacity(0.2))
            Text("Google not connected")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35))
            Button("Connect in Settings →") {
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.blue).buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "tray").font(.system(size: 18)).foregroundStyle(.white.opacity(0.2))
            Text("No primary emails").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Row

private struct GmailRow: View {
    let message: GmailMessage
    let onTap: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var timeLabel: String {
        if Calendar.current.isDateInToday(message.date) {
            return Self.timeFormatter.string(from: message.date)
        }
        return Self.dateFormatter.string(from: message.date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                // Unread dot
                Circle()
                    .fill(message.isUnread ? Color.blue : Color.clear)
                    .frame(width: 5, height: 5)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(message.fromName)
                            .font(.system(size: 11, weight: message.isUnread ? .semibold : .regular))
                            .foregroundStyle(message.isUnread ? .white : .white.opacity(0.65))
                            .lineLimit(1)
                        Spacer()
                        Text(timeLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Text(message.subject)
                        .font(.system(size: 10, weight: message.isUnread ? .medium : .regular))
                        .foregroundStyle(message.isUnread ? .white.opacity(0.9) : .white.opacity(0.5))
                        .lineLimit(1)
                    Text(message.snippet)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.28))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
