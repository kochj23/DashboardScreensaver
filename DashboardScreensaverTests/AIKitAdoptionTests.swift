//
//  AIKitAdoptionTests.swift
//  DashboardScreensaverTests
//
//  The app's contract with NovaAIKit 1.0.0 (AI alert briefing), grouped in the seven
//  categories: security, performance, retry, unit, integration, functional, frame/UI-state.
//  Nothing here touches the real Keychain or the network: settings and keys are in memory
//  and every request goes to a stub URLProtocol.
//

import XCTest
import SwiftUI
import NovaAIKit
@testable import DashboardScreensaver

// MARK: - Support

/// Serves canned replies; records requests. Refuses everything when no reply is queued, and refuses (without
/// recording or consuming a reply) late requests from sessions of earlier tests.
final class AIStubProtocol: URLProtocol {
    struct Reply { var status: Int; var body: String }
    static let tokenHeader = "X-AIKit-Test-Session"
    private static let lock = NSLock()
    private static var replies: [Reply] = []
    private static var seen: [URLRequest] = []
    private static var token = UUID().uuidString

    /// A new session token; only requests carrying it are served.
    static func newSessionToken() -> String {
        lock.lock(); defer { lock.unlock() }
        token = UUID().uuidString
        return token
    }

    static func queue(_ r: [Reply]) { lock.lock(); replies = r; seen = []; lock.unlock() }
    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return seen }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let current = request.value(forHTTPHeaderField: Self.tokenHeader) == Self.token
        if current { Self.seen.append(request) }
        let reply = (!current || Self.replies.isEmpty) ? nil : Self.replies.removeFirst()
        Self.lock.unlock()
        guard let reply, let url = request.url,
              let http = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1",
                                         headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    /// An Ollama /api/chat reply carrying `text`.
    static func ollama(_ text: String) -> Reply {
        let obj: [String: Any] = ["model": "test-model", "message": ["role": "assistant", "content": text], "done": true]
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
        return Reply(status: 200, body: String(decoding: data, as: UTF8.self))
    }
}

enum AITestSupport {
    @MainActor
    static func makeAI(_ settings: NovaAISettings = NovaAISettings(backend: .ollama),
                       keys: NovaAIMemoryKeyStore = NovaAIMemoryKeyStore()) -> NovaAI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [AIStubProtocol.self]
        cfg.httpAdditionalHeaders = [AIStubProtocol.tokenHeader: AIStubProtocol.newSessionToken()]
        return NovaAI(configuration: NovaAIConfiguration(appID: AppAI.appID, appName: AppAI.appName),
                      storage: NovaAIMemoryStorage(settings), keyStore: keys,
                      session: URLSession(configuration: cfg), sleep: { _ in })
    }

    static let critical = AlertBriefing.Input(
        dashboardName: "Payments API", severity: .critical, redPercentage: 12.5, orangePercentage: 3,
        yellowPercentage: 0, keywords: ["error", "down"],
        alertLines: ["checkout-service DOWN", "Error rate 42% (5xx)"], contentChanged: true)

    static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
}

// MARK: - Security

final class AISecurityTests: XCTestCase {
    func testKeychainServiceNames() {
        let c = NovaAIConfiguration(appID: "dashboardscreensaver", appName: "Dashboard Screensaver")
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.dashboardscreensaver.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.dashboardscreensaver.openai")
        XCTAssertEqual(AppAI.appID, "dashboardscreensaver")
    }

    /// The plaintext OpenAI key the old AIBackendManager kept in UserDefaults moves to the Keychain and is
    /// removed from defaults; the removed cloud backends' plaintext secrets are deleted.
    @MainActor
    func testLegacyPlaintextKeysLeaveUserDefaults() throws {
        let suite = "AIKitAdoptionTests.security.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("sk-test-not-a-real-key-000000", forKey: "AIBackend_OpenAI_Key")
        defaults.set("legacy-google", forKey: "AIBackend_GoogleCloud_Key")
        defaults.set("legacy-aws", forKey: "AIBackend_AWS_SecretKey")
        let store = NovaAIMemoryKeyStore()
        let legacy = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(keys: store)

        AppAI.migrateLegacy(ai, defaults: defaults, legacyStore: legacy)

        XCTAssertNil(defaults.object(forKey: "AIBackend_OpenAI_Key"))
        XCTAssertNil(defaults.object(forKey: "AIBackend_GoogleCloud_Key"))
        XCTAssertNil(defaults.object(forKey: "AIBackend_AWS_SecretKey"))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
    }

    /// The old Keychain item (service com.jordankoch.DashboardScreensaver) moves to com.jkoch.dashboardscreensaver.openai
    /// and the removed backends' items are deleted.
    @MainActor
    func testLegacyKeychainItemsMigrateOnce() throws {
        let suite = "AIKitAdoptionTests.keychain.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = NovaAIMemoryKeyStore()
        _ = legacy.write("sk-legacy-not-real", service: AppAI.legacyKeychainService, account: "AIBackend_OpenAI_Key")
        _ = legacy.write("old-azure", service: AppAI.legacyKeychainService, account: "AIBackend_Azure_Key")
        let store = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(keys: store)

        AppAI.migrateLegacy(ai, defaults: defaults, legacyStore: legacy)

        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        XCTAssertNil(legacy.read(service: AppAI.legacyKeychainService, account: "AIBackend_OpenAI_Key"))
        XCTAssertNil(legacy.read(service: AppAI.legacyKeychainService, account: "AIBackend_Azure_Key"))
        XCTAssertTrue(defaults.bool(forKey: AppAI.legacyKeychainMarker))
    }

    /// Keys never end up in the persisted settings blob.
    @MainActor
    func testKeysAreNotInSettings() throws {
        let ai = AITestSupport.makeAI()
        XCTAssertTrue(ai.setAPIKey("sk-or-test-not-real", for: .openRouter))
        let blob = String(decoding: try JSONEncoder().encode(ai.settings), as: UTF8.self)
        XCTAssertFalse(blob.contains("sk-or-test-not-real"))
    }

    /// A key is never sent over plain http to a remote host.
    @MainActor
    func testKeyNotSentOverHTTP() async {
        var s = NovaAISettings(backend: .openAI)
        s.setURL("http://example.com/v1", for: .openAI)
        let ai = AITestSupport.makeAI(s)
        _ = ai.setAPIKey("sk-test-not-real", for: .openAI)
        AIStubProtocol.queue([AIStubProtocol.ollama("should not be used")])
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: ai)
        XCTAssertFalse(r.isAI)
        XCTAssertTrue(AIStubProtocol.requests.isEmpty, "a keyed request went out over http")
    }

    /// No copy of the old AI client is left in the app's sources.
    func testNoLegacyAIClientInSources() throws {
        let root = AITestSupport.repoRoot()
        let fm = FileManager.default
        var hits: [String] = []
        for dir in ["DashboardScreensaver", "DashboardTV", "Shared", "DashboardScreensaver Widget"] {
            guard let e = fm.enumerator(atPath: root.appendingPathComponent(dir).path) else { continue }
            while let f = e.nextObject() as? String {
                guard f.hasSuffix(".swift") else { continue }
                let text = (try? String(contentsOf: root.appendingPathComponent(dir).appendingPathComponent(f), encoding: .utf8)) ?? ""
                for needle in ["AIBackendManager.shared", "class AIBackendManager", "EthicalAIGuardian", "OPENAI_API_KEY",
                               "AIBackendStatusMenu"] where text.contains(needle) {
                    hits.append("\(dir)/\(f): \(needle)")
                }
            }
        }
        XCTAssertEqual(hits, [])
    }
}

// MARK: - Performance

final class AIPerformanceTests: XCTestCase {
    @MainActor
    func testFallbackIsImmediateWhenAIOff() async {
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false))
        let start = Date()
        for _ in 0..<50 { _ = await AlertBriefing.brief(AITestSupport.critical, ai: ai) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }

    @MainActor
    func testOfflineFallbackDoesNotHang() async {
        AIStubProtocol.queue([])
        let ai = AITestSupport.makeAI(NovaAISettings(backend: .auto))
        let start = Date()
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: ai)
        XCTAssertFalse(r.isAI)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5.0)
    }

    func testValidatorAndFactsAreCheapOnHugeOCR() throws {
        let lines = (0..<10_000).map { "error line \($0) " + String(repeating: "x", count: 500) }
        let input = AlertBriefing.Input(dashboardName: "Big", severity: .high, keywords: ["error"], alertLines: lines)
        measure {
            _ = input.facts
            _ = try? AlertBriefing.validate("Errors are spiking on Big; check the error lines first.", input: input)
        }
        XCTAssertEqual(input.alertLines.count, AlertBriefing.maxLines)
        XCTAssertTrue(input.alertLines.allSatisfy { $0.count <= AlertBriefing.maxLineLength })
    }
}

// MARK: - Retry

final class AIRetryTests: XCTestCase {
    /// A 503 is retried on the same backend and the second answer is used.
    @MainActor
    func testTransientServerErrorIsRetried() async {
        AIStubProtocol.queue([.init(status: 503, body: "{}"),
                              AIStubProtocol.ollama("Checkout service is down; check its pods first.")])
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: AITestSupport.makeAI())
        XCTAssertTrue(r.isAI)
        XCTAssertEqual(r.value, "Checkout service is down; check its pods first.")
    }

    /// An invented number is rejected; the kit asks once more and the corrected reply is used.
    @MainActor
    func testRejectedReplyIsAskedAgain() async {
        AIStubProtocol.queue([AIStubProtocol.ollama("Error rate is 97% on 3 hosts."),
                              AIStubProtocol.ollama("Error rate is 42% and checkout-service is down; check it first.")])
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: AITestSupport.makeAI())
        XCTAssertTrue(r.isAI)
        XCTAssertTrue(r.value.contains("42%"))
        XCTAssertEqual(AIStubProtocol.requests.count, 2)
    }

    /// Two rejected replies → built-in briefing, flagged as a validation fallback.
    @MainActor
    func testTwiceRejectedFallsBack() async {
        AIStubProtocol.queue([AIStubProtocol.ollama("Error rate is 97%."), AIStubProtocol.ollama("Still 97%.")])
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: AITestSupport.makeAI())
        XCTAssertFalse(r.isAI)
        guard case .fallback(.validationFailed) = r.source else { return XCTFail("expected validationFailed, got \(r.source)") }
        XCTAssertEqual(r.value, AlertBriefing.fallback(for: AITestSupport.critical))
    }
}

// MARK: - Unit

final class AIUnitTests: XCTestCase {
    func testFallbackDescribesTheAlert() {
        let text = AlertBriefing.fallback(for: AITestSupport.critical)
        XCTAssertTrue(text.hasPrefix("Critical alert on Payments API: error, down."))
        XCTAssertTrue(text.contains("checkout-service DOWN"))
        XCTAssertTrue(text.contains("Content changed"))
        XCTAssertLessThanOrEqual(text.count, AlertBriefing.maxLength)
    }

    func testValidatorAcceptsGroundedPlainText() throws {
        let v = try AlertBriefing.validate("  **Error rate 42%** on Payments API;\ncheck checkout-service.  ",
                                           input: AITestSupport.critical)
        XCTAssertEqual(v, "Error rate 42% on Payments API; check checkout-service.")
    }

    func testValidatorRejectsNonsense() {
        let input = AITestSupport.critical
        XCTAssertThrowsError(try AlertBriefing.validate("", input: input))
        XCTAssertThrowsError(try AlertBriefing.validate("ok", input: input))
        XCTAssertThrowsError(try AlertBriefing.validate(String(repeating: "word ", count: 80), input: input))
        XCTAssertThrowsError(try AlertBriefing.validate("Latency is 900 ms on 7 nodes.", input: input))
        XCTAssertThrowsError(try AlertBriefing.validate("<think>12345</think>", input: input))
    }

    func testThinkBlocksAreStripped() throws {
        let v = try AlertBriefing.validate("<think>maybe 99</think>Checkout service is down.", input: AITestSupport.critical)
        XCTAssertEqual(v, "Checkout service is down.")
    }

    func testFactsCarryEverythingTheModelNeeds() {
        let facts = AITestSupport.critical.facts
        XCTAssertTrue(facts.contains("Dashboard: Payments API"))
        XCTAssertTrue(facts.contains("Severity: Critical"))
        XCTAssertTrue(facts.contains("red 12.5%"))
        XCTAssertTrue(facts.contains("- Error rate 42% (5xx)"))
        let req = AlertBriefing.request(for: AITestSupport.critical)
        XCTAssertEqual(req.messages.first?.role, .system)
        XCTAssertLessThanOrEqual(req.maxTokens, 200)
    }

    func testPercentagesAreClamped() {
        XCTAssertEqual(AlertBriefing.Input.pct(-3), "0.0")
        XCTAssertEqual(AlertBriefing.Input.pct(250), "100.0")
    }

    func testBackendCatalogue() {
        XCTAssertEqual(NovaAIBackend.allCases.count, 9)
    }
}

// MARK: - Integration

final class AIIntegrationTests: XCTestCase {
    /// A real Ollama-shaped exchange through the kit: the request carries the facts, the reply is used.
    @MainActor
    func testBriefingFromOllama() async throws {
        AIStubProtocol.queue([AIStubProtocol.ollama("Checkout service is down with a 42% error rate; check it first.")])
        let ai = AITestSupport.makeAI()
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: ai)
        XCTAssertTrue(r.isAI)
        XCTAssertTrue(r.source.label.hasPrefix("AI · Ollama"))
        let req = try XCTUnwrap(AIStubProtocol.requests.first)
        XCTAssertEqual(req.url?.path, "/api/chat")
    }

    /// Old AIBackendManager UserDefaults settings are imported once.
    @MainActor
    func testLegacySettingsMigrate() throws {
        let suite = "AIKitAdoptionTests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Ollama", forKey: "AIBackend_Active")
        defaults.set("http://studio.local:11434", forKey: "AIBackend_OllamaURL")
        defaults.set("qwen3:8b", forKey: "AIBackend_OllamaModel")
        let ai = AITestSupport.makeAI(NovaAISettings())

        AppAI.migrateLegacy(ai, defaults: defaults, legacyStore: NovaAIMemoryKeyStore())

        XCTAssertEqual(ai.settings.backend, .ollama)
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://studio.local:11434")
        XCTAssertEqual(ai.settings.model(for: .ollama), "qwen3:8b")
    }
}

// MARK: - Functional

final class AIFunctionalTests: XCTestCase {
    /// AI off → every alert still gets its built-in briefing, and nothing is sent.
    @MainActor
    func testEveryFeatureWorksWithAIOff() async {
        AIStubProtocol.queue([AIStubProtocol.ollama("unused")])
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false))
        for severity in AlertSeverity.allCases {
            let input = AlertBriefing.Input(dashboardName: "Grafana", severity: severity, keywords: ["alert"])
            let r = await AlertBriefing.brief(input, ai: ai)
            XCTAssertFalse(r.value.isEmpty)
            XCTAssertEqual(r.source, .fallback(.disabled))
        }
        XCTAssertTrue(AIStubProtocol.requests.isEmpty)
    }

    /// Every backend down → built-in briefing.
    @MainActor
    func testEveryFeatureFallsBackWhenOffline() async {
        AIStubProtocol.queue([])
        let r = await AlertBriefing.brief(AITestSupport.critical, ai: AITestSupport.makeAI(NovaAISettings(backend: .auto)))
        XCTAssertFalse(r.isAI)
        XCTAssertEqual(r.value, AlertBriefing.fallback(for: AITestSupport.critical))
    }
}

// MARK: - Frame / UI state

final class AIFrameTests: XCTestCase {
    @MainActor
    func testStatusReflectsToggleAndSource() async {
        let ai = AITestSupport.makeAI()
        ai.isEnabled = false
        XCTAssertEqual(ai.status.state, .off)
        _ = await AlertBriefing.brief(AITestSupport.critical, ai: ai)
        XCTAssertEqual(ai.status.lastSource, .fallback(.disabled))

        ai.isEnabled = true
        AIStubProtocol.queue([AIStubProtocol.ollama("Checkout service is down; check it first.")])
        _ = await AlertBriefing.brief(AITestSupport.critical, ai: ai)
        XCTAssertEqual(ai.status.state, .online)
        XCTAssertEqual(ai.status.activeBackend, .ollama)
    }

    @MainActor
    func testSettingsAndStatusViewsRender() {
        let ai = AITestSupport.makeAI()
        for view in [AnyView(NovaAISettingsView(ai: ai, footer: "footer")),
                     AnyView(NovaAIStatusIndicator(ai: ai, checksOnAppear: false))] {
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 600, height: 500)
            host.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(host.fittingSize.height, 0)
        }
    }

    @MainActor
    func testDetectorStartsWithoutBriefing() {
        XCTAssertFalse(AIAlertDetector.shared.isBriefing)
    }
}
