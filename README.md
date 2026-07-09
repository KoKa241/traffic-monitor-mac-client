# Traffic Monitor macOS Client

<p align="center">
  <img src="docs/logo.png" alt="Traffic Monitor macOS Logo" width="220">
</p>

<p align="center">
  <a href="https://developer.apple.com/swift/"><img src="https://img.shields.io/badge/Swift-5.0%2B-orange?logo=swift&logoColor=white" alt="Swift"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13.0%2B-black?logo=apple&logoColor=white" alt="macOS"></a>
  <a href="https://github.com/KoKa241/upnp-traffic-monitor"><img src="https://img.shields.io/badge/Backend-Traffic_Monitor-blue" alt="Backend"></a>
  <a href="https://deepwiki.com/KoKa241/traffic-monitor-mac-client"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License"></a>
</p>

A native macOS menubar utility for the [Traffic Monitor](https://github.com/KoKa241/upnp-traffic-monitor) system. It sits quietly in your menu bar, fetching real-time bandwidth consumption data from your Traffic Monitor backend and providing quick access to your daily and monthly statistics.

## Screenshots

| Popover Dashboard | Onboarding |
| :---: | :---: |
| ![Popover](docs/screenshot_popover.png) | ![Onboarding](docs/screenshot_onboarding.png) |

## Features

- **Menu Bar Integration**: See your current day's traffic usage and limit percentage directly in the macOS menu bar.
- **Quick Dashboard**: Click the menu bar icon to reveal a popover with detailed daily and monthly statistics.
- **Interactive Onboarding**: A clean setup flow on first launch to configure your backend server URL and API key.
- **Background Refresh**: Automatically polls the backend for fresh data without interrupting your workflow.
- **Native Experience**: Built entirely with Swift & SwiftUI, automatically hiding from the Dock to stay out of your way.

## Requirements

- **macOS 13.0** (Ventura) or later.
- A running instance of the [Traffic Monitor Backend](https://github.com/KoKa241/upnp-traffic-monitor) (accessible via local network or internet).

---

## Installation

### Option 1: Download Release
1. Go to the [Releases](https://github.com/KoKa241/traffic-monitor-mac-client/releases) page.
2. Download the latest `TrafficMonitor.app.zip`.
3. Unzip and drag `TrafficMonitor.app` to your `Applications` folder.
4. **Important macOS Gatekeeper Step:** Since the app is not signed with a paid Apple Developer certificate, macOS may block it.
   - Try to **Right-click** `TrafficMonitor.app` and select **Open**.
   - If macOS says the app is "damaged", open your Terminal and run this command to remove the quarantine flag:
     ```bash
     xattr -cr /Applications/TrafficMonitor.app
     ```
5. Launch the app and complete the Onboarding wizard.

### Option 2: Build from Source
1. **Clone the repository:**
   ```bash
   git clone https://github.com/KoKa241/traffic-monitor-mac-client.git
   cd traffic-monitor-mac-client
   ```
2. **Open the project in Xcode:**
   Open `TrafficMonitor.xcodeproj`.
3. **Build and Run:**
   Select your Mac as the destination and press `Cmd + R` to build and run the app.

## Architecture

- `TrafficMonitorApp.swift` - Application entry point, managing the menu bar item, dock presence, and window lifecycles (Settings, Onboarding).
- `TrafficManager.swift` - Core network logic, responsible for polling the Traffic Monitor backend API.
- `ContentView.swift` - The main popover interface displaying your traffic statistics.
- `OnboardingView.swift` - The initial setup wizard.

## License
MIT License
