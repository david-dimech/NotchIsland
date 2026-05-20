import SwiftUI

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

            // Timer: live countdown in warning state, dot otherwise
            if viewModel.isTimerWarning {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(viewModel.timerState.displayString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else if viewModel.timerState.isRunning {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.35), value: viewModel.nowPlaying.isPlaying)
        .animation(.easeInOut(duration: 0.35), value: viewModel.timerState.isRunning)
        .animation(.easeInOut(duration: 0.35), value: viewModel.isTimerWarning)
    }
}
