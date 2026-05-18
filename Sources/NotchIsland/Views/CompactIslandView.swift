import SwiftUI

struct CompactIslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Now playing indicator
            if viewModel.nowPlaying.isPlaying {
                Button {
                    viewModel.toggle(.nowPlaying)
                } label: {
                    MusicBarsView()
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }

            // Timer indicator
            if viewModel.timerState.isRunning {
                Button {
                    viewModel.toggle(.timer)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                        Text(viewModel.timerState.displayString)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            // Tap anywhere when idle to show stats
            if !viewModel.nowPlaying.isPlaying && !viewModel.timerState.isRunning {
                Button {
                    viewModel.toggle(.systemStats)
                } label: {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Animated music bars — the classic "currently playing" indicator
struct MusicBarsView: View {
    @State private var heights: [CGFloat] = [0.4, 0.8, 0.6]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.green)
                    .frame(width: 3, height: 16 * heights[i])
                    .animation(
                        .easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                        value: heights[i]
                    )
            }
        }
        .onAppear {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    heights[i] = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
}
