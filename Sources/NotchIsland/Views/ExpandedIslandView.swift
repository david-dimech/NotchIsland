import SwiftUI

struct ExpandedIslandView: View {
    let module: IslandModule
    @ObservedObject var viewModel: IslandViewModel

    // Swipe state
    @State private var moduleIndex: Int = 0
    @State private var dragOffset: CGFloat = 0

    private let modules: [IslandModule] = [.nowPlaying, .systemStats, .timer]

    var body: some View {
        VStack(spacing: 0) {
            // Module indicator dots (tap to switch, swiped between)
            HStack(spacing: 5) {
                ForEach(Array(modules.enumerated()), id: \.offset) { i, _ in
                    Circle()
                        .fill(i == moduleIndex ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 5, height: 5)
                        .animation(.easeInOut(duration: 0.2), value: moduleIndex)
                        .onTapGesture { switchTo(index: i) }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .background(Color.white.opacity(0.08))

            // Swipeable content area
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(Array(modules.enumerated()), id: \.offset) { i, mod in
                        moduleView(mod)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .offset(x: -CGFloat(moduleIndex) * geo.size.width + dragOffset)
                .animation(.interpolatingSpring(mass: 1, stiffness: 450, damping: 38), value: moduleIndex)
                .background(
                    // Intercept two-finger trackpad swipes
                    TrackpadScrollReader { deltaX, phase in
                        handleScroll(deltaX: deltaX, phase: phase, width: geo.size.width)
                    }
                )
            }
            .clipped()
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .onAppear {
            moduleIndex = modules.firstIndex(of: module) ?? 0
        }
        .onChange(of: module) { _, newModule in
            if let i = modules.firstIndex(of: newModule) {
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 450, damping: 38)) {
                    moduleIndex = i
                }
            }
        }
    }

    // MARK: – Module content

    @ViewBuilder
    private func moduleView(_ mod: IslandModule) -> some View {
        switch mod {
        case .nowPlaying:  NowPlayingView(viewModel: viewModel)
        case .systemStats: SystemStatsView(viewModel: viewModel)
        case .timer:       TimerView(viewModel: viewModel)
        }
    }

    // MARK: – Swipe logic

    private func switchTo(index: Int) {
        let clamped = max(0, min(index, modules.count - 1))
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 450, damping: 38)) {
            moduleIndex = clamped
        }
        viewModel.expand(to: modules[clamped])
    }

    private func handleScroll(deltaX: CGFloat, phase: NSEvent.Phase, width: CGFloat) {
        switch phase {
        case .changed:
            let atLeft  = moduleIndex == 0               && dragOffset > 0
            let atRight = moduleIndex == modules.count - 1 && dragOffset < 0
            let rubber: CGFloat = (atLeft || atRight) ? 0.18 : 1.0
            withAnimation(.interactiveSpring()) {
                dragOffset -= deltaX * rubber
            }

        case .ended, .cancelled:
            let threshold = width * 0.22
            let velocity  = dragOffset        // simple: direction determines snap
            var next = moduleIndex
            if velocity < -threshold && moduleIndex < modules.count - 1 { next += 1 }
            if velocity >  threshold && moduleIndex > 0                  { next -= 1 }

            withAnimation(.interpolatingSpring(mass: 1, stiffness: 450, damping: 38)) {
                moduleIndex  = next
                dragOffset   = 0
            }
            if next != moduleIndex { viewModel.expand(to: modules[next]) }

        default:
            break
        }
    }
}
