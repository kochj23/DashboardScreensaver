//
//  AlertBriefing.swift
//  Dashboard Screensaver
//
//  AI alert briefing (NovaAIKit): when Vision flags a dashboard, a one- or two-sentence
//  note telling the on-call engineer what looks wrong and what to check first.
//  When AI is off, unreachable, or its reply is rejected, the deterministic Vision
//  summary is shown instead, so the alert overlay always has text.
//

import Foundation
import NovaAIKit

enum AlertBriefing {
    /// Longest briefing shown in the overlay.
    static let maxLength = 280
    /// OCR lines passed to the model (each capped at `maxLineLength`).
    static let maxLines = 8
    static let maxLineLength = 160

    static let systemPrompt = """
    You are an SRE assistant watching an operations dashboard on a wall display. \
    Write one or two short plain sentences (under 240 characters) telling the on-call engineer \
    what looks wrong and what to check first. Use only the facts given; never invent numbers, \
    hosts or services. No markdown, no lists, no greetings.
    """

    /// What Vision found on one dashboard.
    struct Input: Sendable, Equatable {
        var dashboardName: String
        var severity: AlertSeverity
        var redPercentage: Double
        var orangePercentage: Double
        var yellowPercentage: Double
        var keywords: [String]
        var alertLines: [String]
        var contentChanged: Bool

        init(dashboardName: String, result: DashboardAnalysisResult, alertLines: [String]) {
            self.init(dashboardName: dashboardName, severity: result.severity,
                      redPercentage: result.redPercentage, orangePercentage: result.orangePercentage,
                      yellowPercentage: result.yellowPercentage, keywords: result.detectedKeywords,
                      alertLines: alertLines, contentChanged: result.contentChanged)
        }

        init(dashboardName: String, severity: AlertSeverity, redPercentage: Double = 0,
             orangePercentage: Double = 0, yellowPercentage: Double = 0, keywords: [String] = [],
             alertLines: [String] = [], contentChanged: Bool = false) {
            self.dashboardName = dashboardName
            self.severity = severity
            self.redPercentage = redPercentage
            self.orangePercentage = orangePercentage
            self.yellowPercentage = yellowPercentage
            self.keywords = keywords
            self.alertLines = Array(alertLines.prefix(AlertBriefing.maxLines)).map { String($0.prefix(AlertBriefing.maxLineLength)) }
            self.contentChanged = contentChanged
        }

        /// The facts sent to the model; also the grounding source for the validator.
        var facts: String {
            var lines = [
                "Dashboard: \(dashboardName)",
                "Severity: \(severity.displayName)",
                "Screen colour: red \(Self.pct(redPercentage))%, orange \(Self.pct(orangePercentage))%, yellow \(Self.pct(yellowPercentage))%",
            ]
            if !keywords.isEmpty { lines.append("Alert words: \(keywords.joined(separator: ", "))") }
            if contentChanged { lines.append("The dashboard changed since the last look.") }
            if !alertLines.isEmpty {
                lines.append("Text on screen containing alert words:")
                lines += alertLines.map { "- \($0)" }
            }
            return lines.joined(separator: "\n")
        }

        static func pct(_ v: Double) -> String { String(format: "%.1f", max(0, min(100, v))) }
    }

    static func request(for input: Input) -> NovaAIRequest {
        NovaAIRequest(prompt: input.facts, system: systemPrompt, temperature: 0.2, maxTokens: 160)
    }

    /// Built-in briefing: deterministic, from the Vision result alone.
    static func fallback(for input: Input) -> String {
        var s = "\(input.severity.displayName) alert on \(input.dashboardName)"
        if !input.keywords.isEmpty { s += ": \(input.keywords.prefix(5).joined(separator: ", "))" }
        s += "."
        if let line = input.alertLines.first { s += " \"\(line.prefix(100))\"" }
        if input.contentChanged { s += " Content changed since the last rotation." }
        return String(s.prefix(maxLength))
    }

    /// Accepts a short plain reply whose numbers all appear in the facts; rejects the rest.
    static func validate(_ reply: String, input: Input) throws -> String {
        guard let cleaned = NovaAIText.clean(reply) else { throw NovaAIValidationError("empty reply") }
        let text = NovaAIText.plain(cleaned, max: 2_000)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard text.count >= 12 else { throw NovaAIValidationError("reply too short") }
        guard text.count <= maxLength else {
            throw NovaAIValidationError("reply longer than \(maxLength) characters")
        }
        guard NovaAIText.grounded(text, in: input.facts) else {
            throw NovaAIValidationError("reply contains numbers that are not in the dashboard facts")
        }
        return text
    }

    /// AI briefing or the built-in one. Never throws; honours the AI on/off switch.
    @MainActor
    static func brief(_ input: Input, ai: NovaAI) async -> NovaAIResult<String> {
        await ai.text(request(for: input),
                      validate: { try validate($0, input: input) },
                      fallback: { fallback(for: input) })
    }
}
