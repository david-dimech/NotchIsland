import SwiftUI

// The compact state is intentionally minimal — it reads as an extension of the
// physical notch. Status is communicated by small coloured dots only, so the
// island stays unobtrusive when the user isn't interacting with it.
struct CompactIslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 6) {
            Spacer()

            // Now-playing dot (green)
            if viewModel.nowPlaying.isPlaying {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
            }

            // Timer dot (orange) with live countdown
            if viewModel.timerState.isRunning {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.nowPlaying.isPlaying)
        .animation(.easeInOut(duration: 0.25), value: viewModel.timerState.isRunning)
        // The entire compact island is one tap target (handled in IslandView)
    }
}
