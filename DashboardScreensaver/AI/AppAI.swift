//
//  AppAI.swift
//  Dashboard Screensaver
//
//  The app's one AI object (NovaAIKit 1.0.0). Settings persist in UserDefaults (no secrets);
//  API keys live only in the Keychain under com.jkoch.dashboardscreensaver.<backend>.
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    nonisolated static let appID = "dashboardscreensaver"
    nonisolated static let appName = "Dashboard Screensaver"

    /// Keychain service the old, removed AIBackendManager used.
    nonisolated static let legacyKeychainService = "com.jordankoch.DashboardScreensaver"

    /// Accounts the old AIBackendManager wrote into `legacyKeychainService` for the removed
    /// Google/Azure/AWS/IBM backends. They have no successor and are deleted (never read out).
    nonisolated static let legacyObsoleteAccounts = [
        "AIBackend_GoogleCloud_Key", "AIBackend_Azure_Key", "AIBackend_Azure_Endpoint",
        "AIBackend_AWS_AccessKey", "AIBackend_AWS_SecretKey", "AIBackend_IBM_Key", "AIBackend_IBM_URL",
    ]

    static let shared: NovaAI = {
        let ai = NovaAI(configuration: NovaAIConfiguration(appID: appID, appName: appName))
        migrateLegacy(ai)
        return ai
    }()

    /// UserDefaults flag set once the old Keychain items have been handled.
    nonisolated static let legacyKeychainMarker = "AppAI.legacyKeychainMigrated"

    /// One-time import of the old AIBackendManager settings and keys. Idempotent.
    static func migrateLegacy(_ ai: NovaAI, defaults: UserDefaults = .standard,
                              legacyStore: (any NovaAIKeyStore)? = nil) {
        // Old UserDefaults settings; plaintext OpenAI key -> Keychain; obsolete cloud secrets deleted.
        ai.migrateFromLegacyAIBackendManager(defaults: defaults)
        guard !defaults.bool(forKey: legacyKeychainMarker) else { return }
        // Old Keychain item (this app's alone) -> com.jkoch.dashboardscreensaver.openai.
        ai.migrateLegacyKey(service: legacyKeychainService, account: "AIBackend_OpenAI_Key", to: .openAI,
                            deleteLegacy: true, legacyStore: legacyStore)
        ai.keys.deleteObsoleteLegacyItems(service: legacyKeychainService, accounts: legacyObsoleteAccounts,
                                          legacyStore: legacyStore)
        ai.keys.deleteObsoleteLegacyItems(service: legacyKeychainService, legacyStore: legacyStore)
        defaults.set(true, forKey: legacyKeychainMarker)
    }
}
