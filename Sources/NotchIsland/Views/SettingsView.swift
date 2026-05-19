import SwiftUI

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

            // Section header
            Text("WIDGETS  ·  drag to reorder")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // Module list
            List {
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .preferredColorScheme(.dark)
    }
}

// MARK: – Row

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
