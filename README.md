# Dashboard Screensaver

![Build](https://github.com/kochj23/DashboardScreensaver/actions/workflows/build.yml/badge.svg)
![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20tvOS%2017%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

A macOS application for rotating through multiple web dashboards with AI-powered alert detection, health monitoring, smooth scrolling, schedule-based groups, macOS widgets, Apple TV remote configuration, and a glassmorphic UI. Built for NOC displays, monitoring stations, kiosk environments, and smart home dashboards.

---

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [AI Alert Detection](#ai-alert-detection)
- [Health Monitoring](#health-monitoring)
- [Schedule-Based Rotation](#schedule-based-rotation)
- [Apple TV Companion (DashboardTV)](#apple-tv-companion-dashboardtv)
- [macOS Widget](#macos-widget)
- [Local API Server](#local-api-server)
- [AI Backend Manager](#ai-backend-manager)
- [Security and Privacy](#security-and-privacy)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Version History](#version-history)
- [License](#license)
- [Author](#author)

---

## Architecture

```
+-----------------------------------------------------------------------+
|                        Dashboard Screensaver                          |
|                        macOS 14+ / SwiftUI                            |
+-----------------------------------------------------------------------+
|                                                                       |
|  +------------------+    +------------------+    +-----------------+  |
|  | ContentView      |    | DashboardWebView |    | SettingsView    |  |
|  | (main interface) |--->| (WKWebView +     |    | URLManagerView  |  |
|  |                  |    |  smooth scroll)   |    | AppleTVManager  |  |
|  +--------+---------+    +--------+---------+    +--------+--------+  |
|           |                       |                       |           |
|  +--------v---------+    +--------v---------+    +--------v--------+  |
|  | DashboardManager |    | AIAlertDetector  |    | AIBackend       |  |
|  | - URL storage    |    | - Vision OCR     |    |   Manager       |  |
|  | - group mgmt     |    | - color analysis |    | - Ollama/MLX    |  |
|  | - rotation state |    | - change detect  |    | - TinyLLM/Chat  |  |
|  | - schedule eval  |    | - notifications  |    | - cloud APIs    |  |
|  +--------+---------+    +------------------+    +-----------------+  |
|           |                                                           |
|  +--------v---------+    +------------------+    +-----------------+  |
|  | HealthMonitor    |    | PowerManager     |    | AppleTVDiscovery|  |
|  | - HEAD requests  |    | - IOKit sleep    |    | - Bonjour/mDNS  |  |
|  | - success rates  |    |   prevention     |    | - IP range scan |  |
|  | - failure counts |    | - assertion mgmt |    | - remote config |  |
|  +------------------+    +------------------+    +--------+--------+  |
|                                                           |           |
|  +------------------+    +------------------+             |           |
|  | WidgetDataSync   |    | NovaAPIServer    |             |           |
|  | - App Group      |    | - port 37428     |             |           |
|  | - WidgetKit      |    | - /api/status    |             |           |
|  | - shared state   |    | - /api/ping      |             |           |
|  +--------+---------+    +------------------+             |           |
|           |                                               |           |
+-----------------------------------------------------------------------+
            |                                               |
  +---------v-----------+                     +-------------v---------+
  | Widget Extension    |                     | DashboardTV (tvOS)    |
  | - small / med / lrg |                     | - ConfigurationServer |
  | - health ring       |                     | - Bonjour advertise   |
  | - dashboard grid    |                     | - remote URL config   |
  | - rotation status   |                     | - WKWebView rotation  |
  +---------+-----------+                     +-----------------------+
            |
  +---------v-----------+
  | Shared/             |
  | - Models.swift      |
  | - ModernDesign.swift|
  | - WidgetData.swift  |
  +-----------------------+
```

### Technology Stack

| Layer              | Technology                                           |
|--------------------|------------------------------------------------------|
| Language           | Swift 5.9                                            |
| UI Framework       | SwiftUI                                              |
| Web Rendering      | WebKit (WKWebView)                                   |
| AI / Vision        | Vision framework (VNRecognizeTextRequest, pixel analysis) |
| Network Discovery  | Network.framework (NWBrowser, Bonjour/mDNS)         |
| Power Management   | IOKit (IOPMAssertionCreateWithName)                  |
| Notifications      | UserNotifications                                    |
| Widgets            | WidgetKit + App Groups                               |
| API Server         | Network.framework (NWListener, raw TCP/HTTP)         |
| Credential Storage | macOS Keychain (Security framework)                  |
| Platforms          | macOS 14.0+ (main app + widget), tvOS 17.0+ (companion) |

---

## Features

### Dashboard Rotation
- Add unlimited dashboard URLs, organized into color-coded groups.
- Configurable rotation interval (5--300 seconds) with page-load delay, smooth scroll animation, and post-scroll dwell time.
- Extended display time is automatically applied when alerts are detected.
- Import URLs from CSV/TXT files or remote HTTP configuration endpoints.

### AI Alert Detection (Vision Framework)
- Screenshot-based color analysis detects red, orange, and yellow alert regions.
- OCR text recognition scans for keywords: critical, error, failed, failure, down, alert, warning, danger, urgent, emergency, outage, offline, unhealthy, degraded, incident.
- Content change detection compares screenshots between rotations.
- System notifications for high and critical alerts; optional auto-pause on critical.

### Health Monitoring
- Background HEAD requests check URL availability at configurable intervals.
- Tracks success rates, consecutive failures, and average load times.
- Automatically skips unhealthy URLs after a configurable failure threshold.
- Sends notifications on failure and recovery.

### Schedule-Based Groups
- Define time-based rotation profiles (Business Hours, After Hours, Weekend, or custom).
- Assign dashboard groups to profiles with priority-based selection.
- Supports overnight schedules and day-of-week filtering.

### Apple TV Remote Configuration
- Discovers Apple TVs running DashboardTV via Bonjour/mDNS on the local network.
- Falls back to IP range scanning when Bonjour is unavailable.
- Pushes dashboard groups and settings to Apple TVs over HTTP.

### macOS Widget (WidgetKit)
- **Small**: Health ring showing healthy/total dashboards, rotation pulse, alert badge.
- **Medium**: Current dashboard name, health breakdown, next rotation countdown, pause/resume deep links.
- **Large**: Full dashboard grid with per-dashboard health indicators, rotation controls, alert count, schedule name.
- Refreshes every 60 seconds while rotating, every 5 minutes when paused.

### Display and UI
- Glassmorphic interface with animated floating blobs, glass card modifiers, and circular gauges (adapted from TopGUI design system).
- Dark mode CSS injection for light-themed dashboards.
- Screen sleep prevention via IOKit power assertions.
- Full-screen kiosk mode with hidden title bar.
- Alert overlay with severity badges and detected keywords.

### AI Backend Manager
- Auto-detects local LLM services: Ollama, MLX, TinyLLM, TinyChat, OpenWebUI.
- Auto-detects image generation backends: ComfyUI, Automatic1111, SwarmUI.
- Cloud AI support: OpenAI, Google Cloud, Azure, AWS, IBM Watson.
- All API keys stored in macOS Keychain -- never in UserDefaults or files.
- Auto-fallback: if the primary backend fails, generation falls through to the next available backend.
- Performance metrics and usage tracking per backend.

### Local API Server
- Binds to 127.0.0.1:37428 (loopback only -- no external exposure).
- `GET /api/status` returns running state, version, uptime.
- `GET /api/ping` returns a health check response.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)
- Network access for dashboard loading and Apple TV discovery
- Recommended: secondary display for dedicated monitoring

For the tvOS companion app:
- Apple TV running tvOS 17.0 or later
- Both devices on the same local network

---

## Installation

### From DMG

1. Download the latest DMG from [Releases](https://github.com/kochj23/DashboardScreensaver/releases).
2. Open the DMG file.
3. Drag "Dashboard Screensaver" to your Applications folder.
4. Launch from Applications.

### Building from Source

```bash
git clone git@github.com:kochj23/DashboardScreensaver.git
cd DashboardScreensaver

# Build the macOS app
xcodebuild -project DashboardScreensaver.xcodeproj \
           -scheme DashboardScreensaver \
           -configuration Release \
           build

# Build the tvOS companion (optional)
xcodebuild -project DashboardScreensaver.xcodeproj \
           -scheme DashboardTV \
           -configuration Release \
           -destination 'platform=tvOS Simulator,name=Apple TV' \
           build
```

---

## Usage

### Getting Started

1. Launch Dashboard Screensaver.
2. Add dashboard URLs via the URL Manager (Cmd+N or click "Add Dashboard URL").
3. Organize dashboards into color-coded groups (Monitoring, Business, Security, General, or custom).
4. Configure rotation timing in Settings (Cmd+,).
5. Press Space or Cmd+P to start rotation.
6. Press F or Ctrl+F for full-screen kiosk mode.

### Adding Dashboards

Click the list icon or press Cmd+N, then enter a URL and optionally assign it to a group. Alternatively, import from a file:

- **CSV/TXT**: one URL per line.
- **Remote config**: an HTTP/HTTPS URL pointing to a line-separated list.
- **Auto-load on first launch**: place a `config.txt` file next to the app bundle, in your home directory, or at `~/.dashboardscreensaver/config.txt`.

If no configuration is found, the app loads default status pages (GitHub, AWS, Google Cloud).

### Setting Up Schedules

1. Open Settings, then the Schedules tab.
2. Enable "Schedule-Based Rotation."
3. Create schedule profiles with time ranges and day-of-week filters.
4. Assign dashboard groups to each profile.
5. Higher-priority profiles take precedence when multiple are active.

Default profiles: Business Hours (Mon--Fri 09:00--17:00), After Hours (Mon--Fri 17:00--09:00), Weekend (Sat--Sun all day).

### Configuring Apple TVs

1. Install DashboardTV on your Apple TVs.
2. Open the Apple TV Manager (Cmd+T).
3. Click "Scan Network" to discover devices via Bonjour (with IP range fallback).
4. Select a device, choose a dashboard group, and push the configuration.

---

## Keyboard Shortcuts

| Shortcut      | Action                  |
|---------------|-------------------------|
| Space         | Play / Pause rotation   |
| Right Arrow   | Next dashboard          |
| Left Arrow    | Previous dashboard      |
| Up / Home     | First dashboard         |
| Down / End    | Last dashboard          |
| N             | Next dashboard          |
| P             | Previous dashboard      |
| R             | Reload current page     |
| D             | Toggle dark mode CSS    |
| F / Ctrl+F    | Toggle full screen      |
| Cmd+,         | Open Settings           |
| Cmd+N         | Add Dashboard URL       |
| Cmd+I         | Import from file        |
| Cmd+]         | Next dashboard          |
| Cmd+[         | Previous dashboard      |
| Cmd+P         | Toggle rotation         |
| Cmd+T         | Apple TV Manager        |
| Cmd+/         | Keyboard shortcuts help |
| Esc           | Exit full screen        |

---

## AI Alert Detection

The AIAlertDetector captures a screenshot of each dashboard after loading and analyzes it using two techniques:

### Color Analysis

Pixels are sampled (every 4th pixel for performance) and classified:

| Color  | Threshold          | Severity Mapping          |
|--------|--------------------|---------------------------|
| Red    | R > 0.6, G < 0.4, B < 0.4  | High / Critical    |
| Orange | R > 0.8, 0.3 < G < 0.7, B < 0.3 | Medium / High |
| Yellow | R > 0.7, G > 0.7, B < 0.4 | Low / Medium        |

Severity is determined by the percentage of alert-colored pixels relative to a configurable threshold (default 5%).

### OCR Keyword Detection

The Vision framework's `VNRecognizeTextRequest` (fast mode, no language correction) extracts text and matches against:

- **Critical**: critical, emergency, outage, down
- **High**: error, failed, failure, danger
- **Medium**: warning, degraded, incident
- **Low**: alert, urgent, offline, unhealthy

### Content Change Detection

Screenshots are compared between rotations by sampling every 10th pixel. A change exceeding 5% of sampled pixels triggers a content-changed flag.

### Alert Behavior

- Severity >= High: system notification sent (critical alerts use `defaultCritical` sound).
- Severity == Critical with `pauseOnCritical` enabled: rotation pauses automatically.
- Extra display time is added based on severity (Low: +5s, Medium: +10s, High: +20s, Critical: +30s).

---

## Health Monitoring

The HealthMonitor runs background availability checks using concurrent `HEAD` requests:

- HTTP 200--399: Healthy
- HTTP 400--499: Degraded
- HTTP 500--599 or network error: Failed

Dashboards are marked as failed after reaching the configurable failure threshold (default: 3 consecutive failures). Failed URLs are skipped during rotation when `skipUnhealthyURLs` is enabled and are retried after the retry interval (default: 600 seconds). Notifications are sent on both failure and recovery events.

---

## Schedule-Based Rotation

Schedule profiles define which dashboard groups are active during specific time windows. Each profile specifies:

- Start time and end time (supports overnight ranges, e.g. 22:00--06:00)
- Enabled days of the week
- A priority value (higher priority wins when multiple profiles overlap)
- A list of assigned dashboard group IDs

When scheduling is enabled, only dashboards belonging to the active profile's groups are included in rotation.

---

## Apple TV Companion (DashboardTV)

DashboardTV is a tvOS 17+ companion app that receives configuration from the macOS app over the local network:

- Advertises itself via Bonjour (`_dashboardtv._tcp`).
- Exposes `GET /api/info` for device identification and `POST /api/configure` for receiving dashboard URLs and settings.
- Supports independent rotation with its own timer and dark mode injection.

The macOS app discovers DashboardTV instances via Bonjour and falls back to scanning the local /24 subnet on port 8080.

---

## macOS Widget

The widget extension uses WidgetKit and communicates with the main app through an App Group (`group.com.jordankoch.DashboardScreensaver`). The `WidgetDataSync` manager writes current rotation state, health counts, and a recent-dashboards list to shared UserDefaults, then triggers a timeline reload via `WidgetCenter`.

Three widget sizes are supported:

- **Small**: A health ring gauge (healthy/total), rotation status pulse, and an alert badge.
- **Medium**: Current dashboard name, health breakdown (healthy/degraded/failed), next rotation countdown, and deep links for pause/resume.
- **Large**: A dashboard grid showing per-dashboard health dots, rotation controls, alert count, and the active schedule name.

---

## Local API Server

The `NovaAPIServer` starts automatically on launch and listens on `127.0.0.1:37428` (TCP, loopback only). It provides two endpoints:

```bash
# Application status (returns JSON with app name, version, port, uptimeSeconds)
curl -s http://127.0.0.1:37428/api/status | python3 -m json.tool

# Health check
curl -s http://127.0.0.1:37428/api/ping
```

The server uses `NWListener` from Network.framework with raw TCP request parsing. No external network exposure.

---

## AI Backend Manager

The standardized `AIBackendManager` auto-detects available AI services on the local machine and supports cloud providers:

| Backend        | Protocol / Port     | Check Method                |
|----------------|---------------------|-----------------------------|
| Ollama         | HTTP :11434         | GET /api/tags               |
| MLX            | Local binary        | File existence check        |
| TinyLLM        | HTTP :8000          | GET /v1/models              |
| TinyChat       | HTTP :8000          | GET /api/health             |
| OpenWebUI      | HTTP :8080 or :3000 | GET /                       |
| ComfyUI        | HTTP :8188          | GET /system_stats           |
| Automatic1111  | HTTP :7860          | GET /sdapi/v1/sd-models     |
| SwarmUI        | HTTP :7801          | GET /API/ListModels         |
| OpenAI         | Cloud               | API key presence (Keychain) |
| Google Cloud   | Cloud               | API key presence (Keychain) |
| Azure          | Cloud               | API key + endpoint (Keychain) |
| AWS            | Cloud               | Access key + secret (Keychain) |
| IBM Watson     | Cloud               | API key + URL (Keychain)    |

All cloud API keys are stored exclusively in macOS Keychain. Existing keys in UserDefaults are automatically migrated to Keychain on first launch and removed from UserDefaults.

The manager includes auto-fallback (tries the next available backend on failure), per-backend performance metrics, and a SwiftUI configuration view.

---

## Security and Privacy

- **No Sandbox**: The app runs without App Sandbox to allow full network access, IOKit power management, and local API server binding.
- **Hardened Runtime**: Code-signed with hardened runtime enabled.
- **Local Only**: All dashboard data and settings are stored locally via UserDefaults.
- **Keychain Storage**: All API keys and credentials are stored in macOS Keychain using the Security framework -- never in UserDefaults, plists, or files.
- **No Cloud Telemetry**: No usage tracking, analytics, or data sent to external services. AI alert detection uses the on-device Vision framework exclusively.
- **Loopback API**: The local HTTP API binds to 127.0.0.1 only -- it is not accessible from other machines on the network.

---

## Project Structure

```
DashboardScreensaver/
    DashboardScreensaver/
        DashboardScreensaverApp.swift           App entry point, menu commands, AppState
        NovaAPIServer.swift                     Local HTTP API on port 37428
        DashboardScreensaver.entitlements       App Group entitlement
        AI/
            AIAlertDetector.swift                Vision-based color + OCR alert detection
        Managers/
            DashboardManager.swift              URL/group/schedule storage, rotation state
            HealthMonitor.swift                 Background URL health checks
            PowerManager.swift                  IOKit screen sleep prevention
            WidgetDataSync.swift                App Group data sync for widget
            AIBackendManager.swift              AI backend detection and Keychain storage
            AIBackendManager+Enhanced.swift      Auto-fallback, metrics, notifications
            AIBackendManager+Generation.swift    Text generation via Ollama/TinyLLM/etc.
            AIBackendStatusMenu.swift           SwiftUI status menu component
        Network/
            AppleTVDiscovery.swift              Bonjour + IP scan for Apple TV devices
        Views/
            ContentView.swift                   Main dashboard display and controls
            DashboardWebView.swift              WKWebView wrapper with scroll animation
            SettingsView.swift                  Configuration interface
            URLManagerView.swift                Dashboard URL CRUD
            AppleTVManagerView.swift            Apple TV device management
        Assets.xcassets/
    Shared/
        Models.swift                            Data models (DashboardURL, DashboardGroup,
                                                ScheduleProfile, AlertSeverity, etc.)
        ModernDesign.swift                      Glassmorphic UI components (TopGUI system)
        WidgetData.swift                        Widget data models and health enums
    DashboardScreensaver Widget/
        DashboardScreensaverWidget.swift        WidgetKit timeline provider and views
        SharedDataManager.swift                 Reads widget data from App Group
        DashboardScreensaver_Widget.entitlements
    DashboardTV/
        DashboardTVApp.swift                    tvOS companion: config server, rotation
        Views/
            TVContentView.swift                 tvOS dashboard display
    DashboardScreensaver.xcodeproj
    project.yml                                 XcodeGen project specification
    LICENSE                                     MIT License
    CHANGELOG.md
    SECURITY.md
    CONTRIBUTING.md
    CODE_OF_CONDUCT.md
```

---

## Troubleshooting

### Dashboards Not Loading
- Verify URLs are accessible in a regular browser.
- Check network connectivity.
- Authenticated dashboards require manual login in the WebView first.
- Try disabling dark mode CSS injection (it can interfere with some sites).

### AI Detection Not Working
- Ensure AI Detection is enabled in Settings.
- Check that the alert threshold is not set too high (default is 5%).
- Dashboards with minimal color indicators may not trigger detection.
- OCR requires legible text in the rendered page.

### Apple TVs Not Found
- Confirm DashboardTV is running on the Apple TV.
- All devices must be on the same local network.
- Try the manual IP range scan option in the Apple TV Manager.
- Verify your firewall allows Bonjour/mDNS traffic (UDP port 5353).

### Screen Sleep Not Prevented
- Enable "Prevent Screen Sleep" in Settings.
- Check System Settings > Energy for conflicting power management.
- The app must be running in the foreground (not minimized).

### Widget Not Updating
- Confirm the app is running -- widget data is written on each rotation event.
- Check that the App Group entitlement (`group.com.jordankoch.DashboardScreensaver`) is correctly configured in both targets.
- Widget refresh is limited by the system; updates occur every 60 seconds during rotation and every 5 minutes when paused.

---

## Version History

### v1.1.0 (March 2026)
- macOS Widget support (small, medium, large) via WidgetKit.
- App Group data sync for live rotation state in widgets.

### v1.0.0 (January 2026)
- Initial release.
- Consolidated features from SiteRotator, SiteRotator-Swift, Site Rotator 2.0, Site Screensaver 2.0, and Dashboard Rotator.
- AI alert detection (Vision framework color analysis + OCR).
- Health monitoring with automatic unhealthy URL skipping.
- Schedule-based group rotation.
- Apple TV remote configuration via Bonjour.
- Smooth scrolling animation with ease-in-out curve.
- Glassmorphic UI (TopGUI design system).
- Full keyboard navigation for kiosk operation.
- AI backend manager with Keychain credential storage.
- Local API server on port 37428.
- Dark mode CSS injection.
- IOKit screen sleep prevention.

---

## License

MIT License -- Copyright (c) 2026 Jordan Koch

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See [LICENSE](LICENSE) for the full text.

---

## Author

Written by **Jordan Koch**.

- GitHub: [@kochj23](https://github.com/kochj23)

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
