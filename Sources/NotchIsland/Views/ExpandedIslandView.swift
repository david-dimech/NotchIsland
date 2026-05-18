import SwiftUI

struct ExpandedIslandView: View {
    let module: IslandModule
    @ObservedObject var viewModel: IslandViewModel

    @State private var moduleIndex: Int  = 0
    @State private var dragOffset: CGFloat = 0
    @State private var lastDeltaX: CGFloat = 0

    private let modules: [IslandModule] = [.nowPlaying, .systemStats, .timer]

    // Crisp spring for page snapping — feels like a card flicking into place
    private let snapSpring = Animation.interpolatingSpring(
        mass: 1, stiffness: 500, damping: 40
    )

    var body: some View {
        VStack(spacing: 0) {
            pageIndicator
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.08))

            GeometryReader { geo in
                let w = geo.size.width

                HStack(spacing: 0) {
                    ForEach(Array(modules.enumerated()), id: \.offset) { i, mod in
                        moduleView(mod)
                            .frame(width: w, height: geo.size.height)
                    }
                }
                // Offset has NO .animation modifier — all animation is driven
                // explicitly via withAnimation so drag is instant and snap springs.
                .offset(x: -CGFloat(moduleIndex) * w + dragOffset)
            }
            .clipped()
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
        }
        .onAppear {
            moduleIndex = modules.firstIndex(of: module) ?? 0
            // Register swipe handler — PillHitTestView (root NSView) delivers events here
            viewModel.onSwipeEvent = { [self] deltaX, phase in
                handleSwipe(deltaX: deltaX, phase: phase)
            }
        }
        .onDisappear {
            viewModel.onSwipeEvent = nil
        }
        .onChange(of: module) { _, m in
            guard let i = modules.firstIndex(of: m), i != moduleIndex else { return }
            withAnimation(snapSpring) { moduleIndex = i }
        }
    }

    // MARK: – Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<modules.count, id: \.self) { i in
                if i == moduleIndex {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 18, height: 5)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                        .contentShape(Circle())
                        .onTapGesture { switchTo(i) }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: moduleIndex)
    }

    // MARK: – Module views

    @ViewBuilder
    private func moduleView(_ mod: IslandModule) -> some View {
        switch mod {
        case .nowPlaying:  NowPlayingView(viewModel: viewModel)
        case .systemStats: SystemStatsView(viewModel: viewModel)
        case .timer:       TimerView(viewModel: viewModel)
        }
    }

    // MARK: – Swipe handler (called from PillHitTestView via viewModel.onSwipeEvent)

    private func handleSwipe(deltaX: CGFloat, phase: NSEvent.Phase) {
        switch phase {

        case .began, .changed:
            // Direct 1:1 tracking — no animation so finger and content move together.
            // Rubber-band resistance at the first/last page boundary.
            let pastStart = moduleIndex == 0               && dragOffset > 0
            let pastEnd   = moduleIndex == modules.count - 1 && dragOffset < 0
            let factor: CGFloat = (pastStart || pastEnd) ? 0.12 : 1.0
            dragOffset += deltaX * factor
            lastDeltaX  = deltaX

        case .ended, .cancelled:
            let oldIndex = moduleIndex   // capture BEFORE any mutation

            // A flick (fast last-event velocity) triggers a page change even with
            // minimal total travel. Threshold shrinks to 8 pt for flicks.
            let isFlick   = abs(lastDeltaX) > 3
            let threshold: CGFloat = isFlick ? 8 : 44

            var next = oldIndex
            if dragOffset < -threshold, oldIndex < modules.count - 1 { next = oldIndex + 1 }
            if dragOffset >  threshold, oldIndex > 0                  { next = oldIndex - 1 }

            // Single withAnimation covers BOTH the page-switch and the drag reset,
            // so they spring to the target together rather than jumping.
            withAnimation(snapSpring) {
                moduleIndex = next
                dragOffset  = 0
            }
            lastDeltaX = 0

            if next != oldIndex { viewModel.expand(to: modules[next]) }

        default:
            break
        }
    }

    private func switchTo(_ index: Int) {
        let i = max(0, min(index, modules.count - 1))
        withAnimation(snapSpring) { moduleIndex = i }
        viewModel.expand(to: modules[i])
    }
}
