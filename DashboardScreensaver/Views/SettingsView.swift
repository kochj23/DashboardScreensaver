//
//  SettingsView.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dashboardManager = DashboardManager.shared

    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    ModernHeader(text: "Settings", size: .medium)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }
                .padding()

                Divider()

                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Timing").tag(0)
                    Text("Display").tag(1)
                    Text("Health").tag(2)
                    Text("AI Detection").tag(3)
                    Text("Schedules").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                ScrollView {
                    switch selectedTab {
                    case 0:
                        timingSettings
                    case 1:
                        displaySettings
                    case 2:
                        healthSettings
                    case 3:
                        aiSettings
                    case 4:
                        scheduleSettings
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Timing Settings

    private var timingSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingGroup("Rotation") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rotation Interval")
                        Spacer()
                        Text("\(Int(dashboardManager.settings.rotationInterval)) seconds")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: $dashboardManager.settings.rotationInterval, in: 5...300, step: 5)
                        .tint(ModernColors.accentCyan)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Page Load Delay")
                        Spacer()
                        Text("\(Int(dashboardManager.settings.pageLoadDelay)) seconds")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: $dashboardManager.settings.pageLoadDelay, in: 0...10, step: 0.5)
                        .tint(ModernColors.accentCyan)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scroll Duration")
                        Spacer()
                        Text("\(Int(dashboardManager.settings.scrollDuration)) seconds")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: $dashboardManager.settings.scrollDuration, in: 0...60, step: 1)
                        .tint(ModernColors.accentCyan)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Post-Scroll Delay")
                        Spacer()
                        Text("\(Int(dashboardManager.settings.postScrollDelay)) seconds")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: $dashboardManager.settings.postScrollDelay, in: 0...60, step: 1)
                        .tint(ModernColors.accentCyan)
                }
            }
        }
    }

    // MARK: - Display Settings

    private var displaySettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingGroup("Appearance") {
                Toggle("Enable Dark Mode CSS Injection", isOn: $dashboardManager.settings.enableDarkMode)
                    .tint(ModernColors.accentCyan)

                Text("Injects dark mode CSS into dashboards that don't support dark mode natively")
                    .font(.caption)
                    .foregroundColor(ModernColors.textTertiary)
            }

            settingGroup("Power") {
                Toggle("Prevent Screen Sleep", isOn: $dashboardManager.settings.preventScreenSleep)
                    .tint(ModernColors.accentCyan)
                    .onChange(of: dashboardManager.settings.preventScreenSleep) { _, newValue in
                        if newValue {
                            PowerManager.shared.preventSleep()
                        } else {
                            PowerManager.shared.allowSleep()
                        }
                    }

                Text("Keeps the display on while dashboards are rotating")
                    .font(.caption)
                    .foregroundColor(ModernColors.textTertiary)
            }

            settingGroup("Window") {
                Toggle("Start in Full Screen", isOn: $dashboardManager.settings.enableFullScreen)
                    .tint(ModernColors.accentCyan)
            }
        }
    }

    // MARK: - Health Settings

    private var healthSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingGroup("Health Monitoring") {
                Toggle("Enable Health Monitoring", isOn: $dashboardManager.settings.enableHealthMonitoring)
                    .tint(ModernColors.accentCyan)
                    .onChange(of: dashboardManager.settings.enableHealthMonitoring) { _, newValue in
                        if newValue {
                            HealthMonitor.shared.startMonitoring()
                        } else {
                            HealthMonitor.shared.stopMonitoring()
                        }
                    }

                Toggle("Skip Unhealthy URLs", isOn: $dashboardManager.settings.skipUnhealthyURLs)
                    .tint(ModernColors.accentCyan)
                    .disabled(!dashboardManager.settings.enableHealthMonitoring)
            }

            settingGroup("Thresholds") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Failure Threshold")
                        Spacer()
                        Text("\(dashboardManager.settings.failureThreshold) failures")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: Binding(
                        get: { Double(dashboardManager.settings.failureThreshold) },
                        set: { dashboardManager.settings.failureThreshold = Int($0) }
                    ), in: 1...10, step: 1)
                    .tint(ModernColors.accentCyan)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Retry Interval")
                        Spacer()
                        Text("\(Int(dashboardManager.settings.retryInterval / 60)) minutes")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: $dashboardManager.settings.retryInterval, in: 60...3600, step: 60)
                        .tint(ModernColors.accentCyan)
                }
            }

            settingGroup("Actions") {
                Button("Reset All Health Data") {
                    dashboardManager.resetHealthData()
                }
                .buttonStyle(ModernButtonStyle(style: .destructive))
            }
        }
    }

    // MARK: - AI Settings

    private var aiSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingGroup("AI Alert Detection") {
                Toggle("Enable AI Detection", isOn: $dashboardManager.settings.enableAIDetection)
                    .tint(ModernColors.accentCyan)

                Text("Uses Vision framework for color analysis and OCR to detect alerts in dashboards")
                    .font(.caption)
                    .foregroundColor(ModernColors.textTertiary)
            }

            settingGroup("Thresholds") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Alert Threshold")
                        Spacer()
                        Text("\(Int(dashboardManager.settings.alertThreshold))%")
                            .foregroundColor(ModernColors.textSecondary)
                    }
                    Slider(value: $dashboardManager.settings.alertThreshold, in: 1...50, step: 1)
                        .tint(ModernColors.accentCyan)
                }

                Text("Percentage of alert-colored pixels to trigger detection")
                    .font(.caption)
                    .foregroundColor(ModernColors.textTertiary)
            }

            settingGroup("Behavior") {
                Toggle("Notify on Alert", isOn: $dashboardManager.settings.notifyOnAlert)
                    .tint(ModernColors.accentCyan)

                Toggle("Pause on Critical Alert", isOn: $dashboardManager.settings.pauseOnCritical)
                    .tint(ModernColors.accentCyan)

                Toggle("Show Alert Overlay", isOn: $dashboardManager.settings.showAlertOverlay)
                    .tint(ModernColors.accentCyan)
            }
        }
    }

    // MARK: - Schedule Settings

    private var scheduleSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingGroup("Schedule-Based Rotation") {
                Toggle("Enable Schedules", isOn: $dashboardManager.settings.enableSchedule)
                    .tint(ModernColors.accentCyan)

                Text("When enabled, shows different dashboard groups based on time of day and day of week")
                    .font(.caption)
                    .foregroundColor(ModernColors.textTertiary)
            }

            settingGroup("Profiles") {
                ForEach(dashboardManager.scheduleProfiles) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))

                            Text("\(profile.timeRangeDescription) • \(profile.daysDescription)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(ModernColors.textSecondary)
                        }

                        Spacer()

                        if profile.isActive() {
                            Text("Active")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(ModernColors.statusLow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ModernColors.statusLow.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }

                if dashboardManager.scheduleProfiles.isEmpty {
                    Button("Create Default Schedules") {
                        dashboardManager.createDefaultSchedules()
                    }
                    .buttonStyle(ModernButtonStyle(style: .outlined, color: ModernColors.accentCyan))
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func settingGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    SettingsView()
}
