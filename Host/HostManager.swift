//
//  HostManager.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Manages the host service for sharing this Mac's screen.
//

import Foundation

/// Manages the MirageHostService for screen sharing.
@Observable
@MainActor
final class HostManager {
    private var hostService: MirageHostService?
    private let delegate = HostDelegate()

    var isRunning: Bool = false
    var connectedClients: [MirageConnectedClient] = []
    var activeStreams: [MirageStreamSession] = []
    var availableWindows: [MirageWindow] = []
    var currentError: String?

    // MARK: - Lifecycle

    func start(
        hostName: String,
        qualityPreset: MirageQualityPreset,
        enablePeerToPeer: Bool,
        allowRemoteControl: Bool
    ) async throws {
        guard hostService == nil else {
            MirageLogger.host("Host already running")
            return
        }

        let encoderConfig = qualityPreset.encoderConfiguration(for: 60)
        let networkConfig = MirageNetworkConfiguration(
            enablePeerToPeer: enablePeerToPeer
        )

        let service = MirageHostService(
            hostName: hostName,
            encoderConfiguration: encoderConfig,
            networkConfiguration: networkConfig
        )

        service.delegate = delegate
        service.remoteUnlockEnabled = allowRemoteControl

        // Set up delegate callbacks
        delegate.onClientConnected = { [weak self] client in
            self?.handleClientConnected(client)
        }
        delegate.onClientDisconnected = { [weak self] client in
            self?.handleClientDisconnected(client)
        }
        delegate.onStreamRequest = { [weak self] client, window in
            self?.handleStreamRequest(client: client, window: window) ?? false
        }
        delegate.onDesktopStreamRequest = { [weak self] client in
            self?.handleDesktopStreamRequest(client: client) ?? false
        }
        delegate.onError = { [weak self] error in
            self?.handleError(error)
        }

        try await service.start()

        hostService = service
        isRunning = true
        currentError = nil

        // Start observing service changes
        Task { @MainActor [weak self] in
            await self?.observeServiceChanges(service)
        }
    }

    func stop() async {
        guard let service = hostService else { return }

        await service.stop()
        hostService = nil
        isRunning = false
        connectedClients.removeAll()
        activeStreams.removeAll()
    }

    func refreshWindows() async {
        guard let service = hostService else { return }
        try? await service.refreshWindows()
    }

    // MARK: - Observation

    private func observeServiceChanges(_ service: MirageHostService) async {
        withObservationTracking {
            _ = service.connectedClients
            _ = service.activeStreams
            _ = service.availableWindows
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.connectedClients = service.connectedClients
                self?.activeStreams = service.activeStreams
                self?.availableWindows = service.availableWindows

                // Continue observing
                await self?.observeServiceChanges(service)
            }
        }
    }

    // MARK: - Delegate Handlers

    private func handleClientConnected(_ client: MirageConnectedClient) {
        MirageLogger.host("Client connected: \(client.name)")
        connectedClients.append(client)
    }

    private func handleClientDisconnected(_ client: MirageConnectedClient) {
        MirageLogger.host("Client disconnected: \(client.name)")
        connectedClients.removeAll { $0.id == client.id }
    }

    private func handleStreamRequest(client: MirageConnectedClient, window: MirageWindow) -> Bool {
        MirageLogger.host("Stream request from \(client.name) for window: \(window.title ?? "Untitled")")
        return true
    }

    private func handleDesktopStreamRequest(client: MirageConnectedClient) -> Bool {
        MirageLogger.host("Desktop stream request from \(client.name)")
        return true
    }

    private func handleError(_ error: Error) {
        currentError = error.localizedDescription
        MirageLogger.error(.host, "Host error: \(error)")
    }
}

// MARK: - Host Delegate

private final class HostDelegate: NSObject, MirageHostDelegate, @unchecked Sendable {
    var onClientConnected: ((MirageConnectedClient) -> Void)?
    var onClientDisconnected: ((MirageConnectedClient) -> Void)?
    var onStreamRequest: ((MirageConnectedClient, MirageWindow) -> Bool)?
    var onDesktopStreamRequest: ((MirageConnectedClient) -> Bool)?
    var onError: ((Error) -> Void)?

    func hostService(
        _: MirageHostService,
        didConnectClient client: MirageConnectedClient
    ) {
        onClientConnected?(client)
    }

    func hostService(
        _: MirageHostService,
        didDisconnectClient client: MirageConnectedClient
    ) {
        onClientDisconnected?(client)
    }

    func hostService(
        _: MirageHostService,
        shouldAllowClient client: MirageConnectedClient,
        toStreamWindow window: MirageWindow
    ) -> Bool {
        onStreamRequest?(client, window) ?? false
    }

    func hostService(
        _: MirageHostService,
        didEncounterError error: Error
    ) {
        onError?(error)
    }
}
