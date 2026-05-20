import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var t: TimerState { viewModel.timerState }

    @State private var alertPulse: Bool = false

    private let presets: [(label: String, minutes: Int)] = [
        ("1m", 1), ("5m", 5), ("15m", 15), ("25m", 25), ("45m", 45)
    ]

    var body: some View {
        HStack(spacing: 20) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(t.progress))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: t.progress)

                VStack(spacing: 1) {
                    Text(t.displayString)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(t.justFinished ? "Done!" : (t.isBreak ? "Break" : "Focus"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(t.justFinished ? .red : .white.opacity(0.45))
                        .textCase(.uppercase)
                }
            }
            .frame(width: 64, height: 64)
            .scaleEffect(alertPulse ? 1.08 : 1.0)
            .onChange(of: t.justFinished) { _, finished in
                if finished {
                    withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                        alertPulse = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { alertPulse = false }
                }
            }

            // Controls column
            VStack(alignment: .leading, spacing: 10) {
                // Quick-set presets
                HStack(spacing: 5) {
                    ForEach(presets, id: \.minutes) { p in
                        let active = Int(t.duration / 60) == p.minutes
                        Button { viewModel.setTimerDuration(minutes: p.minutes) } label: {
                            Text(p.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(active ? .white : .white.opacity(0.35))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(active ? Color.white.opacity(0.18) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Play / pause + reset
                HStack(spacing: 16) {
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ringColor: Color {
        if t.justFinished { return .red }
        return t.isBreak ? .green : .orange
    }
}
