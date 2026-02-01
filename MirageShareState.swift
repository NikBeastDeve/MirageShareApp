//
//  MirageShareState.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Central app state managing host and client services.
//

import Foundation
import Observation

/// Main app state that coordinates host and client functionality.
@Observable
@MainActor
final class MirageShareState {
    // MARK: - Host

    let hostManager: HostManager

    var isHostRunning: Bool { hostManager.isRunning }

    // MARK: - Client

    let clientManager: ClientManager

    var isClientConnected: Bool { clientManager.isConnected }

    // MARK: - Settings

    var hostName: String {
        get { UserDefaults.standard.string(forKey: "hostName") ?? defaultHostName }
        set { UserDefaults.standard.set(newValue, forKey: "hostName") }
    }

    var qualityPreset: MirageQualityPreset {
        get {
            let raw = UserDefaults.standard.string(forKey: "qualityPreset") ?? "high"
            return MirageQualityPreset(rawValue: raw) ?? .high
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "qualityPreset") }
    }

    var enablePeerToPeer: Bool {
        get { UserDefaults.standard.bool(forKey: "enablePeerToPeer") }
        set { UserDefaults.standard.set(newValue, forKey: "enablePeerToPeer") }
    }

    var defaultFrameRate: Int {
        get { UserDefaults.standard.integer(forKey: "defaultFrameRate") }
        set { UserDefaults.standard.set(newValue, forKey: "defaultFrameRate") }
    }

    var allowRemoteControl: Bool {
        get { UserDefaults.standard.bool(forKey: "allowRemoteControl") }
        set { UserDefaults.standard.set(newValue, forKey: "allowRemoteControl") }
    }

    var showInMenuBar: Bool {
        get { UserDefaults.standard.bool(forKey: "showInMenuBar") }
        set { UserDefaults.standard.set(newValue, forKey: "showInMenuBar") }
    }

    // MARK: - Private

    private let defaultHostName: String

    // MARK: - Initialization

    init() {
        defaultHostName = Host.current().localizedName ?? "Mac"

        // Initialize defaults
        if UserDefaults.standard.object(forKey: "enablePeerToPeer") == nil {
            UserDefaults.standard.set(true, forKey: "enablePeerToPeer")
        }
        if UserDefaults.standard.integer(forKey: "defaultFrameRate") == 0 {
            UserDefaults.standard.set(60, forKey: "defaultFrameRate")
        }
        if UserDefaults.standard.object(forKey: "allowRemoteControl") == nil {
            UserDefaults.standard.set(true, forKey: "allowRemoteControl")
        }
        if UserDefaults.standard.object(forKey: "showInMenuBar") == nil {
            UserDefaults.standard.set(true, forKey: "showInMenuBar")
        }

        hostManager = HostManager()
        clientManager = ClientManager()
    }

    // MARK: - Host Controls

    func startHost() async throws {
        try await hostManager.start(
            hostName: hostName,
            qualityPreset: qualityPreset,
            enablePeerToPeer: enablePeerToPeer,
            allowRemoteControl: allowRemoteControl
        )
    }

    func stopHost() async {
        await hostManager.stop()
    }

    func toggleHost() async {
        if hostManager.isRunning {
            await stopHost()
        } else {
            try? await startHost()
        }
    }

    // MARK: - Client Controls

    func connect(to host: MirageHost) async throws {
        try await clientManager.connect(to: host, qualityPreset: qualityPreset)
    }

    func disconnect() async {
        await clientManager.disconnect()
    }
}
