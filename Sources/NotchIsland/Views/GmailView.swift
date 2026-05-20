import SwiftUI

struct GmailView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var gmail:  GmailManager
    @ObservedObject private var gcal:   GoogleCalendarManager

    @State private var previewMessage: GmailMessage? = nil
    @State private var previewBody:    String?       = nil
    @State private var loadingPreview: Bool          = false

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        self.gmail  = viewModel.gmailManager
        self.gcal   = viewModel.googleCalendarManager
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.07))
                content
            }
            if let msg = previewMessage {
                emailPreview(msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: previewMessage?.id)
    }

    private func openPreview(_ msg: GmailMessage) {
        previewMessage = msg
        previewBody    = nil
        loadingPreview = true
        Task {
            let body = await gmail.fetchBody(id: msg.id)
            previewBody    = body
            loadingPreview = false
        }
    }

    // MARK: – Inline email preview

    private func emailPreview(_ msg: GmailMessage) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button { withAnimation { previewMessage = nil; previewBody = nil } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(msg.subject)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text(msg.fromName)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 10) {
                    if msg.isUnread {
                        previewAction("envelope.open", color: .white.opacity(0.5)) {
                            Task { await gmail.markAsRead(id: msg.id) }
                        }
                    }
                    previewAction("archivebox", color: .white.opacity(0.5)) {
                        Task { await gmail.archive(id: msg.id) }
                        withAnimation { previewMessage = nil }
                    }
                    previewAction("arrow.up.right.square", color: .blue.opacity(0.7)) {
                        gmail.openMessage(id: msg.id)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.07))

            // Body
            if loadingPreview {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(previewBody ?? msg.snippet)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
        }
        .background(Color(white: 0.06))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewAction(_ icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11))
                .foregroundStyle(color)
        }.buttonStyle(.plain)
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
                        GmailRow(
                            message: msg, gmail: gmail,
                            onTap:       { gmail.openMessage(id: msg.id) },
                            onLongPress: { openPreview(msg) }
                        )
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
    let message:     GmailMessage
    let gmail:       GmailManager
    let onTap:       () -> Void
    let onLongPress: () -> Void

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private var timeLabel: String {
        Calendar.current.isDateInToday(message.date)
            ? Self.timeFmt.string(from: message.date)
            : Self.dateFmt.string(from: message.date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(message.isUnread ? Color.blue : Color.clear)
                .frame(width: 5, height: 5).padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.fromName)
                        .font(.system(size: 11, weight: message.isUnread ? .semibold : .regular))
                        .foregroundStyle(message.isUnread ? .white : .white.opacity(0.65))
                        .lineLimit(1)
                    Spacer()
                    Text(timeLabel)
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                }
                Text(message.subject)
                    .font(.system(size: 10, weight: message.isUnread ? .medium : .regular))
                    .foregroundStyle(message.isUnread ? .white.opacity(0.9) : .white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6).contentShape(Rectangle())
        // Long press → preview; short tap → open in browser.
        // Using exclusive gestures so only one fires per interaction.
        .gesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in onLongPress() }
                .exclusively(before: TapGesture().onEnded { onTap() })
        )
    }
}
