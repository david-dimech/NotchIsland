import SwiftUI
import AppKit

// Mail Drop — rich animated email notification card that drops from the Notch.
// Tapping the body opens the email; × dismisses without marking as read.
//
// Visual design: full animated border glow cycling blue → violet → teal,
// a matching sender badge, and a darkened gradient tint over the background.
struct MailDropView: View {
    let message: GmailMessage
    @ObservedObject var viewModel: IslandViewModel

    @State private var appeared = false

    var body: some View {
        TimelineView(.animation) { tl in
            let t   = tl.date.timeIntervalSinceReferenceDate
            let hue = (t * 0.06).truncatingRemainder(dividingBy: 1.0)
            let accent = Color(hue: hue, saturation: 0.75, brightness: 1.0)
            let accentDim = Color(hue: hue, saturation: 0.55, brightness: 0.7)

            ZStack(alignment: .leading) {
                // Background gradient tint — derives from accent
                LinearGradient(
                    colors: [accent.opacity(0.18), Color.black.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                HStack(spacing: 10) {
                    senderBadge(accent: accent)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            // "New mail" pill
                            Text("NEW")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Capsule().fill(accent.opacity(0.18)))

                            Text(message.fromName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Text(message.subject)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        if !message.snippet.isEmpty {
                            Text(message.snippet)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        Button {
                            viewModel.dismissMailDrop()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "envelope.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(accent.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [accent, accentDim.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 3)
                    .allowsHitTesting(false)
            }
            // Full animated border glow
            .overlay(
                RoundedRectangle(cornerRadius: kIslandCornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.85), accentDim.opacity(0.3), .clear, accentDim.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: accent.opacity(0.35), radius: 12, x: 0, y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Content fades in slightly after the island shape begins expanding downward,
        // so the shape's own spring animation provides the "drop from notch" feel.
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.18).delay(0.08)) { appeared = true }
        }
    }

    // MARK: – Sender badge

    private func senderBadge(accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(accent.opacity(0.4), lineWidth: 1.5)
                .frame(width: 38, height: 38)
            Text(String(message.fromName.prefix(1)).uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent)
        }
    }
}
