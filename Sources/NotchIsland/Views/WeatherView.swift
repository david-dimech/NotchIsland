import SwiftUI

struct WeatherView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var w: WeatherInfo { viewModel.weather }

    var body: some View {
        if w.isLoaded {
            HStack(spacing: 24) {
                // Weather icon + temperature
                VStack(spacing: 4) {
                    Image(systemName: w.sfSymbol)
                        .font(.system(size: 32))
                        .foregroundColor(iconColor)
                        .symbolRenderingMode(.multicolor)

                    Text("\(Int(w.temperature))°")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Details column
                VStack(alignment: .leading, spacing: 5) {
                    Text(w.condition)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if !w.city.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.4))
                            Text(w.city)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Feels like \(Int(w.feelsLike))°")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var iconColor: Color {
        switch w.weatherCode {
        case 0, 1:      return .yellow
        case 2, 3:      return .white.opacity(0.8)
        case 45, 48:    return .white.opacity(0.5)
        case 61...65:   return .blue
        case 71...75:   return .cyan
        case 95:        return .purple
        default:        return .white.opacity(0.7)
        }
    }
}
