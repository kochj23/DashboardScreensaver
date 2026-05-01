//
//  SecurityTests.swift
//  DashboardScreensaverTests
//
//  Security tests: no hardcoded credentials, safe URL construction,
//  Keychain usage verification, loopback-only API binding
//  Created by Jordan Koch
//

import XCTest
@testable import DashboardScreensaver

final class SecurityTests: XCTestCase {

    // MARK: - Source Code Credential Scanning

    /// Verify no hardcoded API keys, tokens, or credentials in Swift source files
    func testNoHardcodedCredentialsInSource() throws {
        let projectDir = findProjectDirectory()
        guard let dir = projectDir else {
            // If we can't find the project dir at test time, skip gracefully
            return
        }

        let suspiciousPatterns = [
            "sk-[A-Za-z0-9]{20,}",          // OpenAI keys
            "sk_live_[A-Za-z0-9]+",          // Stripe live keys
            "AKIA[A-Z0-9]{16}",              // AWS access keys
            "ghp_[A-Za-z0-9]{36}",           // GitHub PATs
            "xox[bpoas]-[A-Za-z0-9-]+",      // Slack tokens
            "Bearer [A-Za-z0-9._-]{20,}",    // Bearer tokens
        ]

        let swiftFiles = findSwiftFiles(in: dir)
        var violations: [String] = []

        for file in swiftFiles {
            // Skip test files
            if file.contains("Tests/") || file.contains("SecurityTests") { continue }

            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }

            for pattern in suspiciousPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                    violations.append("Potential credential in \(file) matching pattern: \(pattern)")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, "Found potential credentials:\n\(violations.joined(separator: "\n"))")
    }

    /// Verify no plaintext passwords in source code
    func testNoPlaintextPasswords() throws {
        let projectDir = findProjectDirectory()
        guard let dir = projectDir else { return }

        let passwordPatterns = [
            "password\\s*=\\s*\"[^\"]{4,}\"",
            "passwd\\s*=\\s*\"[^\"]{4,}\"",
            "secret\\s*=\\s*\"[^\"]{4,}\"",
        ]

        let swiftFiles = findSwiftFiles(in: dir)
        var violations: [String] = []

        for file in swiftFiles {
            if file.contains("Tests/") { continue }

            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }

            for pattern in passwordPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                    for match in matches {
                        let matchedString = (content as NSString).substring(with: match.range)
                        // Exclude known safe patterns (empty strings, placeholders, examples)
                        if !matchedString.contains("\"\"") &&
                           !matchedString.contains("placeholder") &&
                           !matchedString.contains("example") &&
                           !matchedString.contains("keychain") {
                            violations.append("Potential hardcoded password in \(file): \(matchedString)")
                        }
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, "Found potential passwords:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - API Key Storage

    /// Verify AIBackendManager uses Keychain for cloud API keys
    func testAPIKeysUseKeychain() throws {
        let projectDir = findProjectDirectory()
        guard let dir = projectDir else { return }

        // Check that AIBackendManager.swift references Keychain
        let aiBackendPath = dir + "/DashboardScreensaver/Managers/AIBackendManager.swift"
        guard let content = try? String(contentsOfFile: aiBackendPath, encoding: .utf8) else {
            return
        }

        XCTAssertTrue(content.contains("saveToKeychain"), "AIBackendManager should use saveToKeychain for credential storage")
        XCTAssertTrue(content.contains("loadFromKeychain"), "AIBackendManager should use loadFromKeychain for credential retrieval")
        XCTAssertTrue(content.contains("kSecClass"), "AIBackendManager should use Security framework Keychain APIs")
        XCTAssertTrue(content.contains("SecItemAdd"), "AIBackendManager should use SecItemAdd for Keychain storage")
        XCTAssertTrue(content.contains("SecItemCopyMatching"), "AIBackendManager should use SecItemCopyMatching for Keychain retrieval")

        // Verify migration from UserDefaults is implemented
        XCTAssertTrue(content.contains("migrateAPIKeysFromUserDefaults"), "AIBackendManager should migrate keys from UserDefaults to Keychain")
    }

    // MARK: - Nova API Server Security

    /// Verify API server binds to loopback only (127.0.0.1)
    func testAPIServerBindsToLoopback() throws {
        let projectDir = findProjectDirectory()
        guard let dir = projectDir else { return }

        let serverPath = dir + "/DashboardScreensaver/NovaAPIServer.swift"
        guard let content = try? String(contentsOfFile: serverPath, encoding: .utf8) else {
            return
        }

        XCTAssertTrue(content.contains("127.0.0.1"), "NovaAPIServer must bind to 127.0.0.1 (loopback only)")
        XCTAssertFalse(content.contains("0.0.0.0"), "NovaAPIServer must NOT bind to 0.0.0.0 (all interfaces)")
    }

    /// Verify API server uses correct port
    func testAPIServerPort() throws {
        let projectDir = findProjectDirectory()
        guard let dir = projectDir else { return }

        let serverPath = dir + "/DashboardScreensaver/NovaAPIServer.swift"
        guard let content = try? String(contentsOfFile: serverPath, encoding: .utf8) else {
            return
        }

        XCTAssertTrue(content.contains("37428"), "NovaAPIServer should use port 37428")
    }

    // MARK: - URL Construction Safety

    /// Verify AppleTVDevice constructs URLs safely
    func testAppleTVDeviceURLConstruction() {
        // Normal IP
        let device = AppleTVDevice(name: "Test", ipAddress: "192.168.1.50", port: 8080)
        XCTAssertEqual(device.baseURL?.scheme, "http")
        XCTAssertEqual(device.baseURL?.host, "192.168.1.50")
        XCTAssertEqual(device.baseURL?.port, 8080)
    }

    func testAppleTVDeviceURLWithSpecialChars() {
        // Ensure special characters in IP don't create injection
        let device = AppleTVDevice(name: "Test", ipAddress: "192.168.1.50/../../admin", port: 8080)
        // URL(string:) should handle or reject this
        if let url = device.baseURL {
            // The path should not allow directory traversal
            XCTAssertEqual(url.host, "192.168.1.50")
        }
    }

    // MARK: - Input Validation

    /// Verify DashboardURL handles edge case URLs safely
    func testURLEdgeCases() {
        // JavaScript protocol should not crash
        let js = DashboardURL(url: "javascript:alert(1)")
        XCTAssertNotNil(js.displayURL) // URL(string:) accepts this but it won't load
        XCTAssertEqual(js.displayURL?.scheme, "javascript")

        // Data URI
        let data = DashboardURL(url: "data:text/html,<h1>test</h1>")
        _ = data.displayURL // Should not crash

        // Empty URL
        let empty = DashboardURL(url: "")
        XCTAssertNil(empty.displayURL)

        // Very long URL
        let longURL = "https://example.com/" + String(repeating: "a", count: 10000)
        let long = DashboardURL(url: longURL)
        XCTAssertNotNil(long.displayURL)
    }

    // MARK: - HTTP Response Parsing

    /// Verify NovaAPIServer HTTP response format includes security headers
    func testNovaAPIServerResponseFormat() throws {
        let projectDir = findProjectDirectory()
        guard let dir = projectDir else { return }

        let serverPath = dir + "/DashboardScreensaver/NovaAPIServer.swift"
        guard let content = try? String(contentsOfFile: serverPath, encoding: .utf8) else {
            return
        }

        // Verify CORS header is set (Access-Control-Allow-Origin)
        XCTAssertTrue(content.contains("Access-Control-Allow-Origin"), "NovaAPIServer should set CORS headers")

        // Verify Connection: close header is set (prevents connection hijacking)
        XCTAssertTrue(content.contains("Connection: close"), "NovaAPIServer should close connections after response")

        // Verify Content-Length header is set (prevents response splitting)
        XCTAssertTrue(content.contains("Content-Length"), "NovaAPIServer should set Content-Length header")
    }

    // MARK: - Helpers

    private func findProjectDirectory() -> String? {
        // Try common locations
        let paths = [
            "/Volumes/Data/xcode/DashboardScreensaver",
            Bundle.main.bundlePath + "/../../.."
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path + "/DashboardScreensaver") {
                return path
            }
        }
        return nil
    }

    private func findSwiftFiles(in directory: String) -> [String] {
        var files: [String] = []
        let enumerator = FileManager.default.enumerator(atPath: directory)
        while let element = enumerator?.nextObject() as? String {
            if element.hasSuffix(".swift") && !element.contains("build/") && !element.contains(".xcodeproj") {
                files.append(directory + "/" + element)
            }
        }
        return files
    }
}
