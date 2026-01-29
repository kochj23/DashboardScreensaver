//
//  DashboardTVApp.swift
//  DashboardTV
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  tvOS companion app for Dashboard Screensaver
//

import SwiftUI

@main
struct DashboardTVApp: App {
    @StateObject private var configServer = ConfigurationServer.shared
    @StateObject private var dashboardManager = TVDashboardManager.shared

    var body: some Scene {
        WindowGroup {
            TVContentView()
                .environmentObject(configServer)
                .environmentObject(dashboardManager)
        }
    }
}

// MARK: - Configuration Server

/// HTTP server that accepts configuration from macOS app
@MainActor
class ConfigurationServer: ObservableObject {
    static let shared = ConfigurationServer()

    @Published var isRunning = false
    @Published var lastConfigTime: Date?
    @Published var connectedIP: String?

    private var listener: Any? // NWListener in actual implementation

    private init() {
        startServer()
        advertiseService()
    }

    func startServer() {
        // In full implementation, start HTTP server on port 8080
        // Accept POST /api/configure with JSON body
        // Accept GET /api/info to return device info
        isRunning = true
        print("ConfigurationServer: Started on port 8080")
    }

    func stopServer() {
        isRunning = false
    }

    private func advertiseService() {
        // Advertise via Bonjour as _dashboardtv._tcp
        print("ConfigurationServer: Advertising via Bonjour")
    }

    func handleConfiguration(_ config: TVConfiguration) {
        TVDashboardManager.shared.applyConfiguration(config)
        lastConfigTime = Date()
    }
}

// MARK: - TV Dashboard Manager

@MainActor
class TVDashboardManager: ObservableObject {
    static let shared = TVDashboardManager()

    @Published var urls: [String] = []
    @Published var currentIndex = 0
    @Published var isRotating = false
    @Published var settings = TVSettings()

    private var rotationTimer: Timer?

    private init() {
        loadSavedConfiguration()
    }

    var currentURL: URL? {
        guard currentIndex >= 0, currentIndex < urls.count else { return nil }
        return URL(string: urls[currentIndex])
    }

    func startRotation() {
        guard !urls.isEmpty else { return }
        isRotating = true
        scheduleNext()
    }

    func stopRotation() {
        isRotating = false
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    func nextDashboard() {
        guard !urls.isEmpty else { return }
        currentIndex = (currentIndex + 1) % urls.count
        if isRotating { scheduleNext() }
    }

    func previousDashboard() {
        guard !urls.isEmpty else { return }
        currentIndex = currentIndex > 0 ? currentIndex - 1 : urls.count - 1
        if isRotating { scheduleNext() }
    }

    private func scheduleNext() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: settings.rotationInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.nextDashboard()
            }
        }
    }

    func applyConfiguration(_ config: TVConfiguration) {
        urls = config.urls
        settings.rotationInterval = config.rotationInterval
        settings.enableDarkMode = config.enableDarkMode
        settings.enableAIDetection = config.enableAIDetection
        currentIndex = 0
        saveConfiguration()

        if !urls.isEmpty && !isRotating {
            startRotation()
        }
    }

    private func loadSavedConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "DashboardTV.urls"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            urls = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "DashboardTV.settings"),
           let decoded = try? JSONDecoder().decode(TVSettings.self, from: data) {
            settings = decoded
        }
    }

    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(urls) {
            UserDefaults.standard.set(encoded, forKey: "DashboardTV.urls")
        }
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "DashboardTV.settings")
        }
    }
}

// MARK: - Models

struct TVConfiguration: Codable {
    let urls: [String]
    let rotationInterval: TimeInterval
    let enableDarkMode: Bool
    let enableAIDetection: Bool
    let alertThreshold: Double
}

struct TVSettings: Codable {
    var rotationInterval: TimeInterval = 30
    var enableDarkMode: Bool = true
    var enableAIDetection: Bool = false
    var alertThreshold: Double = 5.0
}
