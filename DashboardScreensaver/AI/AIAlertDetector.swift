//
//  AIAlertDetector.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  Uses Vision framework for intelligent dashboard alert detection
//

import Foundation
import Vision
import AppKit
import Combine
import UserNotifications

/// Detects alerts in dashboard screenshots using Vision framework
@MainActor
class AIAlertDetector: ObservableObject {
    static let shared = AIAlertDetector()

    // MARK: - Published Properties

    @Published var lastAnalysisResult: DashboardAnalysisResult?
    @Published var isAnalyzing: Bool = false

    // MARK: - Private Properties

    private var screenshotCache: [UUID: CGImage] = [:]
    private let maxCacheSize = 50

    // Alert keywords to detect via OCR
    private let alertKeywords = [
        "critical", "error", "failed", "failure", "down",
        "alert", "warning", "danger", "urgent", "emergency",
        "outage", "offline", "unhealthy", "degraded", "incident"
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Analysis

    func analyzeImage(_ image: CGImage, for dashboardId: UUID) async -> DashboardAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Analyze colors
        let colorAnalysis = analyzeColors(in: image)

        // Detect text via OCR
        let detectedKeywords = await detectAlertText(in: image)

        // Check for content changes
        let contentChanged = checkForContentChange(image, dashboardId: dashboardId)

        // Cache screenshot for future comparison
        cacheScreenshot(image, for: dashboardId)

        // Determine severity
        let severity = calculateSeverity(
            redPercentage: colorAnalysis.red,
            orangePercentage: colorAnalysis.orange,
            yellowPercentage: colorAnalysis.yellow,
            keywords: detectedKeywords
        )

        let result = DashboardAnalysisResult(
            dashboardId: dashboardId,
            timestamp: Date(),
            severity: severity,
            redPercentage: colorAnalysis.red,
            orangePercentage: colorAnalysis.orange,
            yellowPercentage: colorAnalysis.yellow,
            detectedKeywords: detectedKeywords,
            contentChanged: contentChanged
        )

        lastAnalysisResult = result

        // Send notification if critical
        if severity >= .high && DashboardManager.shared.settings.notifyOnAlert {
            sendAlertNotification(result)
        }

        // Pause rotation if critical and setting enabled
        if severity == .critical && DashboardManager.shared.settings.pauseOnCritical {
            DashboardManager.shared.pauseRotation()
        }

        return result
    }

    // MARK: - Color Analysis

    private func analyzeColors(in image: CGImage) -> (red: Double, orange: Double, yellow: Double) {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0, 0, 0)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return (0, 0, 0)
        }

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        var redCount = 0
        var orangeCount = 0
        var yellowCount = 0
        var totalPixels = 0

        // Sample every 4th pixel for performance
        let step = 4
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)

                let r = Double(buffer[offset]) / 255.0
                let g = Double(buffer[offset + 1]) / 255.0
                let b = Double(buffer[offset + 2]) / 255.0

                totalPixels += 1

                // Red detection: high red, low green/blue
                if r > 0.6 && g < 0.4 && b < 0.4 {
                    redCount += 1
                }
                // Orange detection: high red, medium green, low blue
                else if r > 0.8 && g > 0.3 && g < 0.7 && b < 0.3 {
                    orangeCount += 1
                }
                // Yellow detection: high red, high green, low blue
                else if r > 0.7 && g > 0.7 && b < 0.4 {
                    yellowCount += 1
                }
            }
        }

        let redPercentage = Double(redCount) / Double(totalPixels) * 100
        let orangePercentage = Double(orangeCount) / Double(totalPixels) * 100
        let yellowPercentage = Double(yellowCount) / Double(totalPixels) * 100

        return (redPercentage, orangePercentage, yellowPercentage)
    }

    // MARK: - OCR Text Detection

    private func detectAlertText(in image: CGImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var foundKeywords: [String] = []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }

                    let text = candidate.string.lowercased()

                    for keyword in self.alertKeywords {
                        if text.contains(keyword) && !foundKeywords.contains(keyword) {
                            foundKeywords.append(keyword)
                        }
                    }
                }

                continuation.resume(returning: foundKeywords)
            }

            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Content Change Detection

    private func checkForContentChange(_ image: CGImage, dashboardId: UUID) -> Bool {
        guard let previousImage = screenshotCache[dashboardId] else {
            return false
        }

        // Compare images by sampling pixels
        let width = min(image.width, previousImage.width)
        let height = min(image.height, previousImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard let context1 = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
              let context2 = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return false
        }

        context1.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context2.draw(previousImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data1 = context1.data,
              let data2 = context2.data else {
            return false
        }

        let buffer1 = data1.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        let buffer2 = data2.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        var differentPixels = 0
        var totalSampled = 0

        // Sample every 10th pixel
        let step = 10
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)

                let r1 = Double(buffer1[offset]) / 255.0
                let g1 = Double(buffer1[offset + 1]) / 255.0
                let b1 = Double(buffer1[offset + 2]) / 255.0

                let r2 = Double(buffer2[offset]) / 255.0
                let g2 = Double(buffer2[offset + 1]) / 255.0
                let b2 = Double(buffer2[offset + 2]) / 255.0

                let diff = abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)

                totalSampled += 1
                if diff > 0.3 {
                    differentPixels += 1
                }
            }
        }

        // Consider changed if more than 5% of pixels differ significantly
        let changePercentage = Double(differentPixels) / Double(totalSampled)
        return changePercentage > 0.05
    }

    // MARK: - Severity Calculation

    private func calculateSeverity(
        redPercentage: Double,
        orangePercentage: Double,
        yellowPercentage: Double,
        keywords: [String]
    ) -> AlertSeverity {
        let threshold = DashboardManager.shared.settings.alertThreshold

        // Critical keywords
        let criticalKeywords = ["critical", "emergency", "outage", "down"]
        if keywords.contains(where: { criticalKeywords.contains($0) }) {
            return .critical
        }

        // High keywords
        let highKeywords = ["error", "failed", "failure", "danger"]
        if keywords.contains(where: { highKeywords.contains($0) }) {
            return .high
        }

        // Color-based severity
        if redPercentage >= threshold || orangePercentage >= threshold {
            return .critical
        }

        if redPercentage >= threshold * 0.6 {
            return .high
        }

        if redPercentage >= threshold * 0.4 || orangePercentage >= threshold * 0.6 {
            return .medium
        }

        if yellowPercentage >= threshold || orangePercentage >= threshold * 0.4 {
            return .low
        }

        // Medium keywords
        let mediumKeywords = ["warning", "degraded", "incident"]
        if keywords.contains(where: { mediumKeywords.contains($0) }) {
            return .medium
        }

        // Low keywords
        if !keywords.isEmpty {
            return .low
        }

        return .none
    }

    // MARK: - Screenshot Cache

    private func cacheScreenshot(_ image: CGImage, for dashboardId: UUID) {
        // Limit cache size
        if screenshotCache.count >= maxCacheSize {
            // Remove oldest entries (arbitrary in this simple implementation)
            let keysToRemove = Array(screenshotCache.keys.prefix(10))
            for key in keysToRemove {
                screenshotCache.removeValue(forKey: key)
            }
        }

        screenshotCache[dashboardId] = image
    }

    func clearCache() {
        screenshotCache.removeAll()
    }

    // MARK: - Notifications

    private func sendAlertNotification(_ result: DashboardAnalysisResult) {
        let content = UNMutableNotificationContent()
        content.title = "\(result.severity.displayName) Alert Detected"
        content.body = result.summaryText

        if result.severity == .critical {
            content.sound = .defaultCritical
        } else {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "alert-\(result.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
