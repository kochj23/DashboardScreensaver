//
//  PowerManager.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  Manages screen sleep prevention using IOKit
//

import Foundation
import IOKit.pwr_mgt

/// Manages screen sleep prevention
class PowerManager {
    static let shared = PowerManager()

    private var assertionID: IOPMAssertionID = 0
    private var isPreventingSleep: Bool = false

    private init() {}

    /// Prevent the screen from sleeping
    func preventSleep(reason: String = "Dashboard Screensaver active") {
        guard !isPreventingSleep else { return }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isPreventingSleep = true
            print("PowerManager: Screen sleep prevention enabled")
        } else {
            print("PowerManager: Failed to prevent screen sleep: \(result)")
        }
    }

    /// Allow the screen to sleep again
    func allowSleep() {
        guard isPreventingSleep else { return }

        let result = IOPMAssertionRelease(assertionID)

        if result == kIOReturnSuccess {
            isPreventingSleep = false
            assertionID = 0
            print("PowerManager: Screen sleep prevention disabled")
        } else {
            print("PowerManager: Failed to release sleep assertion: \(result)")
        }
    }

    /// Toggle sleep prevention
    func toggleSleepPrevention() {
        if isPreventingSleep {
            allowSleep()
        } else {
            preventSleep()
        }
    }

    deinit {
        allowSleep()
    }
}
