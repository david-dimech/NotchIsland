# NotchIsland

A macOS Dynamic Island–style overlay that lives in your MacBook Pro's notch. It turns the dead space around the camera cutout into a live, interactive heads-up display.

---

## Terminology

| Term | Description |
|---|---|
| **Notch** | Idle state — matches the physical MacBook notch cutout |
| **Glance** | Hover preview — quick info at a glance without clicking |
| **Drop** | Proactive mini notification that drops from the Notch |
| **Mail Drop** | Rich animated email notification card |
| **Island** | Fully expanded modular dashboard |
| **Widget** | Individual content panel within the Island |

---

## Features

### Notch (always-on compact)
The notch is invisible at rest. It pulses to life when something needs your attention.

### Glance (hover preview)
Hover over the notch for an instant summary:
- **Pending emails** — dismissable new-mail notifications (doesn't mark as read)
- **Music playing** — artwork, title, artist, and transport controls
- **Upcoming event** — title and time; Google Meet events show a **Join** button
- **Focus task** — your highest-priority Todoist task
- **Weather** — current conditions and city

### Drop (alert notifications)
The notch briefly expands to show a notification when:
- A calendar event starts in 15 minutes (Google Meet → **Join** button)
- A Todoist task becomes overdue or is newly added
- A system notification arrives (when Notification Intercept is enabled)

### Mail Drop (rich email notification)
When a new email arrives, the notch animates into a full-width card showing sender, subject, and snippet. The left edge glows with a slow hue-cycling accent colour. Tap to open the email; tap × to dismiss without marking as read.

**OTP / Verification codes** — when a new email contains a verification code, a special **Copy** button appears in the notification. You can also copy any code directly from the Gmail inbox list.

### Island (expanded dashboard)
Click the notch or tap while hovering to open the full dashboard. Swipe left/right or pinch to resize (0.75× – 1.60×; your preferred size is remembered).

| Widget | What it shows |
|---|---|
| **Media** | Album art with animated gradient background, scrub bar, transport controls |
| **Calendar** | Google + local events grouped by date; long-press for details, guests, RSVP status |
| **Gmail** | Primary inbox; OTP codes shown inline with one-tap copy; long-press for full body preview |
| **Todoist** | Today / Upcoming / Inbox; tap a task to prioritise / reschedule / delete |
| **Weather** | Current conditions + Morning / Afternoon / Evening segments (precipitation, wind) |
| **Stats** | CPU, RAM, Disk gauges + live network upload/download speed + battery |
| **Quick Notes** | Persistent scratch-pad — notes survive app restarts |
| **Camera Check** | Live camera preview so you can check your appearance before a video call |
| **Timer** | Pomodoro-style focus timer with presets and custom duration |
| **Bluetooth** | Battery levels for connected devices |
| **Music Tools** | Chord reference and scale helper |
| **Settings** | Toggle and reorder widgets, connect Google, set weather city, configure default widget |

---

## Setup

### Requirements
- macOS 13 Ventura or later
- MacBook Pro with a notch (2021 or later)

### Installation
1. Clone the repository and build:
   ```
   swift build -c release
   ```
2. Copy the built app to `/Applications`.
3. Launch **NotchIsland** — it appears in your menu bar with no main window.

### Google Calendar & Gmail
1. Create a project at [console.cloud.google.com](https://console.cloud.google.com).
2. Enable the **Google Calendar API** and **Gmail API**.
3. Create an **OAuth 2.0 Desktop** client credential.
4. Add yourself as a test user on the OAuth consent screen.
5. Copy `Sources/NotchIsland/Secrets.swift.template` → `Secrets.swift` and fill in your client ID and secret.
6. Rebuild and launch. Go to **Settings → Google → Connect with Google**.

### Todoist
1. Open [app.todoist.com → Settings → Integrations → Developer](https://app.todoist.com/app/settings/integrations/developer).
2. Copy your API token and paste it into **Settings → Todoist → API Token**.

### Weather city (optional)
By default weather uses your IP location. Override in **Settings → Weather → City**.

### Launch at login
Toggle **Settings → General → Launch at Login**.

---

## Usage

| Interaction | Action |
|---|---|
| Hover over notch | Open Glance preview |
| Click notch / Glance | Open Island |
| Swipe left / right | Switch between Widgets |
| Pinch on trackpad | Resize the Island (remembered on restart) |
| Click album art | Open the music source app |
| Long-press email row | Preview full message inline |
| Tap Mail Drop body | Open email in browser |
| Tap × on Mail Drop | Dismiss without marking as read |
| Tap × on Glance email | Dismiss from notification area |
| Long-press calendar event | Detail overlay with location, description, guests |
| Tap OTP pill in Gmail | Copy code to clipboard |
| Click outside the Island | Dismiss |

---

## Privacy
- No analytics, telemetry, or background network calls except to explicitly connected services.
- Google OAuth tokens stored in `UserDefaults` (no sandbox — local machine only).
- Todoist API token stored in `UserDefaults`.
- Camera Check — video never leaves your device; no capture output is added to the session.
- Weather via [Open-Meteo](https://open-meteo.com) (no API key) and [ip-api.com](https://ip-api.com) for IP location.
