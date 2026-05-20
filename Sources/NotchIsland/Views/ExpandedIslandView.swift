import SwiftUI

struct ExpandedIslandView: View {
    let module: IslandModule
    @ObservedObject var viewModel: IslandViewModel

    @State private var moduleIndex: Int    = 0
    @State private var dragOffset: CGFloat = 0
    @State private var lastDeltaX: CGFloat = 0

    @ObservedObject private var settings = SettingsManager.shared

    private var modules: [IslandModule] { settings.enabledModules + [.settings] }

    // Crisp spring for page snapping — feels like a card flicking into place
    private let snapSpring = Animation.interpolatingSpring(
        mass: 1, stiffness: 500, damping: 40
    )

    private var safeIndex: Int { modules.isEmpty ? 0 : min(moduleIndex, modules.count - 1) }

    var body: some View {
        VStack(spacing: 0) {
            // Wings: sit beside the physical notch — prev/next module navigation
            wingsRow

            Divider().background(Color.white.opacity(0.08))

            GeometryReader { geo in
                let w = geo.size.width

                HStack(spacing: 0) {
                    ForEach(Array(modules.enumerated()), id: \.offset) { i, mod in
                        // Each module fills its exact page slot — padding and
                        // centering are handled inside the module view itself.
                        moduleView(mod)
                            .frame(width: w, height: geo.size.height)
                    }
                }
                // No .animation modifier — withAnimation drives all transitions.
                .offset(x: -CGFloat(safeIndex) * w + dragOffset)
            }
            .clipped()

            Divider().background(Color.white.opacity(0.08))

            pageIndicator
                .padding(.vertical, 5)
        }
        .onChange(of: modules.count) { _, count in
            // Clamp index when a module is hidden from settings
            let clamped = min(moduleIndex, max(0, count - 1))
            if clamped != moduleIndex { withAnimation(snapSpring) { moduleIndex = clamped } }
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

    // MARK: – Wings row (flanks the physical notch)

    private var wingsRow: some View {
        HStack(spacing: 0) {
            // Left wing — tap to go to previous module
            wingContent(index: safeIndex - 1, isLeft: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Notch gap — exactly matches the physical notch width
            Spacer().frame(width: viewModel.notchWidth)

            // Right wing — tap to go to next module
            wingContent(index: safeIndex + 1, isLeft: false)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: viewModel.notchHeight)
        .animation(.easeInOut(duration: 0.15), value: safeIndex)
    }

    @ViewBuilder
    private func wingContent(index: Int, isLeft: Bool) -> some View {
        if index >= 0, index < modules.count {
            let mod = modules[index]
            Button { switchTo(index) } label: {
                HStack(spacing: 3) {
                    if isLeft {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                    Image(systemName: mod.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                    if !isLeft {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                }
                .padding(.horizontal, isLeft ? 10 : 10)
                .frame(height: viewModel.notchHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: – Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<modules.count, id: \.self) { i in
                let active = i == moduleIndex
                let mod    = modules[i]
                Button { switchTo(i) } label: {
                    HStack(spacing: active ? 4 : 0) {
                        Image(systemName: mod.icon)
                            .font(.system(size: 8, weight: active ? .semibold : .regular))
                            .foregroundStyle(active ? .white : .white.opacity(0.35))
                        if active {
                            Text(mod.displayName)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        }
                    }
                    .padding(.horizontal, active ? 7 : 5)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(active ? Color.white.opacity(0.18) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: moduleIndex)
    }

    // MARK: – Module views

    @ViewBuilder
    private func moduleView(_ mod: IslandModule) -> some View {
        switch mod {
        case .nowPlaying:  NowPlayingView(viewModel: viewModel)
        case .calendar:    CalendarView(viewModel: viewModel)
        case .systemStats: SystemStatsView(viewModel: viewModel)
        case .timer:       TimerView(viewModel: viewModel)
        case .weather:     WeatherView(viewModel: viewModel)
        case .bluetooth:   BluetoothView(viewModel: viewModel)
        case .music:       MusicView()
        case .todoist:     TodoistView(viewModel: viewModel)
        case .gmail:       GmailView(viewModel: viewModel)
        case .notes:       NotesView()
        case .camera:      CameraCheckView()
        case .settings:    IslandSettingsView()
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

            if next != oldIndex {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                viewModel.expand(to: modules[next])
            }

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
