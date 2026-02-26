# Dashboard Screensaver

![Build](https://github.com/kochj23/DashboardScreensaver/actions/workflows/build.yml/badge.svg)

A comprehensive macOS application for rotating through multiple web dashboards with intelligent alert detection, health monitoring, and remote Apple TV configuration. Perfect for NOC (Network Operations Center) displays, monitoring stations, kiosks, and smart home dashboards.

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Purpose

Dashboard Screensaver consolidates multiple dashboard rotation tools into a single, powerful application featuring:

- **Dashboard Rotation** - Automatically cycle through multiple web dashboards
- **AI Alert Detection** - Vision framework-based color analysis and OCR (Optical Character Recognition) for detecting alerts
- **Health Monitoring** - Track dashboard availability and skip unreachable URLs
- **Smooth Scrolling** - Animated page scrolling for long dashboards
- **Apple TV Support** - Configure remote Apple TVs running DashboardTV
- **Schedule-Based Groups** - Show different dashboards at different times
- **Glassmorphic UI** - Modern, beautiful interface with animated backgrounds

## Features

### Dashboard Management
- Add unlimited dashboard URLs
- Organize dashboards into color-coded groups
- Import URLs from CSV (Comma-Separated Values) files or remote configurations
- Enable/disable individual dashboards
- Automatic health status tracking

### Intelligent Rotation
- Configurable rotation interval (5-300 seconds)
- Page load delay before analysis
- Smooth scroll animation with configurable duration
- Post-scroll delay before rotation
- Extended display time for dashboards with alerts

### AI Alert Detection (Vision Framework)
- **Color Analysis** - Detects red, orange, and yellow alert indicators
  - Critical: ≥5% red pixels
  - High: ≥3% red pixels
  - Medium: ≥2% red or ≥5% orange
  - Low: ≥5% orange or ≥3% yellow
- **OCR Text Recognition** - Detects alert keywords:
  - critical, error, failed, failure, down
  - alert, warning, danger, urgent, emergency
  - outage, offline, unhealthy, degraded, incident
- **Content Change Detection** - Detects significant page changes
- **Notifications** - System notifications for critical alerts
- **Auto-Pause** - Optionally pause rotation on critical alerts

### Health Monitoring
- Background URL availability checks (HEAD requests)
- Success rate tracking
- Consecutive failure counting
- Automatic unhealthy URL skipping
- Configurable failure threshold and retry intervals
- Recovery notifications

### Schedule-Based Groups
- Define time-based rotation profiles
- Assign dashboard groups to profiles
- Support for overnight schedules
- Day-of-week filtering
- Priority-based profile selection
- Default profiles: Business Hours, After Hours, Weekend

### Apple TV Remote Configuration
- Bonjour/mDNS (Multicast Domain Name System) discovery of Apple TVs running DashboardTV
- IP range scanning fallback
- Remote configuration without typing URLs
- Assign dashboard groups to Apple TVs
- View configuration status

### Display Options
- Dark mode CSS (Cascading Style Sheets) injection for dashboards
- Screen sleep prevention (IOKit)
- Full-screen kiosk mode
- Alert overlay display
- Progress indicators

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Space | Play/Pause rotation |
| → | Next dashboard |
| ← | Previous dashboard |
| ↑/Home | First dashboard |
| ↓/End | Last dashboard |
| N | Next dashboard |
| P | Previous dashboard |
| R | Reload current |
| D | Toggle dark mode |
| F / Ctrl+F | Toggle full screen |
| ⌘, | Settings |
| ⌘] | Next dashboard |
| ⌘[ | Previous dashboard |
| ⌘P | Toggle rotation |
| ⌘T | Apple TV manager |
| Esc | Exit full screen |

## What This App Can Do

✅ Rotate through unlimited web dashboards
✅ Detect alerts using AI color analysis and OCR
✅ Monitor dashboard health and skip unreachable URLs
✅ Show different dashboards based on time/day schedules
✅ Configure Apple TVs remotely over the network
✅ Inject dark mode CSS into light-themed dashboards
✅ Prevent screen sleep during rotation
✅ Import dashboard URLs from CSV or remote configs
✅ Send system notifications for critical alerts
✅ Smooth scroll through long dashboard pages
✅ Full keyboard navigation for kiosk operation
✅ Group and organize dashboards by purpose

## What This App Cannot Do

❌ Run as a native macOS screensaver (.saver bundle) - This is a standalone app
❌ Access authenticated dashboards without manual login
❌ Automatically recover credentials or sessions
❌ Modify dashboard content (read-only display)
❌ Push notifications to mobile devices
❌ Integrate with cloud AI services (uses local Vision framework only)

## Requirements

- macOS 14.0 (Sonoma) or later
- Network access for dashboard loading and Apple TV discovery
- Recommended: Secondary display for dedicated dashboard monitoring

## Installation

### From DMG
1. Download the latest DMG (Disk Image) from Releases
2. Open the DMG file
3. Drag "Dashboard Screensaver" to Applications
4. Launch from Applications folder

### Building from Source
```bash
cd /Volumes/Data/xcode/DashboardScreensaver
xcodebuild -project DashboardScreensaver.xcodeproj \
           -scheme DashboardScreensaver \
           -configuration Release \
           build
```

## Usage

### Getting Started
1. **Launch** Dashboard Screensaver
2. **Add URLs** via the URL Manager (⌘N or click "Add Dashboard URL")
3. **Organize** dashboards into groups
4. **Configure** rotation timing in Settings
5. **Start rotation** with Space or ⌘P
6. **Go full screen** with F or Ctrl+F for kiosk mode

### Adding Dashboards
1. Click the list icon or press ⌘N
2. Enter the dashboard URL
3. Select a group (optional)
4. Click "Add"

Or import from file:
- **CSV/TXT**: One URL per line
- **Remote**: HTTP/HTTPS URL to a line-separated list

### Setting Up Schedules
1. Open Settings → Schedules tab
2. Enable "Schedule-Based Rotation"
3. Create schedule profiles with time ranges
4. Assign groups to profiles
5. Higher priority profiles take precedence

### Configuring Apple TVs
1. Install DashboardTV on your Apple TVs
2. Open the Apple TV Manager (⌘T)
3. Click "Scan Network" to discover devices
4. Select a device and choose a dashboard group
5. The Apple TV will receive the configuration automatically

### AI Alert Detection
Alerts are detected automatically when enabled:
- Red/orange/yellow color percentages are analyzed
- OCR scans for alert keywords
- Notifications appear for high/critical alerts
- Rotation pauses on critical if enabled
- Extra display time is added for alerting dashboards

## Architecture

### Technology Stack
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Web Rendering**: WebKit (WKWebView)
- **AI/Vision**: Vision framework (VNRecognizeTextRequest)
- **Network Discovery**: Network.framework (NWBrowser, Bonjour)
- **Power Management**: IOKit
- **Notifications**: UserNotifications
- **Platform**: macOS 14+

### Project Structure
```
DashboardScreensaver/
├── DashboardScreensaver/
│   ├── DashboardScreensaverApp.swift    # App entry point
│   ├── DashboardScreensaver.entitlements
│   ├── Managers/
│   │   ├── DashboardManager.swift       # Core data management
│   │   ├── HealthMonitor.swift          # URL health checking
│   │   └── PowerManager.swift           # Screen sleep prevention
│   ├── AI/
│   │   └── AIAlertDetector.swift        # Vision-based detection
│   ├── Network/
│   │   └── AppleTVDiscovery.swift       # Bonjour discovery
│   ├── Views/
│   │   ├── ContentView.swift            # Main interface
│   │   ├── DashboardWebView.swift       # WebKit wrapper
│   │   ├── SettingsView.swift           # Settings interface
│   │   ├── URLManagerView.swift         # URL management
│   │   └── AppleTVManagerView.swift     # Apple TV config
│   └── Assets.xcassets/
├── Shared/
│   ├── ModernDesign.swift               # Glassmorphic UI components
│   └── Models.swift                     # Data models
├── DashboardTV/                         # tvOS companion app
├── README.md
├── LICENSE
└── DashboardScreensaver.xcodeproj
```

### Key Components

**DashboardManager**
- Manages dashboard URLs, groups, and schedules
- Handles rotation state and timing
- Persists data via UserDefaults
- Calculates active dashboards based on schedules

**AIAlertDetector**
- Analyzes dashboard screenshots using Vision framework
- Color analysis for alert indicator detection
- OCR text extraction for keyword detection
- Content change comparison between screenshots
- Notification and pause triggers

**HealthMonitor**
- Background HEAD requests for availability checks
- Tracks success rates and failure counts
- Sends notifications for status changes
- Automatic retry after configured interval

**AppleTVDiscovery**
- Bonjour/mDNS service discovery
- IP range scanning fallback
- Remote configuration via HTTP API
- Device status persistence

## Security & Privacy

- **No Sandbox**: Required for full network access and IOKit
- **Local Only**: All data stored locally on your Mac
- **No Cloud**: No data sent to external services
- **No Telemetry**: No usage tracking or analytics
- **Hardened Runtime**: Code-signed for security
- **Keychain Storage**: API keys stored securely in macOS Keychain (not UserDefaults)

## Troubleshooting

### Dashboards Not Loading
- Verify URLs are accessible in a browser
- Check network connectivity
- Some dashboards require authentication (login manually)
- Try disabling dark mode CSS injection

### AI Detection Not Working
- Ensure AI Detection is enabled in Settings
- Check alert threshold isn't too high
- Dashboards may not have detectable alert colors
- OCR requires readable text in the dashboard

### Apple TVs Not Found
- Ensure DashboardTV is running on the Apple TV
- Check all devices are on the same network
- Try manual IP range scan
- Verify firewall allows Bonjour traffic

### Screen Sleep Not Prevented
- Enable "Prevent Screen Sleep" in Settings
- Check System Settings → Energy for conflicts
- App must be running (not minimized)

## Version History

### Version 1.0 (2026-01-28)
- Initial release
- Consolidated features from:
  - SiteRotator (basic rotation)
  - SiteRotator-Swift (IOKit, health monitoring)
  - Site Rotator 2.0 (smooth scrolling)
  - Site Screensaver 2.0 (AI alerts, schedules)
  - Dashboard Rotator (AI alerts, groups)
- TopGUI glassmorphic design system
- Apple TV remote configuration
- Full keyboard navigation
- Schedule-based group rotation

## License

MIT License - Copyright (c) 2026 Jordan Koch

See LICENSE file for details.

## Author

**Jordan Koch**
- GitHub: [@kochj23](https://github.com/kochj23)

---

*Dashboard Screensaver - Intelligent dashboard rotation for monitoring and display*

**Last Updated:** January 28, 2026

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
