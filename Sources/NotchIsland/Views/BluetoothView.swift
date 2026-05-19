import SwiftUI

struct BluetoothView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bluetooth")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Bluetooth")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            if viewModel.bluetoothDevices.isEmpty {
                Spacer()
                Text("No devices found")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.bluetoothDevices) { dev in
                        DeviceRow(device: dev)
                        if dev.id != viewModel.bluetoothDevices.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.07))
                                .padding(.leading, 18)
                        }
                    }
                }
                .padding(.top, 6)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DeviceRow: View {
    let device: BTDeviceInfo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: deviceIcon)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 18)

            Text(device.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Battery bar + percentage
            HStack(spacing: 5) {
                BatteryBar(level: Double(device.batteryPercent) / 100)
                    .frame(width: 28, height: 10)
                Text("\(device.batteryPercent)%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(batteryColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private var batteryColor: Color {
        switch device.batteryPercent {
        case ..<20:  return .red
        case ..<40:  return .orange
        default:     return .white.opacity(0.7)
        }
    }

    private var deviceIcon: String {
        let n = device.name.lowercased()
        if n.contains("airpods") || n.contains("headphone") || n.contains("earphone") { return "airpodspro" }
        if n.contains("keyboard")  { return "keyboard" }
        if n.contains("mouse")     { return "computermouse" }
        if n.contains("trackpad")  { return "trackpad" }
        if n.contains("speaker")   { return "hifispeaker" }
        return "dot.radiowaves.left.and.right"
    }
}

private struct BatteryBar: View {
    let level: Double   // 0–1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 2)
                    .fill(fillColor)
                    .frame(width: geo.size.width * CGFloat(min(level, 1)))
            }
        }
    }

    private var fillColor: Color {
        switch level {
        case ..<0.2:  return .red
        case ..<0.4:  return .orange
        default:      return .green
        }
    }
}
