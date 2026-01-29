//
//  AppleTVManagerView.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct AppleTVManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var discovery = AppleTVDiscovery.shared
    @StateObject private var dashboardManager = DashboardManager.shared

    @State private var selectedDevice: AppleTVDevice?
    @State private var showConfiguration = false
    @State private var configurationError: String?
    @State private var isConfiguring = false

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    ModernHeader(text: "Apple TVs", size: .medium)

                    Spacer()

                    if discovery.isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(ModernColors.textSecondary)
                        }
                    }

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }
                .padding()

                Divider()

                // Actions bar
                HStack {
                    Button(action: { discovery.startScanning() }) {
                        Label("Scan Network", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
                    .disabled(discovery.isScanning)

                    if let lastScan = discovery.lastScanTime {
                        Text("Last scan: \(lastScan.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(ModernColors.textSecondary)
                    }

                    Spacer()

                    Text("\(discovery.discoveredDevices.count) devices found")
                        .font(.caption)
                        .foregroundColor(ModernColors.textSecondary)
                }
                .padding()

                Divider()

                // Device list
                if discovery.discoveredDevices.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(discovery.discoveredDevices) { device in
                            deviceRow(device)
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showConfiguration) {
            if let device = selectedDevice {
                configurationSheet(for: device)
            }
        }
        .onAppear {
            if discovery.discoveredDevices.isEmpty {
                discovery.startScanning()
            }
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "appletv")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("No Apple TVs Found")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            Text("Make sure DashboardTV is installed and running on your Apple TVs")
                .font(.caption)
                .foregroundColor(ModernColors.textTertiary)
                .multilineTextAlignment(.center)

            Button("Scan Network") {
                discovery.startScanning()
            }
            .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
            .disabled(discovery.isScanning)

            Spacer()
        }
        .padding()
    }

    private func deviceRow(_ device: AppleTVDevice) -> some View {
        HStack {
            Image(systemName: "appletv.fill")
                .font(.title2)
                .foregroundColor(device.isConfigured ? ModernColors.accentCyan : ModernColors.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                Text(device.ipAddress)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(ModernColors.textSecondary)

                if let groupId = device.assignedGroupId,
                   let group = dashboardManager.groups.first(where: { $0.id == groupId }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(group.color)
                            .frame(width: 8, height: 8)
                        Text(group.name)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }
            }

            Spacer()

            if device.isConfigured {
                Text("Configured")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(ModernColors.statusLow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ModernColors.statusLow.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(device.lastSeen.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(ModernColors.textTertiary)

            Button("Configure") {
                selectedDevice = device
                showConfiguration = true
            }
            .buttonStyle(ModernButtonStyle(style: .glass))

            Button(action: { discovery.removeDevice(device) }) {
                Image(systemName: "trash")
                    .foregroundColor(ModernColors.statusCritical)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func configurationSheet(for device: AppleTVDevice) -> some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 20) {
                HStack {
                    ModernHeader(text: "Configure \(device.name)", size: .medium)
                    Spacer()
                    Button(action: { showConfiguration = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }

                Divider()

                // Configuration options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Dashboard Group")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(ModernColors.textSecondary)

                    ForEach(dashboardManager.groups) { group in
                        Button(action: { configureDevice(device, with: group) }) {
                            HStack {
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading) {
                                    Text(group.name)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))

                                    Text("\(dashboardManager.dashboards.filter { $0.groupId == group.id && $0.isEnabled }.count) dashboards")
                                        .font(.caption)
                                        .foregroundColor(ModernColors.textSecondary)
                                }

                                Spacer()

                                if device.assignedGroupId == group.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ModernColors.statusLow)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    // All dashboards option
                    Button(action: { configureDeviceWithAll(device) }) {
                        HStack {
                            Image(systemName: "rectangle.grid.2x2")
                                .foregroundColor(ModernColors.accentCyan)

                            VStack(alignment: .leading) {
                                Text("All Dashboards")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))

                                Text("\(dashboardManager.dashboards.filter { $0.isEnabled }.count) dashboards")
                                    .font(.caption)
                                    .foregroundColor(ModernColors.textSecondary)
                            }

                            Spacer()

                            if device.assignedGroupId == nil && device.isConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ModernColors.statusLow)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                if let error = configurationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(ModernColors.statusCritical)
                }

                if isConfiguring {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Configuring...")
                            .font(.caption)
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(width: 450, height: 450)
    }

    // MARK: - Actions

    private func configureDevice(_ device: AppleTVDevice, with group: DashboardGroup) {
        isConfiguring = true
        configurationError = nil

        Task {
            do {
                try await discovery.sendGroupConfiguration(to: device, groupId: group.id)
                isConfiguring = false
                showConfiguration = false
            } catch {
                configurationError = error.localizedDescription
                isConfiguring = false
            }
        }
    }

    private func configureDeviceWithAll(_ device: AppleTVDevice) {
        isConfiguring = true
        configurationError = nil

        Task {
            do {
                let urls = dashboardManager.dashboards.filter { $0.isEnabled }.map { $0.url }
                try await discovery.sendConfiguration(to: device, urls: urls, settings: dashboardManager.settings)

                // Clear assigned group
                var updated = device
                updated.assignedGroupId = nil
                updated.isConfigured = true
                discovery.updateDevice(updated)

                isConfiguring = false
                showConfiguration = false
            } catch {
                configurationError = error.localizedDescription
                isConfiguring = false
            }
        }
    }
}

#Preview {
    AppleTVManagerView()
}
