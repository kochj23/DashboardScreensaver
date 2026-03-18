//
//  SharedDataManager.swift
//  DashboardScreensaver Widget
//
//  Manages shared data between DashboardScreensaver and its Widget Extension.
//  Created by Jordan Koch on 2026-03-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

final class SharedDataManager {
    static let shared = SharedDataManager()

    private let appGroupIdentifier = "group.com.jordankoch.DashboardScreensaver"
    private let widgetDataKey = "dashboardWidgetData"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Read (Widget)

    func loadWidgetData() -> DashboardWidgetData {
        guard
            let defaults = sharedDefaults,
            let data = defaults.data(forKey: widgetDataKey),
            let decoded = try? JSONDecoder().decode(DashboardWidgetData.self, from: data)
        else {
            return .empty
        }
        return decoded
    }

    // MARK: - Write (Main App)

    func saveWidgetData(_ data: DashboardWidgetData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize()
            WidgetCenter.shared.reloadTimelines(ofKind: "DashboardScreensaverWidget")
        }
    }

    // MARK: - URL Helpers

    static let openAppURL = URL(string: "dashboardscreensaver://open")!
    static let pauseURL   = URL(string: "dashboardscreensaver://pause")!
    static let resumeURL  = URL(string: "dashboardscreensaver://resume")!

    // MARK: - Time Helpers

    func dataAgeString(for date: Date?) -> String {
        guard let date else { return "Never" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    func countdownString(to date: Date?) -> String? {
        guard let date else { return nil }
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 0 else { return nil }
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}
