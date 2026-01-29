//
//  DashboardWebView.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import WebKit

/// WebView wrapper for displaying dashboards
struct DashboardWebView: NSViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool
    var onLoadComplete: ((CGImage?) -> Void)?
    var onLoadError: ((Error) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        // Enable developer extras for debugging
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }

        // Only load if URL changed
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: DashboardWebView

        init(_ parent: DashboardWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false

                // Inject dark mode CSS if enabled
                if DashboardManager.shared.settings.enableDarkMode {
                    self.injectDarkModeCSS(into: webView)
                }

                // Take screenshot for AI analysis after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + DashboardManager.shared.settings.pageLoadDelay) {
                    self.takeScreenshot(of: webView)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onLoadError?(error)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onLoadError?(error)
            }
        }

        private func injectDarkModeCSS(into webView: WKWebView) {
            let css = """
                body {
                    background-color: #1a1a1a !important;
                    color: #e0e0e0 !important;
                }
                * {
                    background-color: inherit !important;
                    color: inherit !important;
                    border-color: #444 !important;
                }
            """

            let js = """
                (function() {
                    var style = document.getElementById('dashboard-dark-mode');
                    if (!style) {
                        style = document.createElement('style');
                        style.id = 'dashboard-dark-mode';
                        document.head.appendChild(style);
                    }
                    style.textContent = `\(css)`;
                })();
            """

            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("Dark mode injection error: \(error)")
                }
            }
        }

        private func takeScreenshot(of webView: WKWebView) {
            let config = WKSnapshotConfiguration()

            webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let image = image,
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    return
                }

                DispatchQueue.main.async {
                    self?.parent.onLoadComplete?(cgImage)
                }
            }
        }
    }
}

/// WebView with scrolling animation support
struct ScrollingDashboardWebView: NSViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool
    @Binding var scrollProgress: CGFloat
    var scrollDuration: TimeInterval = 10
    var onLoadComplete: ((CGImage?) -> Void)?
    var onLoadError: ((Error) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }

        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ScrollingDashboardWebView
        private var scrollTimer: Timer?

        init(_ parent: ScrollingDashboardWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.scrollProgress = 0
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false

                // Inject dark mode if enabled
                if DashboardManager.shared.settings.enableDarkMode {
                    self.injectDarkModeCSS(into: webView)
                }

                // Start scrolling animation after page load delay
                DispatchQueue.main.asyncAfter(deadline: .now() + DashboardManager.shared.settings.pageLoadDelay) {
                    self.startScrollAnimation(webView)
                    self.takeScreenshot(of: webView)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onLoadError?(error)
            }
        }

        private func startScrollAnimation(_ webView: WKWebView) {
            scrollTimer?.invalidate()

            let duration = parent.scrollDuration
            let interval: TimeInterval = 0.05 // 20fps scroll updates
            let steps = Int(duration / interval)
            var currentStep = 0

            // Get scroll height first
            webView.evaluateJavaScript("document.body.scrollHeight - window.innerHeight") { [weak self] result, _ in
                guard let scrollHeight = result as? CGFloat, scrollHeight > 0 else {
                    self?.parent.scrollProgress = 1.0
                    return
                }

                self?.scrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                    currentStep += 1
                    let progress = min(CGFloat(currentStep) / CGFloat(steps), 1.0)

                    // Ease-in-out curve
                    let easedProgress = progress < 0.5
                        ? 2 * progress * progress
                        : 1 - pow(-2 * progress + 2, 2) / 2

                    let scrollPosition = scrollHeight * easedProgress

                    webView.evaluateJavaScript("window.scrollTo(0, \(scrollPosition))") { _, _ in }

                    DispatchQueue.main.async {
                        self?.parent.scrollProgress = progress
                    }

                    if currentStep >= steps {
                        timer.invalidate()
                    }
                }
            }
        }

        private func injectDarkModeCSS(into webView: WKWebView) {
            let css = """
                body { background-color: #1a1a1a !important; color: #e0e0e0 !important; }
                * { background-color: inherit !important; color: inherit !important; border-color: #444 !important; }
            """

            let js = """
                (function() {
                    var style = document.getElementById('dashboard-dark-mode');
                    if (!style) {
                        style = document.createElement('style');
                        style.id = 'dashboard-dark-mode';
                        document.head.appendChild(style);
                    }
                    style.textContent = `\(css)`;
                })();
            """

            webView.evaluateJavaScript(js) { _, _ in }
        }

        private func takeScreenshot(of webView: WKWebView) {
            webView.takeSnapshot(with: nil) { [weak self] image, _ in
                guard let image = image,
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    return
                }

                DispatchQueue.main.async {
                    self?.parent.onLoadComplete?(cgImage)
                }
            }
        }
    }
}
