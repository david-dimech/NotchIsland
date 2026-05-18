import SwiftUI

struct ExpandedIslandView: View {
    let module: IslandModule
    @ObservedObject var viewModel: IslandViewModel

    @State private var moduleIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var lastEventDeltaX: CGFloat = 0   // used for velocity-based snap

    private let modules: [IslandModule] = [.nowPlaying, .systemStats, .timer]
    private let snapSpring = Animation.interpolatingSpring(mass: 1, stiffness: 420, damping: 36)

    var body: some View {
        VStack(spacing: 0) {
            pageIndicator
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.08))

            GeometryReader { geo in
                // All modules live in a single HStack; we slide it left/right.
                HStack(spacing: 0) {
                    ForEach(Array(modules.enumerated()), id: \.offset) { i, mod in
                        moduleView(mod)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                // Animate only on index snap; drag offset updates are direct/instant.
                .offset(x: -CGFloat(moduleIndex) * geo.size.width + dragOffset)
                .animation(snapSpring, value: moduleIndex)
                .background(
                    TrackpadScrollReader { deltaX, phase in
                        handleScroll(deltaX: deltaX, phase: phase, width: geo.size.width)
                    }
                )
            }
            .clipped()
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
        }
        .onAppear { moduleIndex = modules.firstIndex(of: module) ?? 0 }
        .onChange(of: module) { _, m in
            if let i = modules.firstIndex(of: m), i != moduleIndex {
                withAnimation(snapSpring) { moduleIndex = i }
            }
        }
    }

    // MARK: – Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<modules.count, id: \.self) { i in
                if i == moduleIndex {
                    // Active: wide capsule
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 18, height: 5)
                } else {
                    // Inactive: small circle, tap to jump
                    Circle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                        .onTapGesture { switchTo(i) }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: moduleIndex)
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

    // MARK: – Swipe

    private func switchTo(_ index: Int) {
        let i = max(0, min(index, modules.count - 1))
        withAnimation(snapSpring) { moduleIndex = i }
        // Expand to the new module so the ViewModel stays in sync
        viewModel.expand(to: modules[i])
    }

    private func handleScroll(deltaX: CGFloat, phase: NSEvent.Phase, width: CGFloat) {
        switch phase {

        case .changed:
            // *** Direct, no-animation update so the content follows the finger 1:1 ***
            // Rubber-band resistance at the ends so you feel the boundary.
            let atStart = moduleIndex == 0               && dragOffset > 0
            let atEnd   = moduleIndex == modules.count - 1 && dragOffset < 0
            let rubber: CGFloat = (atStart || atEnd) ? 0.15 : 1.0
            dragOffset += deltaX * rubber
            lastEventDeltaX = deltaX

        case .ended, .cancelled:
            // A "quick flick" (last event had large velocity) triggers the page
            // change even if the accumulated offset is small.
            let isFlick     = abs(lastEventDeltaX) > 4
            let threshold   = isFlick ? 12 : width * 0.2

            let oldIndex = moduleIndex           // save BEFORE mutating
            var next = oldIndex
            if dragOffset < -threshold, oldIndex < modules.count - 1 { next = oldIndex + 1 }
            if dragOffset >  threshold, oldIndex > 0                  { next = oldIndex - 1 }

            withAnimation(snapSpring) {
                moduleIndex = next
                dragOffset  = 0
            }
            lastEventDeltaX = 0

            // Sync viewModel only when the module actually changed
            if next != oldIndex {
                viewModel.expand(to: modules[next])
            }

        default:
            break
        }
    }
}
