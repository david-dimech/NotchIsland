import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var stats: SystemStats { viewModel.systemStats }

    var body: some View {
        HStack(spacing: 20) {
            StatGauge(
                icon: "cpu",
                label: "CPU",
                value: stats.cpuUsage,
                color: cpuColor
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.1))

            StatGauge(
                icon: "memorychip",
                label: "RAM",
                value: stats.memoryUsage,
                color: .blue
            )

            if stats.hasBattery {
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))

                StatGauge(
                    icon: stats.isCharging ? "bolt.fill" : "battery.100",
                    label: stats.isCharging ? "Charging" : "Battery",
                    value: stats.batteryLevel,
                    color: batteryColor
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var cpuColor: Color {
        switch stats.cpuUsage {
        case ..<0.5:  return .green
        case ..<0.8:  return .orange
        default:      return .red
        }
    }

    private var batteryColor: Color {
        if stats.isCharging     { return .green }
        if stats.batteryLevel < 0.2 { return .red }
        return .white
    }
}

private struct StatGauge: View {
    let icon: String
    let label: String
    let value: Double   // 0.0 – 1.0
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: value)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
            }
            .frame(width: 44, height: 44)

            VStack(spacing: 2) {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .textCase(.uppercase)
            }
        }
    }
}
