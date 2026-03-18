//
//  WidgetDataSync.swift
//  DashboardScreensaver
//
//  Writes dashboard rotation state to the App Group container
//  for the Widget Extension to display.
//  Call updateWidget() whenever rotation state, current dashboard, or health changes.
//
//  Created by Jordan Koch on 2026-03-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

final class WidgetDataSync {
    static let shared = WidgetDataSync()

    private let appGroupIdentifier = "group.com.jordankoch.DashboardScreensaver"
    private let widgetDataKey = "dashboardWidgetData"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Public API

    /// Call this on every rotation, pause/resume, or health change.
    @MainActor
    func updateWidget(from manager: DashboardManager, alertsDetected: Int = 0) {
        let current = manager.currentDashboard
        let all = manager.dashboards.filter { $0.isEnabled }

        let healthy  = all.filter { $0.healthStatus == .healthy }.count
        let degraded = all.filter { $0.healthStatus == .degraded }.count
        let failed   = all.filter { $0.healthStatus == .failed }.count

        let recent: [WidgetDashboard] = manager.activeDashboards.prefix(8).map { dash in
            WidgetDashboard(
                name: dash.name,
                health: mapHealth(dash.healthStatus),
                isActive: dash.id == current?.id
            )
        }

        let data = DashboardWidgetData(
            currentDashboardName: current?.name ?? "None",
            currentDashboardURL: current?.url ?? "",
            isRotating: manager.isRotating,
            isPaused: manager.isPaused,
            totalDashboards: all.count,
            healthyCount: healthy,
            degradedCount: degraded,
            failedCount: failed,
            alertsDetected: alertsDetected,
            activeScheduleName: nil,
            nextRotationAt: nil,
            lastRotationAt: Date(),
            recentDashboards: recent,
            lastUpdated: Date()
        )

        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "DashboardScreensaverWidget")
    }

    // MARK: - Helpers

    private func mapHealth(_ status: URLHealthStatus) -> WidgetURLHealth {
        switch status {
        case .healthy:  return .healthy
        case .degraded: return .degraded
        case .failed:   return .failed
        case .unknown:  return .unknown
        }
    }
}
