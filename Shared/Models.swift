//
//  Models.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Dashboard URL

struct DashboardURL: Identifiable, Codable, Hashable {
    let id: UUID
    var url: String
    var name: String
    var groupId: UUID?
    var isEnabled: Bool
    var healthStatus: URLHealthStatus
    var consecutiveFailures: Int
    var successRate: Double
    var averageLoadTime: TimeInterval
    var lastChecked: Date?
    var lastSuccess: Date?

    init(
        id: UUID = UUID(),
        url: String,
        name: String? = nil,
        groupId: UUID? = nil,
        isEnabled: Bool = true,
        healthStatus: URLHealthStatus = .unknown,
        consecutiveFailures: Int = 0,
        successRate: Double = 100,
        averageLoadTime: TimeInterval = 0,
        lastChecked: Date? = nil,
        lastSuccess: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? Self.extractName(from: url)
        self.groupId = groupId
        self.isEnabled = isEnabled
        self.healthStatus = healthStatus
        self.consecutiveFailures = consecutiveFailures
        self.successRate = successRate
        self.averageLoadTime = averageLoadTime
        self.lastChecked = lastChecked
        self.lastSuccess = lastSuccess
    }

    static func extractName(from url: String) -> String {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else {
            return url
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    var displayURL: URL? {
        URL(string: url)
    }
}

// MARK: - URL Health Status

enum URLHealthStatus: Int, Codable, CaseIterable {
    case unknown = 0
    case healthy = 1
    case degraded = 2
    case failed = 3

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

// MARK: - Dashboard Group

struct DashboardGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var colorHex: String
    var isEnabled: Bool
    var urlIds: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        colorHex: String = "#4DD9F3",
        isEnabled: Bool = true,
        urlIds: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.colorHex = colorHex
        self.isEnabled = isEnabled
        self.urlIds = urlIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var color: Color {
        Color(hex: colorHex) ?? ModernColors.accentCyan
    }

    static let defaultGroups: [DashboardGroup] = [
        DashboardGroup(name: "Monitoring", description: "System monitoring dashboards", colorHex: "#4DD9F3"),
        DashboardGroup(name: "Business", description: "Business metrics and KPIs", colorHex: "#9965F2"),
        DashboardGroup(name: "Security", description: "Security dashboards", colorHex: "#FF5AA7"),
        DashboardGroup(name: "General", description: "General purpose dashboards", colorHex: "#FF9933")
    ]
}

// MARK: - Schedule Profile

struct ScheduleProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var enabledDays: Set<DayOfWeek>
    var groupIds: [UUID]
    var priority: Int
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        enabledDays: Set<DayOfWeek> = Set(DayOfWeek.allCases),
        groupIds: [UUID] = [],
        priority: Int = 5,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.enabledDays = enabledDays
        self.groupIds = groupIds
        self.priority = priority
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var timeRangeDescription: String {
        let start = String(format: "%02d:%02d", startHour, startMinute)
        let end = String(format: "%02d:%02d", endHour, endMinute)
        return "\(start) - \(end)"
    }

    var daysDescription: String {
        if enabledDays.count == 7 {
            return "Every day"
        } else if enabledDays == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
            return "Weekdays"
        } else if enabledDays == Set([.saturday, .sunday]) {
            return "Weekends"
        } else {
            return enabledDays.sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
        }
    }

    func isActive(at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)

        guard let hour = components.hour,
              let minute = components.minute,
              let weekday = components.weekday else {
            return false
        }

        // Check day of week
        let dayOfWeek = DayOfWeek.from(calendarWeekday: weekday)
        guard enabledDays.contains(dayOfWeek) else {
            return false
        }

        // Check time range
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        // Handle overnight schedules (e.g., 22:00 - 06:00)
        if endMinutes < startMinutes {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }

    static let defaultProfiles: [ScheduleProfile] = [
        ScheduleProfile(
            name: "Business Hours",
            description: "Business dashboards during work hours",
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            enabledDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            priority: 10
        ),
        ScheduleProfile(
            name: "After Hours",
            description: "Monitoring focus after business hours",
            startHour: 17,
            startMinute: 0,
            endHour: 9,
            endMinute: 0,
            enabledDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            priority: 5
        ),
        ScheduleProfile(
            name: "Weekend",
            description: "Weekend monitoring",
            startHour: 0,
            startMinute: 0,
            endHour: 24,
            endMinute: 0,
            enabledDays: [.saturday, .sunday],
            priority: 5
        )
    ]
}

// MARK: - Day of Week

enum DayOfWeek: Int, Codable, CaseIterable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    static func from(calendarWeekday: Int) -> DayOfWeek {
        DayOfWeek(rawValue: calendarWeekday) ?? .sunday
    }

    static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Alert Severity

enum AlertSeverity: Int, Codable, CaseIterable, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var extraDisplayTime: TimeInterval {
        switch self {
        case .none: return 0
        case .low: return 5
        case .medium: return 10
        case .high: return 20
        case .critical: return 30
        }
    }

    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Dashboard Analysis Result

struct DashboardAnalysisResult: Identifiable {
    let id = UUID()
    let dashboardId: UUID
    let timestamp: Date
    let severity: AlertSeverity
    let redPercentage: Double
    let orangePercentage: Double
    let yellowPercentage: Double
    let detectedKeywords: [String]
    let contentChanged: Bool

    var hasAlerts: Bool {
        severity != .none || !detectedKeywords.isEmpty
    }

    var summaryText: String {
        var parts: [String] = []

        if severity != .none {
            parts.append("\(severity.displayName) alert")
        }

        if !detectedKeywords.isEmpty {
            parts.append("Keywords: \(detectedKeywords.joined(separator: ", "))")
        }

        if contentChanged {
            parts.append("Content changed")
        }

        return parts.isEmpty ? "No alerts" : parts.joined(separator: " | ")
    }
}

// MARK: - Apple TV Device

struct AppleTVDevice: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var ipAddress: String
    var port: Int
    var lastSeen: Date
    var isConfigured: Bool
    var assignedGroupId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        ipAddress: String,
        port: Int = 8080,
        lastSeen: Date = Date(),
        isConfigured: Bool = false,
        assignedGroupId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
        self.lastSeen = lastSeen
        self.isConfigured = isConfigured
        self.assignedGroupId = assignedGroupId
    }

    var baseURL: URL? {
        URL(string: "http://\(ipAddress):\(port)")
    }
}

// MARK: - Settings

struct DashboardSettings: Codable {
    // Rotation settings
    var rotationInterval: TimeInterval = 30
    var pageLoadDelay: TimeInterval = 2
    var scrollDuration: TimeInterval = 10
    var postScrollDelay: TimeInterval = 20

    // Display settings
    var enableDarkMode: Bool = true
    var preventScreenSleep: Bool = true
    var enableFullScreen: Bool = false

    // Health monitoring
    var enableHealthMonitoring: Bool = true
    var skipUnhealthyURLs: Bool = true
    var healthCheckInterval: TimeInterval = 60
    var failureThreshold: Int = 3
    var retryInterval: TimeInterval = 600

    // AI detection
    var enableAIDetection: Bool = true
    var alertThreshold: Double = 5.0
    var notifyOnAlert: Bool = true
    var pauseOnCritical: Bool = true
    var showAlertOverlay: Bool = true

    // Schedule
    var enableSchedule: Bool = false

    // Network
    var enableAppleTVDiscovery: Bool = true

    static let `default` = DashboardSettings()
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
