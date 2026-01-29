//
//  HealthMonitor.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine
import UserNotifications

/// Monitors health status of dashboard URLs
@MainActor
class HealthMonitor: ObservableObject {
    static let shared = HealthMonitor()

    // MARK: - Published Properties

    @Published var isMonitoring: Bool = false
    @Published var lastCheckTime: Date?

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var checkInProgress = false

    // MARK: - Initialization

    private init() {
        requestNotificationPermission()
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Initial check
        Task {
            await performHealthChecks()
        }

        // Schedule periodic checks
        let interval = DashboardManager.shared.settings.healthCheckInterval
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performHealthChecks()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    func checkNow() {
        Task {
            await performHealthChecks()
        }
    }

    // MARK: - Health Checks

    private func performHealthChecks() async {
        guard !checkInProgress else { return }
        checkInProgress = true

        defer {
            checkInProgress = false
            lastCheckTime = Date()
        }

        let dashboards = DashboardManager.shared.dashboards

        await withTaskGroup(of: (UUID, URLHealthStatus, TimeInterval?).self) { group in
            for dashboard in dashboards {
                guard dashboard.isEnabled,
                      let url = URL(string: dashboard.url) else { continue }

                // Skip recently checked URLs
                if let lastChecked = dashboard.lastChecked {
                    let timeSinceLastCheck = Date().timeIntervalSince(lastChecked)
                    if timeSinceLastCheck < DashboardManager.shared.settings.healthCheckInterval * 0.9 {
                        continue
                    }
                }

                // Skip failed URLs until retry interval
                if dashboard.healthStatus == .failed {
                    if let lastChecked = dashboard.lastChecked {
                        let timeSinceLastCheck = Date().timeIntervalSince(lastChecked)
                        if timeSinceLastCheck < DashboardManager.shared.settings.retryInterval {
                            continue
                        }
                    }
                }

                group.addTask {
                    let result = await self.checkURL(url)
                    return (dashboard.id, result.status, result.loadTime)
                }
            }

            for await (id, status, loadTime) in group {
                let previousStatus = DashboardManager.shared.dashboards.first { $0.id == id }?.healthStatus

                DashboardManager.shared.updateHealthStatus(for: id, status: status, loadTime: loadTime)

                // Send notification if status changed to failed
                if status == .failed && previousStatus != .failed {
                    if let dashboard = DashboardManager.shared.dashboards.first(where: { $0.id == id }) {
                        sendFailureNotification(for: dashboard)
                    }
                }

                // Send recovery notification
                if status == .healthy && previousStatus == .failed {
                    if let dashboard = DashboardManager.shared.dashboards.first(where: { $0.id == id }) {
                        sendRecoveryNotification(for: dashboard)
                    }
                }
            }
        }
    }

    private func checkURL(_ url: URL) async -> (status: URLHealthStatus, loadTime: TimeInterval?) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        let startTime = Date()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            let loadTime = Date().timeIntervalSince(startTime)

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return (.healthy, loadTime)
                case 300...399:
                    return (.healthy, loadTime) // Redirects are OK
                case 400...499:
                    return (.degraded, loadTime) // Client errors
                case 500...599:
                    return (.failed, loadTime) // Server errors
                default:
                    return (.degraded, loadTime)
                }
            }

            return (.healthy, loadTime)
        } catch {
            return (.failed, nil)
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func sendFailureNotification(for dashboard: DashboardURL) {
        guard DashboardManager.shared.settings.notifyOnAlert else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dashboard Unreachable"
        content.body = "\(dashboard.name) is not responding"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "health-\(dashboard.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sendRecoveryNotification(for dashboard: DashboardURL) {
        guard DashboardManager.shared.settings.notifyOnAlert else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dashboard Recovered"
        content.body = "\(dashboard.name) is now available"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "health-recovery-\(dashboard.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
