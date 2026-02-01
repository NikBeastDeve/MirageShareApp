//
//  ClientManager.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Manages the client service for viewing remote Mac screens.
//

import Foundation
import Observation

/// Manages the MirageClientService for connecting to remote hosts.
@Observable
@MainActor
final class ClientManager {
    let clientService: MirageClientService
    let sessionStore: MirageClientSessionStore
    private let delegate = ClientDelegate()

    var isConnected: Bool = false
    var connectedHost: MirageHost?
    var availableWindows: [MirageWindow] = []
    var activeSessions: [MirageStreamSessionState] = []
    var currentError: String?
    var discoveredHosts: [MirageHost] = []

    private var browser: MirageHostBrowser?

    // MARK: - Initialization

    init() {
        sessionStore = MirageClientSessionStore()
        clientService = MirageClientService(sessionStore: sessionStore)

        // Set up delegate
        clientService.delegate = delegate
        delegate.onWindowListUpdate = { [weak self] windows in
            self?.handleWindowListUpdate(windows)
        }
        delegate.onDisconnect = { [weak self] reason in
            self?.handleDisconnect(reason: reason)
        }
        delegate.onError = { [weak self] error in
            self?.handleError(error)
        }
        delegate.onStreamStarted = { [weak self] session in
            self?.handleStreamStarted(session)
        }
    }

    // MARK: - Discovery

    func startDiscovery(enablePeerToPeer: Bool) {
        browser = MirageHostBrowser(
            networkConfiguration: MirageNetworkConfiguration(
                enablePeerToPeer: enablePeerToPeer
            )
        )

        browser?.onHostsUpdated = { [weak self] hosts in
            self?.discoveredHosts = hosts
        }

        browser?.start()
    }

    func stopDiscovery() {
        browser?.stop()
        browser = nil
        discoveredHosts.removeAll()
    }

    // MARK: - Connection

    func connect(to host: MirageHost, qualityPreset: MirageQualityPreset) async throws {
        guard clientService.connectionState.canConnect else {
            throw ClientError.alreadyConnected
        }

        try await clientService.connect(to: host)

        connectedHost = host
        isConnected = true
        currentError = nil

        // Request window list
        try await clientService.requestWindowList()
    }

    func disconnect() async {
        await clientService.disconnect()

        isConnected = false
        connectedHost = nil
        availableWindows.removeAll()
        activeSessions.removeAll()
    }

    // MARK: - Streaming

    func startWindowStream(_ window: MirageWindow, qualityPreset: MirageQualityPreset) async throws {
        let _ = try await clientService.startViewing(
            window: window,
            quality: qualityPreset
        )
        MirageLogger.client("Started window stream for window \(window.id)")
    }

    func startDesktopStream(mode: MirageDesktopStreamMode, qualityPreset: MirageQualityPreset) async throws {
        try await clientService.startDesktopStream(
            quality: qualityPreset,
            mode: mode
        )
        MirageLogger.client("Started desktop stream")
    }

    func stopStream(_ session: MirageStreamSessionState) async {
        // Remove session from store (the stream will be cleaned up by the framework)
        sessionStore.removeSession(session.id)
        activeSessions.removeAll { $0.id == session.id }
    }

    // MARK: - Handlers

    private func handleWindowListUpdate(_ windows: [MirageWindow]) {
        availableWindows = windows
    }

    private func handleDisconnect(reason: String) {
        MirageLogger.client("Disconnected: \(reason)")
        isConnected = false
        connectedHost = nil
        availableWindows.removeAll()
        activeSessions.removeAll()
    }

    private func handleError(_ error: Error) {
        currentError = error.localizedDescription
        MirageLogger.error(.client, "Client error: \(error)")
    }

    private func handleStreamStarted(_ session: MirageStreamSessionState) {
        if !activeSessions.contains(where: { $0.id == session.id }) {
            activeSessions.append(session)
        }
    }
}

// MARK: - Errors

enum ClientError: Error {
    case alreadyConnected
    case notConnected

    var localizedDescription: String {
        switch self {
        case .alreadyConnected: "Already connected to a host"
        case .notConnected: "Not connected to any host"
        }
    }
}

// MARK: - Client Delegate

private final class ClientDelegate: NSObject, MirageClientDelegate, @unchecked Sendable {
    var onWindowListUpdate: (([MirageWindow]) -> Void)?
    var onDisconnect: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    var onStreamStarted: ((MirageStreamSessionState) -> Void)?

    func clientService(
        _: MirageClientService,
        didUpdateWindowList windows: [MirageWindow]
    ) {
        onWindowListUpdate?(windows)
    }

    func clientService(
        _: MirageClientService,
        didDisconnectFromHost reason: String
    ) {
        onDisconnect?(reason)
    }

    func clientService(
        _: MirageClientService,
        didEncounterError error: Error
    ) {
        onError?(error)
    }
}
