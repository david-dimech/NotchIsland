import SwiftUI

struct IslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var pillWidth: CGFloat {
        switch viewModel.state {
        case .compact:   return kPillCompactWidth
        case .expanded:  return kPillExpandedWidth
        }
    }

    var pillHeight: CGFloat {
        switch viewModel.state {
        case .compact:   return kPillCompactHeight
        case .expanded:  return kPillExpandedHeight
        }
    }

    var cornerRadius: CGFloat { pillHeight / 2 }

    var body: some View {
        ZStack(alignment: .top) {
            // Transparent click-through background — must NOT intercept events
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            // The island pill
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
                .frame(width: pillWidth, height: pillHeight)
                .overlay(alignment: .top) {
                    pillContent
                        .frame(width: pillWidth, height: pillHeight)
                        .clipped()
                }
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: pillWidth)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: pillHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var pillContent: some View {
        switch viewModel.state {
        case .compact:
            CompactIslandView(viewModel: viewModel)
        case .expanded(let module):
            ExpandedIslandView(module: module, viewModel: viewModel)
        }
    }
}
