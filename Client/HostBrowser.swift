//
//  HostBrowser.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Bonjour browser for discovering Mirage hosts on the network.
//

import Foundation
import Network

/// Browser for discovering Mirage hosts via Bonjour.
@Observable
@MainActor
final class MirageHostBrowser {
    let networkConfiguration: MirageNetworkConfiguration

    var onHostsUpdated: (([MirageHost]) -> Void)?

    private var browser: BonjourBrowser?
    private var hosts: [MirageHost] = []
    private var deviceID: UUID?

    init(networkConfiguration: MirageNetworkConfiguration = .default) {
        self.networkConfiguration = networkConfiguration

        // Load device ID for filtering self
        if let savedIDString = UserDefaults.standard.string(forKey: "com.mirage.client.deviceID"),
           let savedID = UUID(uuidString: savedIDString) {
            deviceID = savedID
        }
    }

    func start() {
        browser = BonjourBrowser(
            serviceType: networkConfiguration.serviceType,
            enablePeerToPeer: networkConfiguration.enablePeerToPeer
        )

        browser?.onHostsUpdated = { [weak self] hosts in
            guard let self else { return }

            // Filter out self
            let filteredHosts = hosts.filter { host in
                guard let deviceID = self.deviceID else { return true }
                return host.capabilities.deviceID != deviceID
            }

            self.hosts = filteredHosts
            self.onHostsUpdated?(filteredHosts)
        }

        browser?.start()
    }

    func stop() {
        browser?.stop()
        browser = nil
        hosts.removeAll()
    }
}

// MARK: - Bonjour Browser Wrapper

/// Wrapper around MirageKit's BonjourBrowser for type safety.
@MainActor
private final class BonjourBrowser: @unchecked Sendable {
    let serviceType: String
    let enablePeerToPeer: Bool

    var onHostsUpdated: (([MirageHost]) -> Void)?

    private var nwBrowser: NWBrowser?
    private var discoveredEndpoints: [NWEndpoint: MirageHost] = [:]

    init(serviceType: String, enablePeerToPeer: Bool) {
        self.serviceType = serviceType
        self.enablePeerToPeer = enablePeerToPeer
    }

    func start() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = enablePeerToPeer

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { state in
            Task { @MainActor in
                switch state {
                case .failed(let error):
                    MirageLogger.error(.client, "Browser failed: \(error)")
                case .ready:
                    MirageLogger.client("Browser ready")
                case .cancelled:
                    MirageLogger.client("Browser cancelled")
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }

        browser.start(queue: .main)
        nwBrowser = browser
    }

    func stop() {
        nwBrowser?.cancel()
        nwBrowser = nil
        discoveredEndpoints.removeAll()
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        var hosts: [MirageHost] = []

        for result in results {
            guard case let .service(name, type, domain, interface) = result.endpoint else {
                continue
            }

            // TXT records are accessed via the result metadata
            // For now, use default capabilities
            var txtDict: [String: String] = [:]
            
            // TODO: Access TXT record data from NWBrowser.Result metadata if needed
            _ = interface
            _ = type
            _ = domain

            let capabilities = MirageHostCapabilities.from(txtRecord: txtDict)

            let host = MirageHost(
                id: capabilities.deviceID ?? UUID(),
                name: name,
                deviceType: .mac,
                endpoint: result.endpoint,
                capabilities: capabilities
            )

            hosts.append(host)
        }

        onHostsUpdated?(hosts)
    }


}
