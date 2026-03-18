//
//  DashboardScreensaverWidget.swift
//  DashboardScreensaver Widget
//
//  macOS WidgetKit widget for DashboardScreensaver.
//  Shows current dashboard, rotation status, health summary, and alert count.
//  Sizes: Small (pulse), Medium (status + health), Large (full dashboard grid)
//
//  Created by Jordan Koch on 2026-03-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DashboardScreensaverEntry: TimelineEntry {
    let date: Date
    let data: DashboardWidgetData
}

// MARK: - Timeline Provider

struct DashboardScreensaverProvider: TimelineProvider {

    func placeholder(in context: Context) -> DashboardScreensaverEntry {
        DashboardScreensaverEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardScreensaverEntry) -> Void) {
        let data = context.isPreview ? .placeholder : SharedDataManager.shared.loadWidgetData()
        completion(DashboardScreensaverEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardScreensaverEntry>) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = DashboardScreensaverEntry(date: Date(), data: data)
        // Refresh every 60s while rotating, every 5m when paused
        let interval: TimeInterval = data.isRotating && !data.isPaused ? 60 : 300
        let nextRefresh = Date().addingTimeInterval(interval)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8)  / 255
        let b = Double(int & 0x0000FF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}

private func healthColor(_ hex: String) -> Color { Color(hex: hex) }

// MARK: - Small Widget: Dashboard Pulse

struct DSSmallView: View {
    let entry: DashboardScreensaverEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "162032")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "38BDF8"))
                    Text("Dashboards")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }

                // Health ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 5)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: entry.data.healthPercent)
                        .stroke(
                            healthColor(entry.data.overallHealth.colorHex),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(entry.data.healthyCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/\(entry.data.totalDashboards)")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                }

                // Status badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(entry.data.isPaused ? Color(hex: "F59E0B") :
                              entry.data.isRotating ? Color(hex: "22C55E") : Color(hex: "64748B"))
                        .frame(width: 6, height: 6)
                        .shadow(color: entry.data.isRotating && !entry.data.isPaused ?
                                Color(hex: "22C55E") : .clear, radius: 3)
                    Text(entry.data.isPaused ? "Paused" :
                         entry.data.isRotating ? "Rotating" : "Stopped")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Current name
                Text(entry.data.currentDashboardName)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if entry.data.alertsDetected > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "EF4444"))
                        Text("\(entry.data.alertsDetected) alert\(entry.data.alertsDetected == 1 ? "" : "s")")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                }
            }
            .padding(10)
        }
        .containerBackground(for: .widget) { Color(hex: "0D1B2A") }
        .widgetURL(SharedDataManager.openAppURL)
    }
}

// MARK: - Medium Widget: Status + Health Overview

struct DSMediumView: View {
    let entry: DashboardScreensaverEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "162032")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "38BDF8"))
                    Text("Dashboard Screensaver")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()

                    // Rotation status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.data.isPaused ? Color(hex: "F59E0B") :
                                  entry.data.isRotating ? Color(hex: "22C55E") : Color(hex: "475569"))
                            .frame(width: 7, height: 7)
                            .shadow(color: entry.data.isRotating && !entry.data.isPaused ?
                                    Color(hex: "22C55E").opacity(0.8) : .clear, radius: 4)
                        Text(entry.data.isPaused ? "Paused" :
                             entry.data.isRotating ? "Live" : "Stopped")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(7)
                }

                // Current dashboard card
                HStack(spacing: 10) {
                    // Health ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 4)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: entry.data.healthPercent)
                            .stroke(
                                healthColor(entry.data.overallHealth.colorHex),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(entry.data.healthPercent * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOW SHOWING")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: "38BDF8"))
                            .tracking(1)
                        Text(entry.data.currentDashboardName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let schedule = entry.data.activeScheduleName {
                            Label(schedule, systemImage: "calendar.clock")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                        if let countdown = SharedDataManager.shared.countdownString(to: entry.data.nextRotationAt) {
                            Label("Next in \(countdown)", systemImage: "arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "94A3B8"))
                        }
                    }
                    Spacer()

                    // Alerts
                    if entry.data.alertsDetected > 0 {
                        VStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "EF4444"))
                            Text("\(entry.data.alertsDetected)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "EF4444"))
                            Text("alerts")
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: "EF4444").opacity(0.7))
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)

                // Health stats row
                HStack(spacing: 0) {
                    healthStat(icon: "checkmark.circle.fill", count: entry.data.healthyCount,
                               label: "Healthy", hex: "22C55E")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 26)
                    healthStat(icon: "minus.circle.fill", count: entry.data.degradedCount,
                               label: "Degraded", hex: "F59E0B")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 26)
                    healthStat(icon: "xmark.circle.fill", count: entry.data.failedCount,
                               label: "Failed", hex: "EF4444")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 26)
                    healthStat(icon: "rectangle.grid.2x2", count: entry.data.totalDashboards,
                               label: "Total", hex: "94A3B8")
                }
            }
            .padding(14)
        }
        .containerBackground(for: .widget) { Color(hex: "0D1B2A") }
        .widgetURL(SharedDataManager.openAppURL)
    }

    @ViewBuilder
    func healthStat(icon: String, count: Int, label: String, hex: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: hex))
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "64748B"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Large Widget: Full Dashboard Grid

struct DSLargeView: View {
    let entry: DashboardScreensaverEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "162032")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "38BDF8"))
                    Text("Dashboard Screensaver")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    // Overall health badge
                    HStack(spacing: 4) {
                        Image(systemName: entry.data.overallHealth.iconName)
                            .font(.system(size: 10))
                        Text(entry.data.overallHealth.label)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(healthColor(entry.data.overallHealth.colorHex))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(healthColor(entry.data.overallHealth.colorHex).opacity(0.12))
                    .cornerRadius(7)
                }

                Divider().background(Color.white.opacity(0.08))

                // Stats row
                HStack(spacing: 0) {
                    bigStat(icon: "checkmark.circle.fill", value: "\(entry.data.healthyCount)",
                            label: "Healthy", hex: "22C55E")
                    bigStat(icon: "minus.circle.fill", value: "\(entry.data.degradedCount)",
                            label: "Degraded", hex: "F59E0B")
                    bigStat(icon: "xmark.circle.fill", value: "\(entry.data.failedCount)",
                            label: "Failed", hex: "EF4444")
                    bigStat(icon: "exclamationmark.triangle.fill", value: "\(entry.data.alertsDetected)",
                            label: "Alerts", hex: entry.data.alertsDetected > 0 ? "EF4444" : "475569")
                }

                Divider().background(Color.white.opacity(0.08))

                // Current + rotation info
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("NOW SHOWING", systemImage: "play.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: "38BDF8"))
                        Text(entry.data.currentDashboardName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let schedule = entry.data.activeScheduleName {
                            Label(schedule, systemImage: "calendar.clock")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(entry.data.isPaused ? Color(hex: "F59E0B") :
                                      entry.data.isRotating ? Color(hex: "22C55E") : Color(hex: "475569"))
                                .frame(width: 6, height: 6)
                            Text(entry.data.isPaused ? "Paused" :
                                 entry.data.isRotating ? "Auto-Rotating" : "Stopped")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        if let countdown = SharedDataManager.shared.countdownString(to: entry.data.nextRotationAt) {
                            Text("Next: \(countdown)")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "94A3B8"))
                        }
                        // Pause / Resume links
                        if entry.data.isPaused {
                            Link(destination: SharedDataManager.resumeURL) {
                                Label("Resume", systemImage: "play.circle.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(hex: "22C55E"))
                            }
                        } else {
                            Link(destination: SharedDataManager.pauseURL) {
                                Label("Pause", systemImage: "pause.circle.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(hex: "F59E0B"))
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)

                Divider().background(Color.white.opacity(0.08))

                // Dashboard list
                if entry.data.recentDashboards.isEmpty {
                    Text("No dashboards configured")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "475569"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 4) {
                        ForEach(entry.data.recentDashboards.prefix(5)) { dash in
                            HStack(spacing: 8) {
                                // Health dot
                                Circle()
                                    .fill(healthColor(dash.health.colorHex))
                                    .frame(width: 7, height: 7)
                                    .shadow(color: dash.isActive ? healthColor(dash.health.colorHex) : .clear, radius: 3)

                                Text(dash.name)
                                    .font(.system(size: 10, weight: dash.isActive ? .semibold : .regular, design: .rounded))
                                    .foregroundColor(dash.isActive ? .white : Color(hex: "94A3B8"))
                                    .lineLimit(1)

                                Spacer()

                                if dash.isActive {
                                    Text("CURRENT")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(Color(hex: "38BDF8"))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "38BDF8").opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(dash.isActive ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                            .cornerRadius(6)
                        }
                        if entry.data.totalDashboards > 5 {
                            Text("+ \(entry.data.totalDashboards - 5) more dashboards")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "475569"))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Footer
                HStack {
                    Image(systemName: "clock").font(.system(size: 8)).foregroundColor(Color(hex: "334155"))
                    Text("Updated \(SharedDataManager.shared.dataAgeString(for: entry.data.lastUpdated))")
                        .font(.system(size: 9)).foregroundColor(Color(hex: "334155"))
                    Spacer()
                    if let last = entry.data.lastRotationAt {
                        Text("Last rotated \(SharedDataManager.shared.dataAgeString(for: last))")
                            .font(.system(size: 9)).foregroundColor(Color(hex: "334155"))
                    }
                }
            }
            .padding(14)
        }
        .containerBackground(for: .widget) { Color(hex: "0D1B2A") }
        .widgetURL(SharedDataManager.openAppURL)
    }

    @ViewBuilder
    func bigStat(icon: String, value: String, label: String, hex: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color(hex: hex))
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(label).font(.system(size: 8)).foregroundColor(Color(hex: "64748B"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Configuration

struct DashboardScreensaverWidget: Widget {
    let kind = "DashboardScreensaverWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardScreensaverProvider()) { entry in
            DashboardScreensaverEntryView(entry: entry)
        }
        .configurationDisplayName("Dashboard Screensaver")
        .description("Current dashboard, rotation status, health overview, and alert count.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DashboardScreensaverEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DashboardScreensaverEntry

    var body: some View {
        switch family {
        case .systemSmall:  DSSmallView(entry: entry)
        case .systemMedium: DSMediumView(entry: entry)
        case .systemLarge:  DSLargeView(entry: entry)
        default:            DSMediumView(entry: entry)
        }
    }
}

@main
struct DashboardScreensaverWidgetBundle: WidgetBundle {
    var body: some Widget {
        DashboardScreensaverWidget()
    }
}
