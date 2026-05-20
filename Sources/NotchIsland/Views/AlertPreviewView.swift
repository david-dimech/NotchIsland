import SwiftUI

/// Compact alert bubble that fits within notchWidth×1.15 × notchHeight×1.10.
/// Shows a priority SF Symbol icon, up to 25-char text, and the originating source.
struct AlertPreviewView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        guard case .alert(let alert) = viewModel.state else { return AnyView(EmptyView()) }
        return AnyView(content(alert))
    }

    private func content(_ alert: AlertInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: alert.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(alert.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(alert.source)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let callback = alert.actionCallback {
                Button {
                    callback()
                    viewModel.alertManager.dismiss()
                } label: {
                    Text(alert.actionLabel ?? "Action")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.orange.opacity(0.8)))
                }
                .buttonStyle(.plain)
            } else if let url = alert.actionURL {
                Button {
                    NSWorkspace.shared.open(url)
                    viewModel.alertManager.dismiss()
                } label: {
                    Text(alert.actionLabel ?? "Join")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.green.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }

            Button {
                viewModel.alertManager.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }
}
