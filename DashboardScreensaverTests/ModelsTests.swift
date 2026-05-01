//
//  ModelsTests.swift
//  DashboardScreensaverTests
//
//  Unit tests for Shared/Models.swift data models
//  Created by Jordan Koch
//

import XCTest
import SwiftUI
@testable import DashboardScreensaver

final class DashboardURLTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitialization() {
        let dashboard = DashboardURL(url: "https://grafana.example.com/d/abc123")

        XCTAssertFalse(dashboard.id.uuidString.isEmpty)
        XCTAssertEqual(dashboard.url, "https://grafana.example.com/d/abc123")
        XCTAssertEqual(dashboard.name, "grafana.example.com")
        XCTAssertNil(dashboard.groupId)
        XCTAssertTrue(dashboard.isEnabled)
        XCTAssertEqual(dashboard.healthStatus, .unknown)
        XCTAssertEqual(dashboard.consecutiveFailures, 0)
        XCTAssertEqual(dashboard.successRate, 100)
        XCTAssertEqual(dashboard.averageLoadTime, 0)
        XCTAssertNil(dashboard.lastChecked)
        XCTAssertNil(dashboard.lastSuccess)
    }

    func testCustomNameOverridesExtracted() {
        let dashboard = DashboardURL(url: "https://grafana.example.com", name: "Production Grafana")
        XCTAssertEqual(dashboard.name, "Production Grafana")
    }

    func testGroupIdAssignment() {
        let groupId = UUID()
        let dashboard = DashboardURL(url: "https://example.com", groupId: groupId)
        XCTAssertEqual(dashboard.groupId, groupId)
    }

    // MARK: - Name Extraction

    func testExtractNameFromHTTPS() {
        XCTAssertEqual(DashboardURL.extractName(from: "https://grafana.example.com/d/abc"), "grafana.example.com")
    }

    func testExtractNameStripsWWW() {
        XCTAssertEqual(DashboardURL.extractName(from: "https://www.example.com/status"), "example.com")
    }

    func testExtractNameFromHTTP() {
        XCTAssertEqual(DashboardURL.extractName(from: "http://localhost:3000"), "localhost")
    }

    func testExtractNameInvalidURL() {
        XCTAssertEqual(DashboardURL.extractName(from: "not a url"), "not a url")
    }

    func testExtractNameEmptyString() {
        XCTAssertEqual(DashboardURL.extractName(from: ""), "")
    }

    // MARK: - Display URL

    func testDisplayURLValid() {
        let dashboard = DashboardURL(url: "https://example.com")
        XCTAssertNotNil(dashboard.displayURL)
        XCTAssertEqual(dashboard.displayURL?.host, "example.com")
    }

    func testDisplayURLInvalid() {
        let dashboard = DashboardURL(url: "not a valid url with spaces")
        // URL(string:) may or may not return nil for this; just test it doesn't crash
        _ = dashboard.displayURL
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = DashboardURL(
            url: "https://grafana.example.com",
            name: "Test",
            groupId: UUID(),
            isEnabled: false,
            healthStatus: .degraded,
            consecutiveFailures: 5,
            successRate: 85.5,
            averageLoadTime: 1.23
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DashboardURL.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.groupId, original.groupId)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
        XCTAssertEqual(decoded.healthStatus, original.healthStatus)
        XCTAssertEqual(decoded.consecutiveFailures, original.consecutiveFailures)
        XCTAssertEqual(decoded.successRate, original.successRate, accuracy: 0.01)
        XCTAssertEqual(decoded.averageLoadTime, original.averageLoadTime, accuracy: 0.01)
    }

    // MARK: - Hashable

    func testHashableEquality() {
        let id = UUID()
        let a = DashboardURL(id: id, url: "https://example.com")
        let b = DashboardURL(id: id, url: "https://example.com")
        XCTAssertEqual(a, b)
    }
}

// MARK: - URLHealthStatus Tests

final class URLHealthStatusTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(URLHealthStatus.allCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(URLHealthStatus.unknown.displayName, "Unknown")
        XCTAssertEqual(URLHealthStatus.healthy.displayName, "Healthy")
        XCTAssertEqual(URLHealthStatus.degraded.displayName, "Degraded")
        XCTAssertEqual(URLHealthStatus.failed.displayName, "Failed")
    }

    func testIcons() {
        XCTAssertEqual(URLHealthStatus.unknown.icon, "questionmark.circle")
        XCTAssertEqual(URLHealthStatus.healthy.icon, "checkmark.circle.fill")
        XCTAssertEqual(URLHealthStatus.degraded.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(URLHealthStatus.failed.icon, "xmark.circle.fill")
    }

    func testRawValues() {
        XCTAssertEqual(URLHealthStatus.unknown.rawValue, 0)
        XCTAssertEqual(URLHealthStatus.healthy.rawValue, 1)
        XCTAssertEqual(URLHealthStatus.degraded.rawValue, 2)
        XCTAssertEqual(URLHealthStatus.failed.rawValue, 3)
    }

    func testCodableRoundTrip() throws {
        for status in URLHealthStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(URLHealthStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - DashboardGroup Tests

final class DashboardGroupTests: XCTestCase {

    func testDefaultInitialization() {
        let group = DashboardGroup(name: "Monitoring")

        XCTAssertEqual(group.name, "Monitoring")
        XCTAssertEqual(group.description, "")
        XCTAssertEqual(group.colorHex, "#4DD9F3")
        XCTAssertTrue(group.isEnabled)
        XCTAssertTrue(group.urlIds.isEmpty)
    }

    func testDefaultGroups() {
        let defaults = DashboardGroup.defaultGroups
        XCTAssertEqual(defaults.count, 4)

        let names = defaults.map(\.name)
        XCTAssertTrue(names.contains("Monitoring"))
        XCTAssertTrue(names.contains("Business"))
        XCTAssertTrue(names.contains("Security"))
        XCTAssertTrue(names.contains("General"))
    }

    func testCodableRoundTrip() throws {
        let original = DashboardGroup(
            name: "Test Group",
            description: "A test group",
            colorHex: "#FF5AA7",
            isEnabled: true,
            urlIds: [UUID(), UUID()]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DashboardGroup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.colorHex, original.colorHex)
        XCTAssertEqual(decoded.urlIds, original.urlIds)
    }
}

// MARK: - ScheduleProfile Tests

final class ScheduleProfileTests: XCTestCase {

    func testDefaultInitialization() {
        let profile = ScheduleProfile(name: "Business Hours")

        XCTAssertEqual(profile.name, "Business Hours")
        XCTAssertEqual(profile.startHour, 9)
        XCTAssertEqual(profile.endHour, 17)
        XCTAssertEqual(profile.priority, 5)
        XCTAssertTrue(profile.isEnabled)
        XCTAssertEqual(profile.enabledDays.count, 7) // All days
    }

    func testTimeRangeDescription() {
        let profile = ScheduleProfile(name: "Test", startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)
        XCTAssertEqual(profile.timeRangeDescription, "09:00 - 17:30")
    }

    func testDaysDescriptionEveryDay() {
        let profile = ScheduleProfile(name: "Test")
        XCTAssertEqual(profile.daysDescription, "Every day")
    }

    func testDaysDescriptionWeekdays() {
        let profile = ScheduleProfile(
            name: "Test",
            enabledDays: [.monday, .tuesday, .wednesday, .thursday, .friday]
        )
        XCTAssertEqual(profile.daysDescription, "Weekdays")
    }

    func testDaysDescriptionWeekends() {
        let profile = ScheduleProfile(
            name: "Test",
            enabledDays: [.saturday, .sunday]
        )
        XCTAssertEqual(profile.daysDescription, "Weekends")
    }

    func testDaysDescriptionCustom() {
        let profile = ScheduleProfile(
            name: "Test",
            enabledDays: [.monday, .wednesday, .friday]
        )
        XCTAssertEqual(profile.daysDescription, "Mon, Wed, Fri")
    }

    // MARK: - isActive Tests

    func testIsActiveBusinessHours() {
        let profile = ScheduleProfile(
            name: "Business",
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            enabledDays: [.monday, .tuesday, .wednesday, .thursday, .friday]
        )

        // Create a date for Wednesday at 12:00
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 28 // Wednesday
        components.hour = 12
        components.minute = 0

        if let date = calendar.date(from: components) {
            XCTAssertTrue(profile.isActive(at: date))
        }
    }

    func testIsActiveBeforeStart() {
        let profile = ScheduleProfile(
            name: "Business",
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            enabledDays: Set(DayOfWeek.allCases)
        )

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 28
        components.hour = 8
        components.minute = 59

        if let date = calendar.date(from: components) {
            XCTAssertFalse(profile.isActive(at: date))
        }
    }

    func testIsActiveOvernightSchedule() {
        let profile = ScheduleProfile(
            name: "After Hours",
            startHour: 22,
            startMinute: 0,
            endHour: 6,
            endMinute: 0,
            enabledDays: Set(DayOfWeek.allCases)
        )

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 28

        // 23:00 should be active
        components.hour = 23
        components.minute = 0
        if let date = calendar.date(from: components) {
            XCTAssertTrue(profile.isActive(at: date))
        }

        // 3:00 should be active
        components.hour = 3
        components.minute = 0
        if let date = calendar.date(from: components) {
            XCTAssertTrue(profile.isActive(at: date))
        }

        // 12:00 should NOT be active
        components.hour = 12
        components.minute = 0
        if let date = calendar.date(from: components) {
            XCTAssertFalse(profile.isActive(at: date))
        }
    }

    func testIsActiveDisabledDay() {
        let profile = ScheduleProfile(
            name: "Weekdays",
            startHour: 0,
            startMinute: 0,
            endHour: 24,
            endMinute: 0,
            enabledDays: [.monday, .tuesday, .wednesday, .thursday, .friday]
        )

        // Find a Saturday in 2026
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 31 // Saturday
        components.hour = 12
        components.minute = 0

        if let date = calendar.date(from: components) {
            let weekday = calendar.component(.weekday, from: date)
            // Only test if this is actually a Saturday (weekday == 7)
            if weekday == 7 {
                XCTAssertFalse(profile.isActive(at: date))
            }
        }
    }

    func testDefaultProfiles() {
        let defaults = ScheduleProfile.defaultProfiles
        XCTAssertEqual(defaults.count, 3)

        let names = defaults.map(\.name)
        XCTAssertTrue(names.contains("Business Hours"))
        XCTAssertTrue(names.contains("After Hours"))
        XCTAssertTrue(names.contains("Weekend"))
    }

    func testCodableRoundTrip() throws {
        let original = ScheduleProfile(
            name: "Test Schedule",
            startHour: 8,
            startMinute: 30,
            endHour: 18,
            endMinute: 45,
            enabledDays: [.monday, .wednesday, .friday],
            groupIds: [UUID()],
            priority: 10
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScheduleProfile.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.startHour, original.startHour)
        XCTAssertEqual(decoded.endHour, original.endHour)
        XCTAssertEqual(decoded.enabledDays, original.enabledDays)
        XCTAssertEqual(decoded.priority, original.priority)
    }
}

// MARK: - DayOfWeek Tests

final class DayOfWeekTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(DayOfWeek.allCases.count, 7)
    }

    func testFromCalendarWeekday() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 1), .sunday)
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 2), .monday)
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 7), .saturday)
    }

    func testFromCalendarWeekdayInvalid() {
        XCTAssertEqual(DayOfWeek.from(calendarWeekday: 99), .sunday) // Default
    }

    func testShortNames() {
        XCTAssertEqual(DayOfWeek.monday.shortName, "Mon")
        XCTAssertEqual(DayOfWeek.sunday.shortName, "Sun")
    }

    func testFullNames() {
        XCTAssertEqual(DayOfWeek.monday.fullName, "Monday")
        XCTAssertEqual(DayOfWeek.sunday.fullName, "Sunday")
    }

    func testComparable() {
        XCTAssertTrue(DayOfWeek.sunday < DayOfWeek.monday)
        XCTAssertTrue(DayOfWeek.friday < DayOfWeek.saturday)
    }
}

// MARK: - AlertSeverity Tests

final class AlertSeverityTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(AlertSeverity.allCases.count, 5)
    }

    func testDisplayNames() {
        XCTAssertEqual(AlertSeverity.none.displayName, "None")
        XCTAssertEqual(AlertSeverity.low.displayName, "Low")
        XCTAssertEqual(AlertSeverity.medium.displayName, "Medium")
        XCTAssertEqual(AlertSeverity.high.displayName, "High")
        XCTAssertEqual(AlertSeverity.critical.displayName, "Critical")
    }

    func testExtraDisplayTime() {
        XCTAssertEqual(AlertSeverity.none.extraDisplayTime, 0)
        XCTAssertEqual(AlertSeverity.low.extraDisplayTime, 5)
        XCTAssertEqual(AlertSeverity.medium.extraDisplayTime, 10)
        XCTAssertEqual(AlertSeverity.high.extraDisplayTime, 20)
        XCTAssertEqual(AlertSeverity.critical.extraDisplayTime, 30)
    }

    func testComparable() {
        XCTAssertTrue(AlertSeverity.none < AlertSeverity.low)
        XCTAssertTrue(AlertSeverity.low < AlertSeverity.medium)
        XCTAssertTrue(AlertSeverity.medium < AlertSeverity.high)
        XCTAssertTrue(AlertSeverity.high < AlertSeverity.critical)
    }

    func testCodableRoundTrip() throws {
        for severity in AlertSeverity.allCases {
            let data = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(AlertSeverity.self, from: data)
            XCTAssertEqual(decoded, severity)
        }
    }
}

// MARK: - DashboardAnalysisResult Tests

final class DashboardAnalysisResultTests: XCTestCase {

    func testHasAlertsNone() {
        let result = DashboardAnalysisResult(
            dashboardId: UUID(),
            timestamp: Date(),
            severity: .none,
            redPercentage: 0,
            orangePercentage: 0,
            yellowPercentage: 0,
            detectedKeywords: [],
            contentChanged: false
        )
        XCTAssertFalse(result.hasAlerts)
    }

    func testHasAlertsSeverity() {
        let result = DashboardAnalysisResult(
            dashboardId: UUID(),
            timestamp: Date(),
            severity: .high,
            redPercentage: 10,
            orangePercentage: 0,
            yellowPercentage: 0,
            detectedKeywords: [],
            contentChanged: false
        )
        XCTAssertTrue(result.hasAlerts)
    }

    func testHasAlertsKeywords() {
        let result = DashboardAnalysisResult(
            dashboardId: UUID(),
            timestamp: Date(),
            severity: .none,
            redPercentage: 0,
            orangePercentage: 0,
            yellowPercentage: 0,
            detectedKeywords: ["error"],
            contentChanged: false
        )
        XCTAssertTrue(result.hasAlerts)
    }

    func testSummaryTextNoAlerts() {
        let result = DashboardAnalysisResult(
            dashboardId: UUID(),
            timestamp: Date(),
            severity: .none,
            redPercentage: 0,
            orangePercentage: 0,
            yellowPercentage: 0,
            detectedKeywords: [],
            contentChanged: false
        )
        XCTAssertEqual(result.summaryText, "No alerts")
    }

    func testSummaryTextCriticalWithKeywords() {
        let result = DashboardAnalysisResult(
            dashboardId: UUID(),
            timestamp: Date(),
            severity: .critical,
            redPercentage: 15,
            orangePercentage: 0,
            yellowPercentage: 0,
            detectedKeywords: ["error", "outage"],
            contentChanged: true
        )
        XCTAssertTrue(result.summaryText.contains("Critical alert"))
        XCTAssertTrue(result.summaryText.contains("Keywords: error, outage"))
        XCTAssertTrue(result.summaryText.contains("Content changed"))
    }
}

// MARK: - AppleTVDevice Tests

final class AppleTVDeviceTests: XCTestCase {

    func testDefaultInitialization() {
        let device = AppleTVDevice(name: "Living Room TV", ipAddress: "192.168.1.50")

        XCTAssertEqual(device.name, "Living Room TV")
        XCTAssertEqual(device.ipAddress, "192.168.1.50")
        XCTAssertEqual(device.port, 8080)
        XCTAssertFalse(device.isConfigured)
        XCTAssertNil(device.assignedGroupId)
    }

    func testBaseURL() {
        let device = AppleTVDevice(name: "Test", ipAddress: "192.168.1.50", port: 8080)
        XCTAssertEqual(device.baseURL?.absoluteString, "http://192.168.1.50:8080")
    }

    func testCustomPort() {
        let device = AppleTVDevice(name: "Test", ipAddress: "10.0.0.1", port: 9090)
        XCTAssertEqual(device.baseURL?.absoluteString, "http://10.0.0.1:9090")
    }

    func testCodableRoundTrip() throws {
        let original = AppleTVDevice(
            name: "Office TV",
            ipAddress: "192.168.1.100",
            port: 8080,
            isConfigured: true,
            assignedGroupId: UUID()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppleTVDevice.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.ipAddress, original.ipAddress)
        XCTAssertEqual(decoded.port, original.port)
        XCTAssertEqual(decoded.isConfigured, original.isConfigured)
        XCTAssertEqual(decoded.assignedGroupId, original.assignedGroupId)
    }
}

// MARK: - DashboardSettings Tests

final class DashboardSettingsTests: XCTestCase {

    func testDefaultValues() {
        let settings = DashboardSettings.default

        XCTAssertEqual(settings.rotationInterval, 30)
        XCTAssertEqual(settings.pageLoadDelay, 2)
        XCTAssertEqual(settings.scrollDuration, 10)
        XCTAssertEqual(settings.postScrollDelay, 20)
        XCTAssertTrue(settings.enableDarkMode)
        XCTAssertTrue(settings.preventScreenSleep)
        XCTAssertFalse(settings.enableFullScreen)
        XCTAssertTrue(settings.enableHealthMonitoring)
        XCTAssertTrue(settings.skipUnhealthyURLs)
        XCTAssertEqual(settings.healthCheckInterval, 60)
        XCTAssertEqual(settings.failureThreshold, 3)
        XCTAssertEqual(settings.retryInterval, 600)
        XCTAssertTrue(settings.enableAIDetection)
        XCTAssertEqual(settings.alertThreshold, 5.0)
        XCTAssertTrue(settings.notifyOnAlert)
        XCTAssertTrue(settings.pauseOnCritical)
        XCTAssertTrue(settings.showAlertOverlay)
        XCTAssertFalse(settings.enableSchedule)
        XCTAssertTrue(settings.enableAppleTVDiscovery)
    }

    func testCodableRoundTrip() throws {
        var settings = DashboardSettings()
        settings.rotationInterval = 60
        settings.enableDarkMode = false
        settings.failureThreshold = 5

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(DashboardSettings.self, from: data)

        XCTAssertEqual(decoded.rotationInterval, 60)
        XCTAssertEqual(decoded.enableDarkMode, false)
        XCTAssertEqual(decoded.failureThreshold, 5)
    }
}

// MARK: - Color Extension Tests

final class ColorExtensionTests: XCTestCase {

    func testValidHexColor() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testHexWithoutHash() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
    }

    func testInvalidHex() {
        let color = Color(hex: "not a hex")
        XCTAssertNil(color)
    }

    func testEmptyHex() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testHexWithWhitespace() {
        let color = Color(hex: "  #FF5500  ")
        XCTAssertNotNil(color)
    }
}
