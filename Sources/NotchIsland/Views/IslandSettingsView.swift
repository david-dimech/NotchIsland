import SwiftUI
import AppKit

struct IslandSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "gear")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Text("SETTINGS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(0.8)
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                } label: {
                    Text("More…")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.08))

            // Module toggles
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(settings.moduleOrder, id: \.self) { mod in
                        HStack(spacing: 8) {
                            Image(systemName: mod.icon)
                                .font(.system(size: 10))
                                .foregroundColor(settings.isEnabled(mod) ? .white.opacity(0.75) : .white.opacity(0.2))
                                .frame(width: 14)
                            Text(mod.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(settings.isEnabled(mod) ? .white.opacity(0.85) : .white.opacity(0.28))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get:  { settings.isEnabled(mod) },
                                set:  { _ in settings.toggle(mod) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension Notification.Name {
    static let openSettingsWindow    = Notification.Name("ni.openSettingsWindow")
    static let googleAuthDidComplete = Notification.Name("ni.googleAuthDidComplete")
}
