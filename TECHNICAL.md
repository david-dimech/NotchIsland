# NotchIsland — Technical Reference

## Architecture overview

NotchIsland is a macOS menu-bar app built with **Swift + SwiftUI + AppKit**. It has no main window; instead it owns a single transparent, always-on-top `NSPanel` that covers the full width of the screen and a configurable height at the top edge. The panel hosts a SwiftUI root view via `NSHostingView`.

```
AppDelegate
  └─ NotchWindow (NSPanel, level 26, transparent, non-activating)
       └─ PillHitTestView (NSView, custom hitTest / cursor rect)
            └─ NSHostingView<IslandView>
                 └─ IslandView
                      ├─ CompactIslandView
                      ├─ AlertPreviewView
                      ├─ PeekView
                      └─ ExpandedIslandView
                           └─ [module views]
```

---

## State machine

`IslandState` (in `Models.swift`) is the single source of truth for what's visible:

| State | When | Dimensions |
|---|---|---|
| `.compact` | Idle | `notchWidth × notchHeight` (real notch size) |
| `.alert(AlertInfo)` | Notification queued | `notchWidth × 1.15 × notchHeight × 1.10` |
| `.peek` | Hovering | `380 × 120 pt` |
| `.expanded(IslandModule)` | User opened a widget | `380 × module.preferredExpandedHeight pt` |

Transitions are driven by `IslandViewModel` using `withAnimation` + spring parameters defined as static constants (`expandSpring`, `collapseSpring`, `alertSpring`, `peekSpring`).

Per-module expanded heights (`IslandModule.preferredExpandedHeight`):
- `.todoist`, `.gmail`, `.calendar` → 280 pt (list-heavy, need scroll room)
- All others → 160 pt

The transparent window is always `kWindowHeight = 500 pt` tall, which comfortably covers the 1.60× pinch-resize maximum (280 × 1.6 = 448 pt).

---

## Key files

| File | Purpose |
|---|---|
| `Models.swift` | All value types: `IslandState`, `IslandModule`, `WeatherInfo`, `WeatherSegment`, `AlertInfo`, `NowPlayingInfo`, `TimerState`, dimension constants |
| `IslandViewModel.swift` | `@MainActor ObservableObject`; owns all managers; drives state transitions, hover, alerts, reminders, MIDI glow, pinch-resize |
| `IslandView.swift` | Root SwiftUI view; switches between the four state branches with `ZStack` + conditional rendering |
| `NotchWindow.swift` | `NSPanel` setup; `PillHitTestView` hit-testing, hover tracking, cursor rects |
| `AlertManager.swift` | Serial alert queue cycling at 4 s intervals; `AlertInfo` carries optional `actionURL` for Join buttons |
| `SettingsManager.swift` | `ObservableObject` backed by `UserDefaults`; enabled module list, Todoist token, weather city, notification prefs |

---

## Managers

Each manager is a `class : ObservableObject` owned by `IslandViewModel` as a `let` constant.

### NowPlayingManager
Uses the **MediaRemote private framework** via `dlopen` / `dlsym`:
- `MRMediaRemoteRegisterForNowPlayingNotifications` — must be called first or macOS 12+ silently drops notifications
- `MRMediaRemoteGetNowPlayingInfo` — title, artist, duration, elapsed, artwork
- `MRMediaRemoteGetNowPlayingApplicationIsPlaying` — playing flag
- `MRMediaRemoteGetNowPlayingApplicationDisplayID` — source app bundle ID
- `MRMediaRemoteSendCommand` — transport commands (play=2, next=4, prev=5, seek=42)

Artwork: `kMRMediaRemoteNowPlayingInfoArtworkData` may return a `Data`, `NSImage`, or `MRMediaRemoteArtwork` object. The last case requires calling `imageWithSize:` which takes a `CGSize` struct. `perform(_:with:)` only handles object pointers, and Swift marks `objc_msgSend` as `@_unavailable`. Solution: `dlsym(dlopen(nil, RTLD_LAZY), "objc_msgSend")` → `unsafeBitCast` to `@convention(c) (AnyObject, Selector, CGSize) -> NSImage?`.

Progress interpolation: a 0.5 s timer advances `elapsed` between fetches to avoid jitter from the 3 s poll interval.

### CalendarManager
Uses **EventKit** (`EKEventStore`) to fetch local calendar events for the selected day. Requires Calendar access permission. `nextUpcoming` returns the soonest event starting within 2 hours — used by the peek panel.

### GoogleCalendarManager
OAuth 2.0 loopback flow using a POSIX TCP server (`OAuthCallbackServer`) on a random port. Combined scope: `calendar.events` + `gmail.modify` (single sign-in covers both). Tokens stored in `UserDefaults` with keys `ni.gcal.*`. Auto-refreshes every 10 minutes. `validToken()` is `internal` so `GmailManager` can call it.

### GmailManager
Shares auth tokens via `weak var authProvider: GoogleCalendarManager?`. Fetches primary-only messages (`category:primary&labelIds=INBOX`). Detects new messages by comparing `Set<String>` of IDs against `knownMessageIDs` (first fetch is skipped to avoid flooding on launch). `fetchBody(id:)` fetches with `format=full` and recursively extracts `text/plain` from multipart payloads, falling back to stripping tags from `text/html`.

### TodoistManager
REST API v1 (`api.todoist.com/api/v1`). Polls every 5 minutes. Detects new tasks by comparing `knownTaskIDs` across refreshes (same skip-first-fetch pattern as Gmail). `focusTask` is computed: highest-priority overdue task first, then highest-priority due-today task.

### WeatherManager
Fetches from **Open-Meteo** (`api.open-meteo.com/v1/forecast`) with `current` + `hourly` parameters. Hourly data includes `temperature_2m`, `precipitation_probability`, `windspeed_10m`, `weathercode` for 24 hours. Three `WeatherSegment` values are derived using representative hours 9 (Morning), 15 (Afternoon), 21 (Evening). IP-based location via `ip-api.com`; manual override stored in `SettingsManager.weatherCity`.

### AlertManager
A `@MainActor` serial queue. `post(icon:text:source:actionURL:)` appends to the queue and starts cycling if idle. Each alert auto-advances after 4 s. `AlertInfo.text` is capped at 25 characters. `actionURL` is rendered as a "Join" button in `AlertPreviewView`.

### MIDIManager
Uses **CoreMIDI** to listen for any incoming MIDI events. On event: calls `onEvent` closure → `IslandViewModel.triggerMIDIFlash()` which snaps `midiGlowOpacity` to 1.0 then fades to 0 in 0.15 s.

### NotificationInterceptor
Registers a `UNUserNotificationCenter` delegate and intercepts delivered banners. Filtered by DND state and an allowlist stored in `SettingsManager`. Forwards to `AlertManager`.

---

## Hover and hit-testing

`PillHitTestView` overrides `hitTest(_:)` to only return `self` when the cursor is inside the island rect (computed by `IslandViewModel.pillRectInWindow`). This prevents the transparent window from eating mouse events outside the island.

Hover tracking uses `addTrackingArea` with `.mouseEnteredAndExited` + `.activeAlways`. `IslandViewModel.isHovering` is set directly from `mouseEntered`/`mouseExited`, triggering the `.compact → .peek` transition via `onHoverChanged`.

Click-outside-to-dismiss uses `NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown)` and checks whether the cursor is inside the island rect on the notch screen.

---

## Animations

All transitions use `withAnimation` with named spring constants:

| Constant | Usage | Parameters |
|---|---|---|
| `expandSpring` | Open expanded island | `mass:1 stiffness:160 damping:18` |
| `collapseSpring` | Close to compact | `mass:1 stiffness:260 damping:28` |
| `hoverSpring` | Compact size change on hover | `mass:1 stiffness:320 damping:24` |
| `alertSpring` | Alert pop-in | `response:0.36 dampingFraction:0.76` |
| `peekSpring` | Compact → peek | `response:0.32 dampingFraction:0.76` |

Pinch-to-resize uses `.interactiveSpring(response: 0.18, dampingFraction: 0.9)` applied inside an `.magnify` `NSEvent` local monitor.

---

## Layout constants (Models.swift)

| Constant | Value | Purpose |
|---|---|---|
| `kNotchWidth` | 250 pt | Compact width (matches physical notch) |
| `kNotchHeight` | 38 pt | Compact height |
| `kIslandExpandedWidth` | 380 pt | Expanded width (all modules) |
| `kIslandExpandedHeight` | 160 pt | Default expanded height |
| `kPeekExpandedWidth` | 380 pt | Peek panel width |
| `kPeekExpandedHeight` | 120 pt | Peek panel height |
| `kWindowWidth` | 600 pt | Transparent window width |
| `kWindowHeight` | 500 pt | Transparent window height |
| `kHoverWidthMultiplier` | 1.15 | Compact hover width factor |
| `kHoverHeightMultiplier` | 1.20 | Compact hover height factor |

---

## Calendar reminder system

`IslandViewModel` runs a `Timer.publish(every: 60)` Combine pipeline. On each tick, `checkCalendarReminders()` iterates both `calendarEvents` (local) and `googleCalendarManager.events` (Google), finding events that start between now and now + 15 min. A `remindedEventKeys: Set<String>` prevents duplicate alerts. Google Meet URLs from `GCalEvent.hangoutLink` are forwarded as `actionURL` in the `AlertInfo`.

---

## Secrets

`Secrets.swift` is gitignored. It must be created locally from `Secrets.swift.template`:

```swift
enum Secrets {
    static let googleClientID     = "YOUR_CLIENT_ID.apps.googleusercontent.com"
    static let googleClientSecret = "YOUR_CLIENT_SECRET"
}
```

These values are read only at OAuth flow start — they are never stored, logged, or sent anywhere except Google's OAuth endpoint.

---

## Build

```bash
swift build                     # debug
swift build -c release          # optimised
```

The package target is `NotchIsland` (macOS 13+, no sandbox). Warnings about `Info.plist` and `Secrets.swift.template` being unhandled resources are benign — they are excluded via `.gitignore` / resource rules and do not affect the build.
