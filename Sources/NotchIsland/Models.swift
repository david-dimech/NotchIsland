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

enum IslandModule: Equatable {
    case nowPlaying
    case systemStats
    case timer
}

enum IslandState: Equatable {
    case compact
    case expanded(IslandModule)

    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }
}

// Compact pill dimensions matching a 14/16" MacBook Pro notch area
let kPillCompactWidth: CGFloat  = 126
let kPillCompactHeight: CGFloat = 34
let kPillExpandedWidth: CGFloat = 400
let kPillExpandedHeight: CGFloat = 130
let kWindowWidth: CGFloat  = 600
let kWindowHeight: CGFloat = 200
