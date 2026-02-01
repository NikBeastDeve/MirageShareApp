//
//  ClientView.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Client mode view for connecting to remote Macs.
//

import SwiftUI

struct ClientView: View {
    @Environment(MirageShareState.self)
    private var appState

    @State
    private var isDiscovering = true
    @State
    private var showStreamWindow = false

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            headerSection

            Divider()

            if appState.clientManager.isConnected {
                connectedSection
            } else {
                discoverySection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appState.clientManager.startDiscovery(enablePeerToPeer: appState.enablePeerToPeer)
        }
        .onDisappear {
            appState.clientManager.stopDiscovery()
        }
        .onChange(of: appState.clientManager.activeSessions.count) { oldCount, newCount in
            if newCount > 0 && oldCount == 0 {
                showStreamWindow = true
            }
        }
        .sheet(isPresented: $showStreamWindow) {
            StreamWindowView(
                sessions: appState.clientManager.activeSessions,
                clientService: appState.clientManager.clientService,
                sessionStore: appState.clientManager.sessionStore
            )
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Connect to a Mac")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("View and control another Mac on your network")
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var discoverySection: some View {
        VStack(spacing: 16) {
            if appState.clientManager.discoveredHosts.isEmpty {
                emptyStateSection
            } else {
                hostsListSection
            }
        }
        .padding()
    }

    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.2)

            VStack(spacing: 8) {
                Text("Looking for Macs...")
                    .foregroundStyle(.secondary)

                Text("Make sure the other Mac is on the same network and has sharing enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Button {
                // Manual refresh
                appState.clientManager.stopDiscovery()
                appState.clientManager.startDiscovery(enablePeerToPeer: appState.enablePeerToPeer)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .padding(.top)
        }
        .padding(.vertical, 60)
    }

    private var hostsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Macs")
                    .font(.headline)

                Spacer()

                Button {
                    appState.clientManager.stopDiscovery()
                    appState.clientManager.startDiscovery(enablePeerToPeer: appState.enablePeerToPeer)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)

            List(appState.clientManager.discoveredHosts) { host in
                HostRow(
                    host: host,
                    onConnect: {
                        Task {
                            try? await appState.connect(to: host)
                        }
                    }
                )
            }
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var connectedSection: some View {
        VStack(spacing: 16) {
            connectionHeader

            if let host = appState.clientManager.connectedHost {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Windows")
                            .font(.headline)

                        Spacer()

                        Button {
                            Task {
                                try? await appState.clientManager.clientService.requestWindowList()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }

                    if appState.clientManager.availableWindows.isEmpty {
                        Text("No windows available")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        windowsGrid
                    }
                }
                .padding()
            }

            Spacer()

            if let error = appState.clientManager.currentError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding()
            }
        }
    }

    private var connectionHeader: some View {
        HStack {
            if let host = appState.clientManager.connectedHost {
                HStack(spacing: 12) {
                    Image(systemName: host.deviceType.systemImage)
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text(host.name)
                            .font(.headline)

                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            Button {
                Task {
                    await appState.disconnect()
                }
            } label: {
                Label("Disconnect", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
    }

    private var windowsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                ForEach(appState.clientManager.availableWindows) { window in
                    WindowCard(
                        window: window,
                        onSelect: {
                            Task {
                                try? await appState.clientManager.startWindowStream(
                                    window,
                                    qualityPreset: appState.qualityPreset
                                )
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Host Row

struct HostRow: View {
    let host: MirageHost
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack {
                Image(systemName: host.deviceType.systemImage)
                    .font(.title2)
                    .frame(width: 40)

                VStack(alignment: .leading) {
                    Text(host.name)
                        .font(.headline)

                    HStack(spacing: 4) {
                        Text(host.deviceType.displayName)
                        Text("•")
                        Text("\(host.capabilities.maxFrameRate) FPS")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window Card

struct WindowCard: View {
    let window: MirageWindow
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "window")
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !window.isOnScreen {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(window.title ?? "Untitled")
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let app = window.application {
                    Text(app.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("\(Int(window.frame.width))×\(Int(window.frame.height))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.primary)
                }
            }
            .padding()
            .background(.quaternary.opacity(0.2))
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Discovery") {
    ClientView()
        .environment(MirageShareState())
        .frame(width: 600, height: 500)
}
