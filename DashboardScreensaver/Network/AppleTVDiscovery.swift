//
//  AppleTVDiscovery.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  Discovers Apple TVs running DashboardTV on the local network
//

import Foundation
import Network
import Combine

/// Discovers Apple TVs running DashboardTV via Bonjour/mDNS
@MainActor
class AppleTVDiscovery: ObservableObject {
    static let shared = AppleTVDiscovery()

    // MARK: - Published Properties

    @Published var discoveredDevices: [AppleTVDevice] = []
    @Published var isScanning: Bool = false
    @Published var lastScanTime: Date?

    // MARK: - Private Properties

    private var browser: NWBrowser?
    private let serviceType = "_dashboardtv._tcp"
    private let serviceDomain = "local."
    private var scanTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadSavedDevices()
    }

    // MARK: - Discovery

    func startScanning() {
        guard !isScanning else { return }
        isScanning = true

        // Create browser for DashboardTV service
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: serviceDomain), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("AppleTVDiscovery: Browser ready")
                case .failed(let error):
                    print("AppleTVDiscovery: Browser failed: \(error)")
                    self?.isScanning = false
                case .cancelled:
                    self?.isScanning = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }

        browser?.start(queue: .main)
        lastScanTime = Date()

        // Also scan by IP range as fallback
        scanIPRange()

        // Auto-stop after 30 seconds
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopScanning()
            }
        }
    }

    func stopScanning() {
        browser?.cancel()
        browser = nil
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                resolveService(name: name, type: type, domain: domain)
            default:
                break
            }
        }
    }

    private func resolveService(name: String, type: String, domain: String) {
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let parameters = NWParameters.tcp

        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    Task { @MainActor in
                        let ipAddress: String
                        switch host {
                        case .ipv4(let addr):
                            ipAddress = "\(addr)"
                        case .ipv6(let addr):
                            ipAddress = "\(addr)"
                        case .name(let hostname, _):
                            ipAddress = hostname
                        @unknown default:
                            ipAddress = "unknown"
                        }

                        self?.addDiscoveredDevice(
                            name: name,
                            ipAddress: ipAddress,
                            port: Int(port.rawValue)
                        )
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: .main)

        // Timeout after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if connection.state != .ready {
                connection.cancel()
            }
        }
    }

    // MARK: - IP Range Scanning

    private func scanIPRange() {
        // Get local IP to determine subnet
        guard let localIP = getLocalIPAddress() else { return }

        let components = localIP.split(separator: ".").map { String($0) }
        guard components.count == 4 else { return }

        let subnet = "\(components[0]).\(components[1]).\(components[2])"

        // Scan common IP ranges (1-254)
        for i in 1...254 {
            let ip = "\(subnet).\(i)"
            checkForDashboardTV(at: ip)
        }
    }

    private func checkForDashboardTV(at ipAddress: String, port: Int = 8080) {
        guard let url = URL(string: "http://\(ipAddress):\(port)/api/info") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard error == nil,
                  let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            // Try to parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let deviceName = json["name"] as? String,
               let isDashboardTV = json["isDashboardTV"] as? Bool,
               isDashboardTV {
                Task { @MainActor in
                    self?.addDiscoveredDevice(name: deviceName, ipAddress: ipAddress, port: port)
                }
            }
        }.resume()
    }

    private func getLocalIPAddress() -> String? {
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

                // Skip loopback
                if name == "en0" || name == "en1" {
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

    // MARK: - Device Management

    private func addDiscoveredDevice(name: String, ipAddress: String, port: Int) {
        // Check if already exists
        if let existingIndex = discoveredDevices.firstIndex(where: { $0.ipAddress == ipAddress }) {
            // Update existing
            discoveredDevices[existingIndex].name = name
            discoveredDevices[existingIndex].port = port
            discoveredDevices[existingIndex].lastSeen = Date()
        } else {
            // Add new
            let device = AppleTVDevice(
                name: name,
                ipAddress: ipAddress,
                port: port
            )
            discoveredDevices.append(device)
        }

        saveDevices()
    }

    func removeDevice(_ device: AppleTVDevice) {
        discoveredDevices.removeAll { $0.id == device.id }
        saveDevices()
    }

    func updateDevice(_ device: AppleTVDevice) {
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
            saveDevices()
        }
    }

    // MARK: - Remote Configuration

    func sendConfiguration(to device: AppleTVDevice, urls: [String], settings: DashboardSettings) async throws {
        guard let baseURL = device.baseURL else {
            throw NSError(domain: "AppleTVDiscovery", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid device URL"])
        }

        let configURL = baseURL.appendingPathComponent("api/configure")

        var request = URLRequest(url: configURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let config: [String: Any] = [
            "urls": urls,
            "rotationInterval": settings.rotationInterval,
            "enableDarkMode": settings.enableDarkMode,
            "enableAIDetection": settings.enableAIDetection,
            "alertThreshold": settings.alertThreshold
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: config)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppleTVDiscovery", code: 2, userInfo: [NSLocalizedDescriptionKey: "Configuration failed"])
        }

        // Mark as configured
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index].isConfigured = true
            saveDevices()
        }
    }

    func sendGroupConfiguration(to device: AppleTVDevice, groupId: UUID) async throws {
        let urls = DashboardManager.shared.dashboards
            .filter { $0.groupId == groupId && $0.isEnabled }
            .map { $0.url }

        try await sendConfiguration(to: device, urls: urls, settings: DashboardManager.shared.settings)

        // Update assigned group
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index].assignedGroupId = groupId
            saveDevices()
        }
    }

    // MARK: - Persistence

    private func loadSavedDevices() {
        if let data = UserDefaults.standard.data(forKey: "DashboardScreensaver.appleTVDevices"),
           let decoded = try? JSONDecoder().decode([AppleTVDevice].self, from: data) {
            discoveredDevices = decoded
        }
    }

    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(discoveredDevices) {
            UserDefaults.standard.set(encoded, forKey: "DashboardScreensaver.appleTVDevices")
        }
    }
}
