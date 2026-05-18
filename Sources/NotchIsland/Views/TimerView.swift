import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var t: TimerState { viewModel.timerState }

    private let presets: [(label: String, minutes: Int)] = [
        ("5m", 5), ("15m", 15), ("25m", 25), ("45m", 45)
    ]

    var body: some View {
        HStack(spacing: 20) {
            // Ring + time
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: t.progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: t.progress)

                VStack(spacing: 2) {
                    Text(t.displayString)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(t.isBreak ? "Break" : "Focus")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .textCase(.uppercase)
                }
            }
            .frame(width: 72, height: 72)

            // Controls
            VStack(alignment: .leading, spacing: 8) {
                // Presets
                HStack(spacing: 6) {
                    ForEach(presets, id: \.minutes) { preset in
                        Button {
                            viewModel.setTimerDuration(minutes: preset.minutes)
                        } label: {
                            Text(preset.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Int(t.duration / 60) == preset.minutes ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Int(t.duration / 60) == preset.minutes
                                              ? Color.white.opacity(0.18)
                                              : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Play / Pause / Reset
                HStack(spacing: 14) {
                    Button {
                        t.isRunning ? viewModel.pauseTimer() : viewModel.startTimer()
                    } label: {
                        Image(systemName: t.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.resetTimer() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ringColor: Color {
        t.isBreak ? .green : .orange
    }
}
