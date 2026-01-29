//
//  TVContentView.swift
//  DashboardTV
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import Darwin

struct TVContentView: View {
    @EnvironmentObject var configServer: ConfigurationServer
    @EnvironmentObject var dashboardManager: TVDashboardManager

    @State private var showSettings = false
    @State private var dashboardImage: UIImage?
    @State private var isLoading = false

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

            // Loading overlay
            if isLoading {
                ProgressView()
                    .scaleEffect(2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
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
                loadCurrentDashboard()
            case .right:
                dashboardManager.nextDashboard()
                loadCurrentDashboard()
            default:
                break
            }
        }
        .onChange(of: dashboardManager.currentIndex) { _, _ in
            loadCurrentDashboard()
        }
        .onAppear {
            if !dashboardManager.urls.isEmpty {
                loadCurrentDashboard()
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
            if let image = dashboardImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 20) {
                    if let url = dashboardManager.currentURL {
                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(url.absoluteString)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }

                    Text("Dashboard \(dashboardManager.currentIndex + 1)")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan)
                }
                .padding(40)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
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

    // MARK: - Methods

    private func loadCurrentDashboard() {
        guard let url = dashboardManager.currentURL else { return }

        isLoading = true

        // Try to load a screenshot from a screenshot service
        // Format: https://your-server/screenshot?url=<dashboard-url>
        // For now, we'll just display the URL info since tvOS can't render web pages directly

        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
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

#Preview {
    TVContentView()
        .environmentObject(ConfigurationServer.shared)
        .environmentObject(TVDashboardManager.shared)
}
