//
//  TVContentView.swift
//  DashboardTV
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if os(tvOS)
import TVUIKit
#endif

struct TVContentView: View {
    @EnvironmentObject var configServer: ConfigurationServer
    @EnvironmentObject var dashboardManager: TVDashboardManager

    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.14),
                    Color(red: 0.12, green: 0.12, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if dashboardManager.urls.isEmpty {
                emptyStateView
            } else {
                dashboardView
            }

            // Status overlay
            VStack {
                HStack {
                    statusIndicator
                    Spacer()
                    dashboardCounter
                }
                .padding()

                Spacer()
            }
        }
        .focusable()
        .onPlayPauseCommand {
            if dashboardManager.isRotating {
                dashboardManager.stopRotation()
            } else {
                dashboardManager.startRotation()
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                dashboardManager.previousDashboard()
            case .right:
                dashboardManager.nextDashboard()
            default:
                break
            }
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Image(systemName: "display")
                .font(.system(size: 80))
                .foregroundColor(.cyan.opacity(0.6))

            Text("DashboardTV")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Configure from Dashboard Screensaver on your Mac")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(configServer.isRunning ? .green : .orange)
                    Text(configServer.isRunning ? "Ready for configuration" : "Starting...")
                        .foregroundColor(.white.opacity(0.7))
                }

                if let ip = getIPAddress() {
                    Text("IP Address: \(ip)")
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
        .padding(60)
    }

    private var dashboardView: some View {
        Group {
            if let url = dashboardManager.currentURL {
                TVWebView(url: url, enableDarkMode: dashboardManager.settings.enableDarkMode)
            }
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dashboardManager.isRotating ? Color.green : Color.orange)
                .frame(width: 12, height: 12)

            Text(dashboardManager.isRotating ? "Rotating" : "Paused")
                .font(.system(size: 18, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
    }

    private var dashboardCounter: some View {
        Text("\(dashboardManager.currentIndex + 1) / \(dashboardManager.urls.count)")
            .font(.system(size: 18, design: .rounded))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(20)
    }

    private func getIPAddress() -> String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }
}

// MARK: - TV WebView

import WebKit

struct TVWebView: UIViewRepresentable {
    let url: URL
    let enableDarkMode: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: TVWebView

        init(_ parent: TVWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if parent.enableDarkMode {
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
        }
    }
}

#Preview {
    TVContentView()
        .environmentObject(ConfigurationServer.shared)
        .environmentObject(TVDashboardManager.shared)
}
