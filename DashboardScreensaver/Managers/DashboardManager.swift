//
//  DashboardManager.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// Manages dashboard URLs, groups, schedules, and rotation state
@MainActor
class DashboardManager: ObservableObject {
    static let shared = DashboardManager()

    // MARK: - Published Properties

    @Published var dashboards: [DashboardURL] = []
    @Published var groups: [DashboardGroup] = []
    @Published var scheduleProfiles: [ScheduleProfile] = []
    @Published var settings: DashboardSettings = .default

    @Published var currentIndex: Int = 0
    @Published var isRotating: Bool = false
    @Published var isPaused: Bool = false

    // MARK: - Private Properties

    private var rotationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let userDefaultsKey = "DashboardScreensaver"

    // MARK: - Computed Properties

    var currentDashboard: DashboardURL? {
        let active = activeDashboards
        guard currentIndex >= 0, currentIndex < active.count else { return nil }
        return active[currentIndex]
    }

    var activeDashboards: [DashboardURL] {
        var urls: [DashboardURL]

        if settings.enableSchedule {
            // Get URLs from active schedule profile
            let activeProfile = scheduleProfiles
                .filter { $0.isEnabled && $0.isActive() }
                .max { $0.priority < $1.priority }

            if let profile = activeProfile {
                let groupIds = Set(profile.groupIds)
                let enabledGroups = groups.filter { groupIds.contains($0.id) && $0.isEnabled }
                let urlIds = Set(enabledGroups.flatMap { $0.urlIds })
                urls = dashboards.filter { urlIds.contains($0.id) && $0.isEnabled }
            } else {
                // No active profile, use all enabled URLs from enabled groups
                let enabledGroupIds = Set(groups.filter { $0.isEnabled }.map { $0.id })
                urls = dashboards.filter { dashboard in
                    dashboard.isEnabled && (dashboard.groupId == nil || enabledGroupIds.contains(dashboard.groupId!))
                }
            }
        } else {
            // No schedule, use all enabled URLs
            urls = dashboards.filter { $0.isEnabled }
        }

        // Filter out unhealthy URLs if enabled
        if settings.skipUnhealthyURLs {
            urls = urls.filter { $0.healthStatus != .failed }
        }

        return urls
    }

    // MARK: - Initialization

    private init() {
        loadData()
        setupAutoSave()
    }

    // MARK: - Rotation Control

    func startRotation() {
        guard !isRotating else { return }
        isRotating = true
        isPaused = false
        scheduleNextRotation()
    }

    func stopRotation() {
        isRotating = false
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    func pauseRotation() {
        isPaused = true
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    func resumeRotation() {
        guard isRotating else { return }
        isPaused = false
        scheduleNextRotation()
    }

    func toggleRotation() {
        if isRotating {
            if isPaused {
                resumeRotation()
            } else {
                pauseRotation()
            }
        } else {
            startRotation()
        }
    }

    func nextDashboard() {
        let active = activeDashboards
        guard !active.isEmpty else { return }

        currentIndex = (currentIndex + 1) % active.count

        if isRotating && !isPaused {
            scheduleNextRotation()
        }
    }

    func previousDashboard() {
        let active = activeDashboards
        guard !active.isEmpty else { return }

        currentIndex = currentIndex > 0 ? currentIndex - 1 : active.count - 1

        if isRotating && !isPaused {
            scheduleNextRotation()
        }
    }

    func goToFirst() {
        currentIndex = 0
        if isRotating && !isPaused {
            scheduleNextRotation()
        }
    }

    func goToLast() {
        let active = activeDashboards
        currentIndex = max(0, active.count - 1)
        if isRotating && !isPaused {
            scheduleNextRotation()
        }
    }

    private func scheduleNextRotation() {
        rotationTimer?.invalidate()

        let interval = settings.rotationInterval + settings.pageLoadDelay + settings.scrollDuration + settings.postScrollDelay

        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.nextDashboard()
            }
        }
    }

    func extendDisplayTime(by seconds: TimeInterval) {
        rotationTimer?.invalidate()

        let remaining = settings.rotationInterval + seconds

        rotationTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.nextDashboard()
            }
        }
    }

    // MARK: - Dashboard Management

    func addDashboard(url: String, name: String? = nil, groupId: UUID? = nil) {
        let dashboard = DashboardURL(url: url, name: name, groupId: groupId)
        dashboards.append(dashboard)

        if let groupId = groupId, let groupIndex = groups.firstIndex(where: { $0.id == groupId }) {
            groups[groupIndex].urlIds.append(dashboard.id)
            groups[groupIndex].updatedAt = Date()
        }

        saveData()
    }

    func removeDashboard(_ dashboard: DashboardURL) {
        dashboards.removeAll { $0.id == dashboard.id }

        // Remove from groups
        for i in groups.indices {
            groups[i].urlIds.removeAll { $0 == dashboard.id }
        }

        // Adjust current index if needed
        if currentIndex >= activeDashboards.count {
            currentIndex = max(0, activeDashboards.count - 1)
        }

        saveData()
    }

    func updateDashboard(_ dashboard: DashboardURL) {
        if let index = dashboards.firstIndex(where: { $0.id == dashboard.id }) {
            dashboards[index] = dashboard
            saveData()
        }
    }

    func updateHealthStatus(for dashboardId: UUID, status: URLHealthStatus, loadTime: TimeInterval? = nil) {
        guard let index = dashboards.firstIndex(where: { $0.id == dashboardId }) else { return }

        dashboards[index].healthStatus = status
        dashboards[index].lastChecked = Date()

        if status == .healthy {
            dashboards[index].consecutiveFailures = 0
            dashboards[index].lastSuccess = Date()

            if let loadTime = loadTime {
                let oldAvg = dashboards[index].averageLoadTime
                dashboards[index].averageLoadTime = oldAvg == 0 ? loadTime : (oldAvg * 0.8 + loadTime * 0.2)
            }

            // Update success rate
            let currentRate = dashboards[index].successRate
            dashboards[index].successRate = min(100, currentRate * 0.95 + 100 * 0.05)
        } else if status == .failed {
            dashboards[index].consecutiveFailures += 1

            // Update success rate
            let currentRate = dashboards[index].successRate
            dashboards[index].successRate = max(0, currentRate * 0.95)

            // Mark as failed after threshold
            if dashboards[index].consecutiveFailures >= settings.failureThreshold {
                dashboards[index].healthStatus = .failed
            }
        }

        saveData()
    }

    func resetHealthData() {
        for i in dashboards.indices {
            dashboards[i].healthStatus = .unknown
            dashboards[i].consecutiveFailures = 0
            dashboards[i].successRate = 100
            dashboards[i].averageLoadTime = 0
            dashboards[i].lastChecked = nil
            dashboards[i].lastSuccess = nil
        }
        saveData()
    }

    // MARK: - Group Management

    func addGroup(_ group: DashboardGroup) {
        groups.append(group)
        saveData()
    }

    func removeGroup(_ group: DashboardGroup) {
        // Remove group from dashboards
        for i in dashboards.indices where dashboards[i].groupId == group.id {
            dashboards[i].groupId = nil
        }

        // Remove from schedule profiles
        for i in scheduleProfiles.indices {
            scheduleProfiles[i].groupIds.removeAll { $0 == group.id }
        }

        groups.removeAll { $0.id == group.id }
        saveData()
    }

    func updateGroup(_ group: DashboardGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            groups[index].updatedAt = Date()
            saveData()
        }
    }

    func createDefaultGroups() {
        for defaultGroup in DashboardGroup.defaultGroups {
            if !groups.contains(where: { $0.name == defaultGroup.name }) {
                groups.append(defaultGroup)
            }
        }
        saveData()
    }

    // MARK: - Schedule Management

    func addScheduleProfile(_ profile: ScheduleProfile) {
        scheduleProfiles.append(profile)
        saveData()
    }

    func removeScheduleProfile(_ profile: ScheduleProfile) {
        scheduleProfiles.removeAll { $0.id == profile.id }
        saveData()
    }

    func updateScheduleProfile(_ profile: ScheduleProfile) {
        if let index = scheduleProfiles.firstIndex(where: { $0.id == profile.id }) {
            scheduleProfiles[index] = profile
            saveData()
        }
    }

    func createDefaultSchedules() {
        for defaultProfile in ScheduleProfile.defaultProfiles {
            if !scheduleProfiles.contains(where: { $0.name == defaultProfile.name }) {
                var profile = defaultProfile
                // Assign groups if they exist
                profile.groupIds = groups.map { $0.id }
                scheduleProfiles.append(profile)
            }
        }
        saveData()
    }

    // MARK: - Import/Export

    func importFromCSV(_ url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else {
                continue
            }

            // Check for duplicate
            if !dashboards.contains(where: { $0.url == trimmed }) {
                addDashboard(url: trimmed)
            }
        }
    }

    func importFromRemoteConfig(_ url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "DashboardManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else {
                continue
            }

            if !dashboards.contains(where: { $0.url == trimmed }) {
                addDashboard(url: trimmed)
            }
        }
    }

    // MARK: - Persistence

    private func loadData() {
        // Load dashboards
        if let data = UserDefaults.standard.data(forKey: "\(userDefaultsKey).dashboards"),
           let decoded = try? JSONDecoder().decode([DashboardURL].self, from: data) {
            dashboards = decoded
        }

        // Load groups
        if let data = UserDefaults.standard.data(forKey: "\(userDefaultsKey).groups"),
           let decoded = try? JSONDecoder().decode([DashboardGroup].self, from: data) {
            groups = decoded
        }

        // Load schedules
        if let data = UserDefaults.standard.data(forKey: "\(userDefaultsKey).schedules"),
           let decoded = try? JSONDecoder().decode([ScheduleProfile].self, from: data) {
            scheduleProfiles = decoded
        }

        // Load settings
        if let data = UserDefaults.standard.data(forKey: "\(userDefaultsKey).settings"),
           let decoded = try? JSONDecoder().decode(DashboardSettings.self, from: data) {
            settings = decoded
        }

        // Create defaults if empty
        if groups.isEmpty {
            createDefaultGroups()
        }

        // Load from config file if dashboards empty
        if dashboards.isEmpty {
            loadFromConfigFile()
        }
    }

    func saveData() {
        // Save dashboards
        if let encoded = try? JSONEncoder().encode(dashboards) {
            UserDefaults.standard.set(encoded, forKey: "\(userDefaultsKey).dashboards")
        }

        // Save groups
        if let encoded = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(encoded, forKey: "\(userDefaultsKey).groups")
        }

        // Save schedules
        if let encoded = try? JSONEncoder().encode(scheduleProfiles) {
            UserDefaults.standard.set(encoded, forKey: "\(userDefaultsKey).schedules")
        }

        // Save settings
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "\(userDefaultsKey).settings")
        }
    }

    private func setupAutoSave() {
        // Auto-save settings changes
        $settings
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
    }

    private func loadFromConfigFile() {
        // Try to load config.txt from various locations
        let possiblePaths = [
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("config.txt"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("config.txt"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".dashboardscreensaver/config.txt")
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    try importFromCSV(path)
                    return
                } catch {
                    print("Failed to load config from \(path): \(error)")
                }
            }
        }

        // Add default dashboards if no config found
        addDefaultDashboards()
    }

    private func addDefaultDashboards() {
        let defaults = [
            "https://status.github.com",
            "https://status.aws.amazon.com",
            "https://status.cloud.google.com"
        ]

        for url in defaults {
            addDashboard(url: url)
        }
    }
}
