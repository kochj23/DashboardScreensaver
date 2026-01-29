//
//  ContentView.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dashboardManager = DashboardManager.shared
    @StateObject private var healthMonitor = HealthMonitor.shared
    @StateObject private var aiDetector = AIAlertDetector.shared
    @StateObject private var appleTVDiscovery = AppleTVDiscovery.shared

    @State private var isLoading = false
    @State private var scrollProgress: CGFloat = 0
    @State private var showSettings = false
    @State private var showURLManager = false
    @State private var showAppleTVs = false
    @State private var showAlertOverlay = false

    var body: some View {
        ZStack {
            // Background
            GlassmorphicBackground()

            if dashboardManager.activeDashboards.isEmpty {
                emptyStateView
            } else {
                mainDashboardView
            }

            // Alert overlay
            if showAlertOverlay, let result = aiDetector.lastAnalysisResult, result.hasAlerts {
                alertOverlayView(result)
            }

            // Controls overlay
            VStack {
                Spacer()
                controlsBar
            }
        }
        .onAppear {
            setupApp()
        }
        .focusable()
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showURLManager) {
            URLManagerView()
        }
        .sheet(isPresented: $showAppleTVs) {
            AppleTVManagerView()
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "display")
                .font(.system(size: 64))
                .foregroundColor(ModernColors.accentCyan)

            ModernHeader(text: "No Dashboards", size: .large)

            Text("Add dashboard URLs to get started")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            Button("Add Dashboard URL") {
                showURLManager = true
            }
            .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
        }
        .glassCard()
    }

    private var mainDashboardView: some View {
        GeometryReader { geo in
            ZStack {
                // WebView
                if let dashboard = dashboardManager.currentDashboard,
                   let url = dashboard.displayURL {
                    ScrollingDashboardWebView(
                        url: url,
                        isLoading: $isLoading,
                        scrollProgress: $scrollProgress,
                        scrollDuration: dashboardManager.settings.scrollDuration,
                        onLoadComplete: { image in
                            handlePageLoaded(image, for: dashboard)
                        },
                        onLoadError: { error in
                            handlePageError(error, for: dashboard)
                        }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                // Loading indicator
                if isLoading {
                    loadingOverlay
                }

                // Dashboard info overlay
                VStack {
                    dashboardInfoBar
                    Spacer()
                }
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ModernColors.accentCyan)

                Text("Loading...")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }
            .glassCard(cornerRadius: 16, padding: 24)
        }
    }

    private var dashboardInfoBar: some View {
        HStack {
            if let dashboard = dashboardManager.currentDashboard {
                HStack(spacing: 12) {
                    // Health status
                    StatusIndicator(
                        isActive: dashboard.healthStatus == .healthy,
                        activeColor: ModernColors.healthColor(dashboard.healthStatus)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dashboard.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(ModernColors.textPrimary)

                        Text("\(dashboardManager.currentIndex + 1) of \(dashboardManager.activeDashboards.count)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Rotation status
            HStack(spacing: 8) {
                if dashboardManager.isRotating && !dashboardManager.isPaused {
                    // Scroll progress
                    MiniGauge(value: Double(scrollProgress) * 100, color: ModernColors.accentCyan)
                        .frame(width: 60)

                    Image(systemName: "play.circle.fill")
                        .foregroundColor(ModernColors.statusLow)
                } else if dashboardManager.isPaused {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(ModernColors.statusMedium)
                    Text("Paused")
                        .font(.system(size: 12, design: .rounded))
                } else {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(ModernColors.textSecondary)
                    Text("Stopped")
                        .font(.system(size: 12, design: .rounded))
                }
            }
            .foregroundColor(ModernColors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }

    private var controlsBar: some View {
        HStack(spacing: 16) {
            // Navigation buttons
            Button(action: { dashboardManager.previousDashboard() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(ModernButtonStyle(style: .glass))
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button(action: { dashboardManager.toggleRotation() }) {
                Image(systemName: dashboardManager.isRotating && !dashboardManager.isPaused ? "pause.fill" : "play.fill")
            }
            .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
            .keyboardShortcut(.space, modifiers: [])

            Button(action: { dashboardManager.nextDashboard() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(ModernButtonStyle(style: .glass))
            .keyboardShortcut(.rightArrow, modifiers: [])

            Divider()
                .frame(height: 30)

            // Settings buttons
            Button(action: { showURLManager = true }) {
                Image(systemName: "list.bullet")
            }
            .buttonStyle(ModernButtonStyle(style: .glass))

            Button(action: { showAppleTVs = true }) {
                Image(systemName: "appletv")
            }
            .buttonStyle(ModernButtonStyle(style: .glass))

            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(ModernButtonStyle(style: .glass))
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func alertOverlayView(_ result: DashboardAnalysisResult) -> some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 12) {
                    AlertBadge(severity: result.severity, count: result.detectedKeywords.count)

                    if !result.detectedKeywords.isEmpty {
                        Text(result.detectedKeywords.joined(separator: ", "))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(ModernColors.textSecondary)
                            .lineLimit(1)
                    }

                    Button(action: { showAlertOverlay = false }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ModernColors.alertColor(result.severity).opacity(0.2))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ModernColors.alertColor(result.severity).opacity(0.5), lineWidth: 1)
                )
            }
            .padding()

            Spacer()
        }
    }

    // MARK: - Setup

    private func setupApp() {
        // Start health monitoring if enabled
        if dashboardManager.settings.enableHealthMonitoring {
            healthMonitor.startMonitoring()
        }

        // Prevent screen sleep if enabled
        if dashboardManager.settings.preventScreenSleep {
            PowerManager.shared.preventSleep()
        }

        // Start Apple TV discovery if enabled
        if dashboardManager.settings.enableAppleTVDiscovery {
            appleTVDiscovery.startScanning()
        }

        // Start rotation
        dashboardManager.startRotation()
    }

    // MARK: - Event Handlers

    private func handlePageLoaded(_ image: CGImage?, for dashboard: DashboardURL) {
        // Record success
        dashboardManager.updateHealthStatus(for: dashboard.id, status: .healthy)

        // Run AI analysis if enabled
        if dashboardManager.settings.enableAIDetection, let image = image {
            Task {
                let result = await aiDetector.analyzeImage(image, for: dashboard.id)

                if result.hasAlerts && dashboardManager.settings.showAlertOverlay {
                    showAlertOverlay = true
                }

                // Extend display time based on alert severity
                if result.severity != .none {
                    dashboardManager.extendDisplayTime(by: result.severity.extraDisplayTime)
                }
            }
        }
    }

    private func handlePageError(_ error: Error, for dashboard: DashboardURL) {
        dashboardManager.updateHealthStatus(for: dashboard.id, status: .failed)

        // Skip to next if auto-skip enabled
        if dashboardManager.settings.skipUnhealthyURLs {
            dashboardManager.nextDashboard()
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .space:
            dashboardManager.toggleRotation()
            return .handled
        case .leftArrow:
            dashboardManager.previousDashboard()
            return .handled
        case .rightArrow:
            dashboardManager.nextDashboard()
            return .handled
        case .upArrow, .home:
            dashboardManager.goToFirst()
            return .handled
        case .downArrow, .end:
            dashboardManager.goToLast()
            return .handled
        case .escape:
            if let window = NSApp.keyWindow {
                window.toggleFullScreen(nil)
            }
            return .handled
        default:
            // Check for letter keys
            if let character = keyPress.characters.first {
                switch character {
                case "n", "N":
                    dashboardManager.nextDashboard()
                    return .handled
                case "p", "P":
                    dashboardManager.previousDashboard()
                    return .handled
                case "r", "R":
                    // Reload current page
                    dashboardManager.currentIndex = dashboardManager.currentIndex
                    return .handled
                case "d", "D":
                    // Toggle dark mode
                    dashboardManager.settings.enableDarkMode.toggle()
                    return .handled
                case "f", "F":
                    if let window = NSApp.keyWindow {
                        window.toggleFullScreen(nil)
                    }
                    return .handled
                default:
                    break
                }
            }
            return .ignored
        }
    }
}

#Preview {
    ContentView()
}
