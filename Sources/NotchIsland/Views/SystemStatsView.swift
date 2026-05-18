import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var stats: SystemStats { viewModel.systemStats }

    var body: some View {
        HStack(spacing: 0) {
            StatGauge(icon: "cpu",         label: "CPU",     value: stats.cpuUsage,    color: cpuColor)
            Spacer()
            separator
            Spacer()
            StatGauge(icon: "memorychip",  label: "RAM",     value: stats.memoryUsage, color: .blue)

            if stats.hasBattery {
                Spacer()
                separator
                Spacer()
                StatGauge(
                    icon:  stats.isCharging ? "bolt.fill" : "battery.100",
                    label: stats.isCharging ? "Charging"  : "Battery",
                    value: stats.batteryLevel,
                    color: batteryColor
                )
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill + centre in page slot
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 36)
    }

    private var cpuColor: Color {
        switch stats.cpuUsage {
        case ..<0.5: return .green
        case ..<0.8: return .orange
        default:     return .red
        }
    }

    private var batteryColor: Color {
        if stats.isCharging        { return .green }
        if stats.batteryLevel < 0.2 { return .red  }
        return .white
    }
}

private struct StatGauge: View {
    let icon: String
    let label: String
    let value: Double   // 0–1
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: value)
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
            }
            .frame(width: 40, height: 40)

            VStack(spacing: 1) {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
        }
    }
}
