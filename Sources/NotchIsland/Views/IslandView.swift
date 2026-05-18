import SwiftUI

struct IslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    private var islandW: CGFloat { viewModel.islandWidth }
    private var islandH: CGFloat { viewModel.islandHeight }

    // Hover scale only applies in compact state — expanded island stays stable
    private var hoverScale: CGFloat {
        (viewModel.isHovering && !viewModel.state.isExpanded) ? kHoverScale : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Transparent layer — clicks pass through to whatever is behind
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            // The island — a rounded rectangle that grows down from the notch
            RoundedRectangle(cornerRadius: kIslandCornerRadius, style: .continuous)
                .fill(Color.black)
                .frame(width: islandW, height: islandH)
                .overlay(alignment: .top) {
                    islandContent
                        .frame(width: islandW, height: islandH)
                        .clipped()
                }
                // Expand shadow only when open so compact blends into the notch
                .shadow(
                    color: viewModel.state.isExpanded ? .black.opacity(0.45) : .clear,
                    radius: 16, x: 0, y: 8
                )
                .scaleEffect(hoverScale, anchor: .top)
                .animation(IslandViewModel.hoverSpring, value: hoverScale)
                // Width and height animate with the organic expand spring
                .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: islandW)
                .animation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 18), value: islandH)
                // Tap on compact island to expand to the contextually relevant module
                .onTapGesture {
                    guard case .compact = viewModel.state else { return }
                    viewModel.expand(to: viewModel.contextManager.suggestedModule)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var islandContent: some View {
        switch viewModel.state {
        case .compact:
            CompactIslandView(viewModel: viewModel)
        case .expanded(let module):
            ExpandedIslandView(module: module, viewModel: viewModel)
        }
    }
}
