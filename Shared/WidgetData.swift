//
//  WidgetData.swift
//  DashboardScreensaver Widget
//
//  Data models shared between DashboardScreensaver and its Widget Extension.
//  Created by Jordan Koch on 2026-03-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

// MARK: - Widget Dashboard Data

struct DashboardWidgetData: Codable {
    var currentDashboardName: String
    var currentDashboardURL: String
    var isRotating: Bool
    var isPaused: Bool
    var totalDashboards: Int
    var healthyCount: Int
    var degradedCount: Int
    var failedCount: Int
    var alertsDetected: Int
    var activeScheduleName: String?
    var nextRotationAt: Date?
    var lastRotationAt: Date?
    var recentDashboards: [WidgetDashboard]
    var lastUpdated: Date

    var failedPercent: Double {
        guard totalDashboards > 0 else { return 0 }
        return Double(failedCount) / Double(totalDashboards)
    }

    var healthPercent: Double {
        guard totalDashboards > 0 else { return 0 }
        return Double(healthyCount) / Double(totalDashboards)
    }

    var overallHealth: DashboardHealth {
        if failedPercent >= 0.5 { return .critical }
        if failedPercent >= 0.2 || degradedCount > 0 { return .warning }
        if healthyCount == totalDashboards { return .allGreen }
        return .nominal
    }

    static var placeholder: DashboardWidgetData {
        DashboardWidgetData(
            currentDashboardName: "DataDog — Production",
            currentDashboardURL: "https://datadoghq.com",
            isRotating: true,
            isPaused: false,
            totalDashboards: 12,
            healthyCount: 10,
            degradedCount: 1,
            failedCount: 1,
            alertsDetected: 2,
            activeScheduleName: "Business Hours",
            nextRotationAt: Date().addingTimeInterval(45),
            lastRotationAt: Date().addingTimeInterval(-15),
            recentDashboards: [
                WidgetDashboard(name: "DataDog — Prod",    health: .healthy,  isActive: true),
                WidgetDashboard(name: "Grafana — Metrics", health: .healthy,  isActive: false),
                WidgetDashboard(name: "Kibana — Logs",     health: .degraded, isActive: false),
                WidgetDashboard(name: "Prometheus",        health: .healthy,  isActive: false),
                WidgetDashboard(name: "PagerDuty",         health: .failed,   isActive: false)
            ],
            lastUpdated: Date()
        )
    }

    static var empty: DashboardWidgetData {
        DashboardWidgetData(
            currentDashboardName: "No Dashboards",
            currentDashboardURL: "",
            isRotating: false,
            isPaused: false,
            totalDashboards: 0,
            healthyCount: 0,
            degradedCount: 0,
            failedCount: 0,
            alertsDetected: 0,
            activeScheduleName: nil,
            nextRotationAt: nil,
            lastRotationAt: nil,
            recentDashboards: [],
            lastUpdated: Date()
        )
    }
}

enum DashboardHealth: Int, Codable {
    case allGreen = 0
    case nominal  = 1
    case warning  = 2
    case critical = 3

    var label: String {
        switch self { case .allGreen: return "All Green"; case .nominal: return "Nominal"
        case .warning: return "Warning"; case .critical: return "Critical" }
    }
    var colorHex: String {
        switch self { case .allGreen: return "22C55E"; case .nominal: return "00D4FF"
        case .warning: return "F59E0B"; case .critical: return "EF4444" }
    }
    var iconName: String {
        switch self { case .allGreen: return "checkmark.circle.fill"; case .nominal: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle.fill"; case .critical: return "xmark.octagon.fill" }
    }
}

struct WidgetDashboard: Codable, Identifiable {
    let id: UUID
    var name: String
    var health: WidgetURLHealth
    var isActive: Bool

    init(name: String, health: WidgetURLHealth, isActive: Bool) {
        self.id = UUID()
        self.name = name
        self.health = health
        self.isActive = isActive
    }
}

enum WidgetURLHealth: Int, Codable {
    case unknown  = 0
    case healthy  = 1
    case degraded = 2
    case failed   = 3

    var colorHex: String {
        switch self { case .unknown: return "475569"; case .healthy: return "22C55E"
        case .degraded: return "F59E0B"; case .failed: return "EF4444" }
    }
    var dot: String { "●" }
}
