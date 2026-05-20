import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var s: SystemStats { viewModel.systemStats }

    var body: some View {
        VStack(spacing: 10) {
            // Row 1: CPU · RAM · Disk
            HStack(spacing: 0) {
                StatGauge(icon: "cpu",        label: "CPU",  value: s.cpuUsage,    color: cpuColor)
                Spacer()
                vDivider
                Spacer()
                StatGauge(icon: "memorychip", label: "RAM",  value: s.memoryUsage, color: .blue)
                Spacer()
                vDivider
                Spacer()
                StatGauge(icon: "internaldrive", label: "Disk", value: s.diskUsage, color: diskColor)
            }

            Divider().background(Color.white.opacity(0.08))

            // Row 2: Network + Battery
            HStack(spacing: 16) {
                NetworkRow(upBps: s.netUpBps, downBps: s.netDownBps)

                if s.hasBattery {
                    Spacer()
                    BatteryRow(level: s.batteryLevel, charging: s.isCharging)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var vDivider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 36)
    }

    private var cpuColor: Color {
        switch s.cpuUsage {
        case ..<0.5: return .green
        case ..<0.8: return .orange
        default:     return .red
        }
    }

    private var diskColor: Color {
        switch s.diskUsage {
        case ..<0.7: return .cyan
        case ..<0.9: return .orange
        default:     return .red
        }
    }
}

// MARK: – Circular gauge (CPU / RAM / Disk)

private struct StatGauge: View {
    let icon:  String
    let label: String
    let value: Double
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
            }
        }
    }
}

// MARK: – Network row (up/down speeds)

private struct NetworkRow: View {
    let upBps:   Double
    let downBps: Double

    var body: some View {
        HStack(spacing: 14) {
            speedLabel(icon: "arrow.up.circle.fill", value: upBps,   color: .green)
            speedLabel(icon: "arrow.down.circle.fill", value: downBps, color: .blue)
        }
    }

    private func speedLabel(icon: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(formatSpeed(value))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        switch bps {
        case ..<1_024:              return "0 B/s"
        case ..<1_048_576:          return String(format: "%.0f KB/s", bps / 1_024)
        case ..<1_073_741_824:      return String(format: "%.1f MB/s", bps / 1_048_576)
        default:                    return String(format: "%.1f GB/s", bps / 1_073_741_824)
        }
    }
}

// MARK: – Battery row

private struct BatteryRow: View {
    let level:    Double
    let charging: Bool

    private var color: Color {
        if charging          { return .green }
        if level < 0.2       { return .red   }
        return .white
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: charging ? "bolt.fill" : batteryIcon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Int(level * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(charging ? "Charging" : "Battery")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
            }
        }
    }

    private var batteryIcon: String {
        switch level {
        case ..<0.125: return "battery.0"
        case ..<0.375: return "battery.25"
        case ..<0.625: return "battery.50"
        case ..<0.875: return "battery.75"
        default:       return "battery.100"
        }
    }
}
