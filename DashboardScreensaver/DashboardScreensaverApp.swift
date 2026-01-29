//
//  DashboardScreensaverApp.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct DashboardScreensaverApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("Add Dashboard URL...") {
                    appState.showURLManager = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Import from File...") {
                    appState.showImport = true
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            // View Menu
            CommandGroup(after: .sidebar) {
                Divider()

                Button("Next Dashboard") {
                    DashboardManager.shared.nextDashboard()
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Previous Dashboard") {
                    DashboardManager.shared.previousDashboard()
                }
                .keyboardShortcut("[", modifiers: .command)

                Divider()

                Button("Toggle Full Screen") {
                    if let window = NSApp.keyWindow {
                        window.toggleFullScreen(nil)
                    }
                }
                .keyboardShortcut("f", modifiers: [.control])
            }

            // Control Menu (replacing toolbar)
            CommandGroup(replacing: .toolbar) {
                Button(DashboardManager.shared.isRotating ? "Pause Rotation" : "Start Rotation") {
                    DashboardManager.shared.toggleRotation()
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Toggle("Prevent Screen Sleep", isOn: Binding(
                    get: { DashboardManager.shared.settings.preventScreenSleep },
                    set: { newValue in
                        DashboardManager.shared.settings.preventScreenSleep = newValue
                        if newValue {
                            PowerManager.shared.preventSleep()
                        } else {
                            PowerManager.shared.allowSleep()
                        }
                    }
                ))

                Toggle("Dark Mode CSS", isOn: Binding(
                    get: { DashboardManager.shared.settings.enableDarkMode },
                    set: { DashboardManager.shared.settings.enableDarkMode = $0 }
                ))

                Divider()

                Button("Manage Apple TVs...") {
                    appState.showAppleTVs = true
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            // Settings shortcut
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Help Menu
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    appState.showShortcuts = true
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var showSettings = false
    @Published var showURLManager = false
    @Published var showAppleTVs = false
    @Published var showImport = false
    @Published var showShortcuts = false
}
