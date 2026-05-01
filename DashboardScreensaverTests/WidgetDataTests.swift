//
//  WidgetDataTests.swift
//  DashboardScreensaverTests
//
//  Unit tests for Shared/WidgetData.swift models
//  Created by Jordan Koch
//

import XCTest
@testable import DashboardScreensaver

final class DashboardWidgetDataTests: XCTestCase {

    // MARK: - Computed Properties

    func testHealthPercentAllHealthy() {
        let data = DashboardWidgetData(
            currentDashboardName: "Test",
            currentDashboardURL: "https://example.com",
            isRotating: true,
            isPaused: false,
            totalDashboards: 10,
            healthyCount: 10,
            degradedCount: 0,
            failedCount: 0,
            alertsDetected: 0,
            recentDashboards: [],
            lastUpdated: Date()
        )
        XCTAssertEqual(data.healthPercent, 1.0, accuracy: 0.01)
        XCTAssertEqual(data.failedPercent, 0.0, accuracy: 0.01)
    }

    func testHealthPercentMixed() {
        let data = DashboardWidgetData(
            currentDashboardName: "Test",
            currentDashboardURL: "https://example.com",
            isRotating: true,
            isPaused: false,
            totalDashboards: 10,
            healthyCount: 6,
            degradedCount: 2,
            failedCount: 2,
            alertsDetected: 1,
            recentDashboards: [],
            lastUpdated: Date()
        )
        XCTAssertEqual(data.healthPercent, 0.6, accuracy: 0.01)
        XCTAssertEqual(data.failedPercent, 0.2, accuracy: 0.01)
    }

    func testHealthPercentZeroDashboards() {
        let data = DashboardWidgetData.empty
        XCTAssertEqual(data.healthPercent, 0.0, accuracy: 0.01)
        XCTAssertEqual(data.failedPercent, 0.0, accuracy: 0.01)
    }

    // MARK: - Overall Health

    func testOverallHealthAllGreen() {
        let data = DashboardWidgetData(
            currentDashboardName: "Test",
            currentDashboardURL: "https://example.com",
            isRotating: true,
            isPaused: false,
            totalDashboards: 5,
            healthyCount: 5,
            degradedCount: 0,
            failedCount: 0,
            alertsDetected: 0,
            recentDashboards: [],
            lastUpdated: Date()
        )
        XCTAssertEqual(data.overallHealth, .allGreen)
    }

    func testOverallHealthWarning() {
        let data = DashboardWidgetData(
            currentDashboardName: "Test",
            currentDashboardURL: "https://example.com",
            isRotating: true,
            isPaused: false,
            totalDashboards: 10,
            healthyCount: 7,
            degradedCount: 1,
            failedCount: 2,
            alertsDetected: 0,
            recentDashboards: [],
            lastUpdated: Date()
        )
        XCTAssertEqual(data.overallHealth, .warning)
    }

    func testOverallHealthCritical() {
        let data = DashboardWidgetData(
            currentDashboardName: "Test",
            currentDashboardURL: "https://example.com",
            isRotating: true,
            isPaused: false,
            totalDashboards: 10,
            healthyCount: 3,
            degradedCount: 0,
            failedCount: 7,
            alertsDetected: 5,
            recentDashboards: [],
            lastUpdated: Date()
        )
        XCTAssertEqual(data.overallHealth, .critical)
    }

    // MARK: - Placeholder and Empty

    func testPlaceholder() {
        let placeholder = DashboardWidgetData.placeholder
        XCTAssertEqual(placeholder.totalDashboards, 12)
        XCTAssertTrue(placeholder.isRotating)
        XCTAssertFalse(placeholder.isPaused)
        XCTAssertEqual(placeholder.recentDashboards.count, 5)
    }

    func testEmpty() {
        let empty = DashboardWidgetData.empty
        XCTAssertEqual(empty.totalDashboards, 0)
        XCTAssertFalse(empty.isRotating)
        XCTAssertTrue(empty.recentDashboards.isEmpty)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = DashboardWidgetData.placeholder
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DashboardWidgetData.self, from: data)

        XCTAssertEqual(decoded.totalDashboards, original.totalDashboards)
        XCTAssertEqual(decoded.healthyCount, original.healthyCount)
        XCTAssertEqual(decoded.failedCount, original.failedCount)
        XCTAssertEqual(decoded.recentDashboards.count, original.recentDashboards.count)
    }
}

// MARK: - DashboardHealth Tests

final class DashboardHealthTests: XCTestCase {

    func testLabels() {
        XCTAssertEqual(DashboardHealth.allGreen.label, "All Green")
        XCTAssertEqual(DashboardHealth.nominal.label, "Nominal")
        XCTAssertEqual(DashboardHealth.warning.label, "Warning")
        XCTAssertEqual(DashboardHealth.critical.label, "Critical")
    }

    func testColorHexValues() {
        XCTAssertFalse(DashboardHealth.allGreen.colorHex.isEmpty)
        XCTAssertFalse(DashboardHealth.critical.colorHex.isEmpty)
    }

    func testIconNames() {
        XCTAssertFalse(DashboardHealth.allGreen.iconName.isEmpty)
        XCTAssertFalse(DashboardHealth.critical.iconName.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(DashboardHealth.warning)
        let decoded = try JSONDecoder().decode(DashboardHealth.self, from: data)
        XCTAssertEqual(decoded, .warning)
    }
}

// MARK: - WidgetDashboard Tests

final class WidgetDashboardTests: XCTestCase {

    func testInitialization() {
        let dashboard = WidgetDashboard(name: "Grafana", health: .healthy, isActive: true)
        XCTAssertEqual(dashboard.name, "Grafana")
        XCTAssertEqual(dashboard.health, .healthy)
        XCTAssertTrue(dashboard.isActive)
        XCTAssertFalse(dashboard.id.uuidString.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let original = WidgetDashboard(name: "Test", health: .degraded, isActive: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetDashboard.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.health, original.health)
        XCTAssertEqual(decoded.isActive, original.isActive)
    }
}

// MARK: - WidgetURLHealth Tests

final class WidgetURLHealthTests: XCTestCase {

    func testColorHexValues() {
        XCTAssertEqual(WidgetURLHealth.unknown.colorHex, "475569")
        XCTAssertEqual(WidgetURLHealth.healthy.colorHex, "22C55E")
        XCTAssertEqual(WidgetURLHealth.degraded.colorHex, "F59E0B")
        XCTAssertEqual(WidgetURLHealth.failed.colorHex, "EF4444")
    }

    func testDot() {
        for health in [WidgetURLHealth.unknown, .healthy, .degraded, .failed] {
            XCTAssertEqual(health.dot, "\u{25CF}") // filled circle
        }
    }
}
