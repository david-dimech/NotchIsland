import SwiftUI

struct WeatherView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var w: WeatherInfo { viewModel.weather }

    var body: some View {
        if w.isLoaded {
            VStack(spacing: 0) {
                currentRow
                if !w.segments.isEmpty {
                    Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 12)
                    segmentsRow
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
        } else if w.isError {
            VStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 22)).foregroundColor(.white.opacity(0.3))
                Text("Weather unavailable")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                Button("Retry") { viewModel.weatherManager.refresh() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView().progressViewStyle(.circular).tint(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: – Current conditions row

    private var currentRow: some View {
        HStack(spacing: 16) {
            // Large icon + temperature
            HStack(spacing: 8) {
                Image(systemName: w.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.multicolor)
                Text("\(Int(w.temperature))°")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(w.condition)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                HStack(spacing: 10) {
                    statPill("thermometer.medium", "\(Int(w.feelsLike))°")
                    statPill("wind", "\(Int(w.windSpeed)) km/h")
                }
                if !w.city.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill").font(.system(size: 8)).foregroundColor(.white.opacity(0.3))
                        Text(w.city).font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func statPill(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
        }
    }

    // MARK: – Segments row

    private var segmentsRow: some View {
        HStack(spacing: 0) {
            ForEach(w.segments.indices, id: \.self) { i in
                segmentCard(w.segments[i])
                if i < w.segments.count - 1 {
                    Divider().frame(height: 44).background(Color.white.opacity(0.07))
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func segmentCard(_ seg: WeatherSegment) -> some View {
        VStack(spacing: 3) {
            Text(seg.label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(seg.isPast ? .white.opacity(0.25) : .white.opacity(0.5))
            Image(systemName: seg.sfSymbol)
                .font(.system(size: 14))
                .foregroundColor(seg.isPast ? .white.opacity(0.2) : iconColor)
                .symbolRenderingMode(.multicolor)
            Text("\(Int(seg.temperature))°")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(seg.isPast ? .white.opacity(0.3) : .white)
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill").font(.system(size: 7)).foregroundColor(.blue.opacity(seg.isPast ? 0.3 : 0.7))
                    Text("\(seg.precipPct)%").font(.system(size: 8)).foregroundColor(seg.isPast ? .white.opacity(0.25) : .white.opacity(0.5))
                }
                HStack(spacing: 2) {
                    Image(systemName: "wind").font(.system(size: 7)).foregroundColor(.white.opacity(seg.isPast ? 0.2 : 0.4))
                    Text("\(Int(seg.windKmh))").font(.system(size: 8)).foregroundColor(seg.isPast ? .white.opacity(0.25) : .white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var iconColor: Color {
        switch w.weatherCode {
        case 0, 1:    return .yellow
        case 2, 3:    return .white.opacity(0.8)
        case 45, 48:  return .white.opacity(0.5)
        case 61...65: return .blue
        case 71...75: return .cyan
        case 95:      return .purple
        default:      return .white.opacity(0.7)
        }
    }
}
