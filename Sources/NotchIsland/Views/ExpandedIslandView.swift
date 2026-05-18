import SwiftUI

struct ExpandedIslandView: View {
    let module: IslandModule
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header row: module switcher + close
            HStack {
                moduleTabBar
                Spacer()
                Button { viewModel.collapse() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.1))

            // Content
            Group {
                switch module {
                case .nowPlaying:  NowPlayingView(viewModel: viewModel)
                case .systemStats: SystemStatsView(viewModel: viewModel)
                case .timer:       TimerView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var moduleTabBar: some View {
        HStack(spacing: 6) {
            TabButton(icon: "music.note",    module: .nowPlaying,  current: module, vm: viewModel)
            TabButton(icon: "cpu",           module: .systemStats, current: module, vm: viewModel)
            TabButton(icon: "timer",         module: .timer,       current: module, vm: viewModel)
        }
    }
}

private struct TabButton: View {
    let icon: String
    let module: IslandModule
    let current: IslandModule
    let vm: IslandViewModel

    var isActive: Bool { module == current }

    var body: some View {
        Button { vm.expand(to: module) } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.35))
                .padding(5)
                .background(isActive ? Color.white.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
