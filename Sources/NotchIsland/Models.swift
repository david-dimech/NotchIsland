import AppKit
import Foundation

struct NowPlayingInfo: Equatable {
    var title: String = ""
    var artist: String = ""
    var isPlaying: Bool = false
    var artwork: NSImage? = nil
    var duration: TimeInterval = 0
    var elapsed: TimeInterval = 0

    static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.duration == rhs.duration
    }
}

struct SystemStats {
    var cpuUsage: Double = 0      // 0.0–1.0
    var memoryUsage: Double = 0   // 0.0–1.0
    var batteryLevel: Double = 0  // 0.0–1.0
    var isCharging: Bool = false
    var hasBattery: Bool = false
}

struct TimerState {
    var isRunning: Bool = false
    var duration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60
    var isBreak: Bool = false

    var progress: Double {
        guard duration > 0 else { return 0 }
        return 1.0 - (remaining / duration)
    }

    var displayString: String {
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

enum IslandModule: String, Equatable, Hashable, CaseIterable {
    case nowPlaying  = "nowPlaying"
    case calendar    = "calendar"
    case systemStats = "systemStats"
    case timer       = "timer"
    case weather     = "weather"
    case bluetooth   = "bluetooth"

    var displayName: String {
        switch self {
        case .nowPlaying:  return "Media"
        case .calendar:    return "Calendar"
        case .systemStats: return "Battery"
        case .timer:       return "Timer"
        case .weather:     return "Weather"
        case .bluetooth:   return "Bluetooth"
        }
    }

    var icon: String {
        switch self {
        case .nowPlaying:  return "music.note"
        case .calendar:    return "calendar"
        case .systemStats: return "battery.100"
        case .timer:       return "timer"
        case .weather:     return "cloud.sun.fill"
        case .bluetooth:   return "bluetooth"
        }
    }
}

enum IslandState: Equatable {
    case compact
    case expanded(IslandModule)

    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }
}

// Notch-anchored island dimensions
// Compact matches the physical MacBook Pro notch (~250×38 pt).
// The rounded rect uses a fixed corner radius instead of a capsule shape
// so it reads as an extension of the notch, not a floating pill.
let kNotchWidth: CGFloat        = 250   // compact — aligns with physical notch
let kNotchHeight: CGFloat       = 38
let kIslandExpandedWidth: CGFloat  = 380
let kIslandExpandedHeight: CGFloat = 142
let kIslandCornerRadius: CGFloat   = 14  // fixed, not height/2

// Hover preview grows 15% wider and 20% taller than the physical notch.
// Computed dynamically in IslandViewModel from the real notch dimensions.
let kHoverWidthMultiplier:  CGFloat = 1.15
let kHoverHeightMultiplier: CGFloat = 1.20

// Calendar event
struct CalendarEventInfo: Identifiable {
    let id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
}

// Weather (Open-Meteo WMO weather codes)
struct WeatherInfo {
    var temperature: Double = 0
    var feelsLike: Double = 0
    var weatherCode: Int = 0
    var city: String = ""
    var isLoaded: Bool = false
    var isError: Bool = false

    var condition: String {
        switch weatherCode {
        case 0:        return "Clear"
        case 1:        return "Mostly Clear"
        case 2:        return "Partly Cloudy"
        case 3:        return "Overcast"
        case 45, 48:   return "Foggy"
        case 51...55:  return "Drizzle"
        case 61...65:  return "Rain"
        case 71...75:  return "Snow"
        case 80...82:  return "Showers"
        case 95:       return "Thunderstorm"
        default:       return "—"
        }
    }

    var sfSymbol: String {
        switch weatherCode {
        case 0:        return "sun.max.fill"
        case 1:        return "sun.haze.fill"
        case 2:        return "cloud.sun.fill"
        case 3:        return "cloud.fill"
        case 45, 48:   return "cloud.fog.fill"
        case 51...55:  return "cloud.drizzle.fill"
        case 61...65:  return "cloud.rain.fill"
        case 71...75:  return "cloud.snow.fill"
        case 80...82:  return "cloud.heavyrain.fill"
        case 95:       return "cloud.bolt.rain.fill"
        default:       return "cloud.fill"
        }
    }
}

// Bluetooth device battery
struct BTDeviceInfo: Identifiable {
    let id = UUID()
    var name: String
    var batteryPercent: Int   // 0–100
}

// Legacy aliases kept so manager / view code compiles during refactor
let kPillCompactWidth  = kNotchWidth
let kPillCompactHeight = kNotchHeight
let kPillExpandedWidth  = kIslandExpandedWidth
let kPillExpandedHeight = kIslandExpandedHeight
let kWindowWidth: CGFloat  = 600
let kWindowHeight: CGFloat = 220
