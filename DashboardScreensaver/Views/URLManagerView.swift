//
//  URLManagerView.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct URLManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dashboardManager = DashboardManager.shared

    @State private var newURL = ""
    @State private var selectedGroupId: UUID?
    @State private var showImportPicker = false
    @State private var showRemoteImport = false
    @State private var remoteConfigURL = ""
    @State private var importError: String?
    @State private var showGroupManager = false

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    ModernHeader(text: "Dashboard URLs", size: .medium)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }
                .padding()

                Divider()

                // Add URL section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("https://example.com/dashboard", text: $newURL)
                            .textFieldStyle(.roundedBorder)

                        Picker("Group", selection: $selectedGroupId) {
                            Text("No Group").tag(nil as UUID?)
                            ForEach(dashboardManager.groups) { group in
                                Text(group.name).tag(group.id as UUID?)
                            }
                        }
                        .frame(width: 150)

                        Button("Add") {
                            addURL()
                        }
                        .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
                        .disabled(newURL.isEmpty || !isValidURL(newURL))
                    }

                    HStack {
                        Button("Import CSV") {
                            showImportPicker = true
                        }
                        .buttonStyle(ModernButtonStyle(style: .glass))

                        Button("Import Remote") {
                            showRemoteImport = true
                        }
                        .buttonStyle(ModernButtonStyle(style: .glass))

                        Button("Manage Groups") {
                            showGroupManager = true
                        }
                        .buttonStyle(ModernButtonStyle(style: .glass))

                        Spacer()

                        if !dashboardManager.dashboards.isEmpty {
                            Button("Clear All") {
                                dashboardManager.dashboards.removeAll()
                            }
                            .buttonStyle(ModernButtonStyle(style: .destructive))
                        }
                    }

                    if let error = importError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ModernColors.statusCritical)
                    }
                }
                .padding()

                Divider()

                // URL List
                List {
                    ForEach(dashboardManager.groups) { group in
                        Section(header: groupHeader(group)) {
                            ForEach(dashboardManager.dashboards.filter { $0.groupId == group.id }) { dashboard in
                                dashboardRow(dashboard)
                            }
                        }
                    }

                    // Ungrouped
                    let ungrouped = dashboardManager.dashboards.filter { $0.groupId == nil }
                    if !ungrouped.isEmpty {
                        Section(header: Text("Ungrouped")) {
                            ForEach(ungrouped) { dashboard in
                                dashboardRow(dashboard)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 700, height: 600)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            onCompletion: handleFileImport
        )
        .sheet(isPresented: $showRemoteImport) {
            remoteImportSheet
        }
        .sheet(isPresented: $showGroupManager) {
            GroupManagerView()
        }
    }

    // MARK: - Views

    private func groupHeader(_ group: DashboardGroup) -> some View {
        HStack {
            Circle()
                .fill(group.color)
                .frame(width: 10, height: 10)
            Text(group.name)
            Spacer()
            Text("\(dashboardManager.dashboards.filter { $0.groupId == group.id }.count) URLs")
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    private func dashboardRow(_ dashboard: DashboardURL) -> some View {
        HStack {
            StatusIndicator(
                isActive: dashboard.healthStatus == .healthy,
                activeColor: ModernColors.healthColor(dashboard.healthStatus)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(dashboard.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                Text(dashboard.url)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(ModernColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if dashboard.healthStatus != .unknown {
                Text(String(format: "%.0f%%", dashboard.successRate))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Toggle("", isOn: Binding(
                get: { dashboard.isEnabled },
                set: { newValue in
                    var updated = dashboard
                    updated.isEnabled = newValue
                    dashboardManager.updateDashboard(updated)
                }
            ))
            .labelsHidden()

            Button(action: { dashboardManager.removeDashboard(dashboard) }) {
                Image(systemName: "trash")
                    .foregroundColor(ModernColors.statusCritical)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var remoteImportSheet: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 20) {
                ModernHeader(text: "Import from URL", size: .medium)

                TextField("https://example.com/config.txt", text: $remoteConfigURL)
                    .textFieldStyle(.roundedBorder)

                Text("Enter a URL to a text file with one dashboard URL per line")
                    .font(.caption)
                    .foregroundColor(ModernColors.textSecondary)

                HStack {
                    Button("Cancel") {
                        showRemoteImport = false
                    }
                    .buttonStyle(ModernButtonStyle(style: .glass))

                    Button("Import") {
                        importFromRemote()
                    }
                    .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
                    .disabled(remoteConfigURL.isEmpty || !isValidURL(remoteConfigURL))
                }
            }
            .padding()
            .glassCard()
        }
        .frame(width: 400, height: 200)
    }

    // MARK: - Actions

    private func addURL() {
        guard isValidURL(newURL) else { return }
        dashboardManager.addDashboard(url: newURL, groupId: selectedGroupId)
        newURL = ""
    }

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        importError = nil

        switch result {
        case .success(let url):
            do {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                try dashboardManager.importFromCSV(url)
            } catch {
                importError = "Failed to import: \(error.localizedDescription)"
            }
        case .failure(let error):
            importError = "Failed to open file: \(error.localizedDescription)"
        }
    }

    private func importFromRemote() {
        guard let url = URL(string: remoteConfigURL) else { return }

        Task {
            do {
                try await dashboardManager.importFromRemoteConfig(url)
                showRemoteImport = false
                remoteConfigURL = ""
            } catch {
                importError = "Failed to import: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Group Manager

struct GroupManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dashboardManager = DashboardManager.shared

    @State private var newGroupName = ""
    @State private var newGroupColor = "#4DD9F3"

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                HStack {
                    ModernHeader(text: "Manage Groups", size: .medium)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }
                .padding()

                Divider()

                // Add group
                HStack {
                    TextField("Group Name", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)

                    ColorPicker("", selection: Binding(
                        get: { Color(hex: newGroupColor) ?? .cyan },
                        set: { newGroupColor = $0.hexString }
                    ))
                    .labelsHidden()

                    Button("Add Group") {
                        addGroup()
                    }
                    .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentCyan))
                    .disabled(newGroupName.isEmpty)
                }
                .padding()

                Divider()

                // Groups list
                List {
                    ForEach(dashboardManager.groups) { group in
                        HStack {
                            Circle()
                                .fill(group.color)
                                .frame(width: 16, height: 16)

                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))

                                if !group.description.isEmpty {
                                    Text(group.description)
                                        .font(.caption)
                                        .foregroundColor(ModernColors.textSecondary)
                                }
                            }

                            Spacer()

                            Text("\(group.urlIds.count) URLs")
                                .font(.caption)
                                .foregroundColor(ModernColors.textSecondary)

                            Toggle("", isOn: Binding(
                                get: { group.isEnabled },
                                set: { newValue in
                                    var updated = group
                                    updated.isEnabled = newValue
                                    dashboardManager.updateGroup(updated)
                                }
                            ))
                            .labelsHidden()

                            Button(action: { dashboardManager.removeGroup(group) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(ModernColors.statusCritical)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.inset)

                if dashboardManager.groups.isEmpty {
                    Button("Create Default Groups") {
                        dashboardManager.createDefaultGroups()
                    }
                    .buttonStyle(ModernButtonStyle(style: .outlined, color: ModernColors.accentCyan))
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 400)
    }

    private func addGroup() {
        let group = DashboardGroup(
            name: newGroupName,
            colorHex: newGroupColor
        )
        dashboardManager.addGroup(group)
        newGroupName = ""
    }
}

#Preview {
    URLManagerView()
}
