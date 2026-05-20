# NotchIsland

A macOS Dynamic Island–style overlay that lives in your MacBook Pro's notch. It turns the dead space around the camera cutout into a live, interactive heads-up display.

---

## Features

### Always-on compact state
The notch is invisible at rest. It pulses to life when something needs your attention.

### Hover preview (Peek)
Hover over the notch to see a 380 × 120 pt summary panel:
- **Music playing** — artwork, track title, artist, and play/pause/skip controls
- **Upcoming event** — title and time; Google Meet events show a **Join** button
- **Focus task** — your highest-priority Todoist task
- **Weather** — current conditions and city

### Alert notifications
The notch briefly expands to show a notification when:
- A new Todoist task appears on the next sync
- A new primary Gmail message arrives
- A calendar event starts in 15 minutes (Google Meet events include a **Join** button)
- A Todoist task becomes overdue
- A system notification arrives (when Notification Intercept is enabled)

### Expanded widgets
Click the notch (or tap while hovering) to open the full dashboard. Swipe left/right or use the trackpad pinch to resize.

| Widget | What it shows |
|---|---|
| **Media** | Album art, scrub bar, transport controls, click art/title to open source app |
| **Calendar** | Local and Google Calendar events grouped by date with start–end times and Meet join buttons |
| **Todoist** | Today / Upcoming / Inbox tabs; tap a task to set priority, reschedule, or delete |
| **Gmail** | Primary inbox; long-press a message for an inline body preview with mark-read / archive |
| **Weather** | Current conditions + Morning / Afternoon / Evening segments with precipitation and wind |
| **Timer** | Pomodoro-style focus timer with presets (1 / 5 / 15 / 25 / 45 min) and custom duration |
| **System** | Battery, CPU, RAM, network |
| **Bluetooth** | Battery levels for connected devices |
| **Music Tools** | Chord reference and scale helper |
| **Settings** | Toggle and reorder widgets, connect Google, set weather city |

---

## Setup

### Requirements
- macOS 13 Ventura or later
- MacBook Pro with a notch (2021 or later)

### Installation
1. Clone the repository and open it in Xcode or build with Swift Package Manager:
   ```
   swift build -c release
   ```
2. Copy the built app to `/Applications`.
3. Launch **NotchIsland** — it appears in your menu bar with no main window.

### Optional integrations

#### Google Calendar and Gmail
1. Create a project at [console.cloud.google.com](https://console.cloud.google.com).
2. Enable the **Google Calendar API** and **Gmail API**.
3. Create an **OAuth 2.0 Desktop** client credential.
4. Add yourself as a test user on the OAuth consent screen.
5. Copy `Sources/NotchIsland/Secrets.swift.template` to `Sources/NotchIsland/Secrets.swift` and fill in your client ID and secret.
6. Rebuild and launch. Go to **Settings → Google → Connect with Google**.

#### Todoist
1. Open [app.todoist.com/app/settings/integrations/developer](https://app.todoist.com/app/settings/integrations/developer).
2. Copy your API token.
3. Paste it into **Settings → Todoist → API Token**.

#### Weather city (optional)
By default weather uses your IP location. To override, type a city name in **Settings → Weather → City**.

#### Launch at login
Toggle **Settings → General → Launch at Login**.

---

## Usage tips

| Interaction | Action |
|---|---|
| Hover over notch | Open peek preview |
| Click notch / peek | Open expanded widget |
| Swipe left / right | Switch between widgets |
| Pinch on trackpad | Resize the expanded island (0.75× – 1.60×) |
| Click album art or track title | Open the music source app |
| Long-press an email | Preview the full message inline |
| Tap a Todoist task | Open inline priority / reschedule / delete bar |
| Click outside the island | Dismiss and return to compact |

---

## Privacy

- No analytics, no telemetry, no network calls except to the services you explicitly connect.
- Google tokens are stored in macOS Keychain (`ni.gcal.*` keys) and never leave the device.
- The Todoist API token is stored in `UserDefaults` (sandboxless app, local only).
- Weather uses [Open-Meteo](https://open-meteo.com) (no API key required) and [ip-api.com](https://ip-api.com) for IP-based location.
