import SwiftUI

struct IslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    private var islandW: CGFloat { viewModel.islandWidth }
    private var islandH: CGFloat { viewModel.islandHeight }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            let topR:    CGFloat = topRadius
            let bottomR: CGFloat = bottomRadius

            IslandShape(topRadius: topR, bottomRadius: bottomR)
                .fill(Color.black)
                .frame(width: islandW, height: islandH)
                // Warm amber tint during final 5% of timer
                .overlay(
                    Color(red: 1, green: 0.45, blue: 0)
                        .opacity(viewModel.isTimerWarning ? 0.13 : 0)
                        .clipShape(IslandShape(topRadius: topR, bottomRadius: bottomR))
                        .animation(.easeInOut(duration: 0.9), value: viewModel.isTimerWarning)
                )
                .overlay(alignment: .top) {
                    islandContent
                        .frame(width: islandW, height: islandH)
                        .clipped()
                }
                // MIDI neon glow — bottom edge capsule that flashes on MIDI events
                .overlay(alignment: .bottom) {
                    midiGlowLine
                }
                .shadow(
                    color: (viewModel.state.isRaised || viewModel.isHovering) ? .black.opacity(0.45) : .clear,
                    radius: 16, x: 0, y: 8
                )
                .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: islandW)
                .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: islandH)
                .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: topR)
                .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: bottomR)
                .onTapGesture { handleTap() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: – Corner radii per state

    private var topRadius: CGFloat {
        switch viewModel.state {
        case .compact, .alert, .mailDrop, .peek: return 0
        case .expanded:                          return kIslandCornerRadius
        }
    }

    private var bottomRadius: CGFloat {
        switch viewModel.state {
        case .compact:            return kNotchBottomRadius
        case .alert:              return kNotchBottomRadius
        case .mailDrop:           return kIslandCornerRadius
        case .peek:               return kIslandCornerRadius
        case .expanded:           return kIslandCornerRadius
        }
    }

    // MARK: – Content per state

    @ViewBuilder
    private var islandContent: some View {
        switch viewModel.state {
        case .compact:
            if viewModel.isHovering {
                HoverPreviewView(viewModel: viewModel)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.isHovering)
            } else {
                CompactIslandView(viewModel: viewModel)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.isHovering)
            }
        case .alert:
            AlertPreviewView(viewModel: viewModel)
        case .mailDrop(let msg):
            MailDropView(message: msg, viewModel: viewModel)
        case .peek:
            PeekView(viewModel: viewModel)
        case .expanded(let module):
            ExpandedIslandView(module: module, viewModel: viewModel)
        }
    }

    // MARK: – Tap handling

    private func handleTap() {
        switch viewModel.state {
        case .compact:
            viewModel.expand(to: viewModel.contextManager.suggestedModule)
        case .alert:
            viewModel.alertManager.clearAll()
            viewModel.expand(to: viewModel.contextManager.suggestedModule)
        case .mailDrop:
            viewModel.dismissMailDrop()
            viewModel.expand(to: .gmail)
        case .peek:
            viewModel.expand(to: viewModel.peekTargetModule)
        case .expanded:
            break  // taps inside expanded handled by child views
        }
    }

    // MARK: – MIDI glow overlay

    private var midiGlowLine: some View {
        let neonGreen = Color(red: 0, green: 1.0, blue: 0.40)
        return Capsule()
            .fill(neonGreen)
            .frame(height: 2)
            .padding(.horizontal, 24)
            .shadow(color: neonGreen.opacity(0.9), radius: 4,  x: 0, y: 0)
            .shadow(color: neonGreen.opacity(0.6), radius: 10, x: 0, y: 0)
            .shadow(color: neonGreen.opacity(0.3), radius: 20, x: 0, y: 0)
            .opacity(viewModel.midiGlowOpacity)
    }
}
