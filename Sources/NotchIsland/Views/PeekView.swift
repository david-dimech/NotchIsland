import SwiftUI

/// Medium status panel (340×88pt) shown reactively when a background task is
/// active and the user hovers over the notch. Tapping expands to Full Opened.
struct PeekView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 14) {
            taskIcon
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(taskLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Text(taskSubtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: viewModel.timerState.displayString)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.expand(to: viewModel.peekTargetModule)
        }
    }

    @ViewBuilder
    private var taskIcon: some View {
        let t = viewModel.timerState
        if t.isRunning {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
                    .frame(width: 30, height: 30)
                Circle()
                    .trim(from: 0, to: t.progress)
                    .stroke(t.isBreak ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: t.progress)
                Image(systemName: t.isBreak ? "leaf.fill" : "timer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(t.isBreak ? .green : .orange)
            }
        } else {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var taskLabel: String {
        let t = viewModel.timerState
        if t.isRunning { return t.isBreak ? "Break" : "Focus" }
        return "Timer"
    }

    private var taskSubtitle: String {
        let t = viewModel.timerState
        if t.isRunning { return "\(t.displayString) remaining" }
        return "Tap to open"
    }
}
