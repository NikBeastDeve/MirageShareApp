//
//  HostView.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Host mode view for sharing this Mac's screen.
//

import SwiftUI

struct HostView: View {
    @Environment(MirageShareState.self)
    private var appState

    @State
    private var isStarting = false

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 24) {
            headerSection

            Divider()

            if appState.hostManager.isRunning {
                runningSection
            } else {
                stoppedSection
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Share Your Screen")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Allow other Macs to view and control your screen")
                .foregroundStyle(.secondary)
        }
    }

    private var stoppedSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                settingRow(
                    icon: "person.text.rectangle",
                    title: "Host Name",
                    value: appState.hostName
                )

                // Quality Picker
                HStack {
                    Label("Quality", systemImage: "gauge.with.dots.needle.67percent")
                    Spacer()
                    Picker("Quality", selection: Bindable(appState).qualityPreset) {
                        ForEach(MirageQualityPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                // Frame Rate Picker
                HStack {
                    Label("Frame Rate", systemImage: "figure.run")
                    Spacer()
                    Picker("Frame Rate", selection: Bindable(appState).defaultFrameRate) {
                        Text("60 FPS").tag(60)
                        Text("120 FPS").tag(120)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                settingRow(
                    icon: "network",
                    title: "Peer-to-Peer",
                    value: appState.enablePeerToPeer ? "Enabled" : "Disabled"
                )

                settingRow(
                    icon: "keyboard",
                    title: "Remote Control",
                    value: appState.allowRemoteControl ? "Allowed" : "View Only"
                )
            }
            .padding(.horizontal)

            Button {
                Task {
                    isStarting = true
                    try? await appState.startHost()
                    isStarting = false
                }
            } label: {
                Label("Start Sharing", systemImage: "play.fill")
                    .font(.headline)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isStarting)
            .padding(.top)
        }
    }

    private var runningSection: some View {
        VStack(spacing: 20) {
            StatusBadge(
                icon: "checkmark.circle.fill",
                text: "Sharing Active",
                color: .green
            )

            if !appState.hostManager.connectedClients.isEmpty {
                clientsSection
            } else {
                waitingSection
            }

            if let error = appState.hostManager.currentError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await appState.stopHost()
                }
            } label: {
                Label("Stop Sharing", systemImage: "stop.fill")
                    .font(.headline)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.top)
        }
    }

    private var waitingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.2)

            Text("Waiting for connections...")
                .foregroundStyle(.secondary)

            Text("Other Macs on your network will see \"\(appState.hostName)\" in their device list")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var clientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Clients")
                .font(.headline)
                .padding(.horizontal)

            List(appState.hostManager.connectedClients) { client in
                ClientRow(client: client)
            }
            .clipShape(.rect(cornerRadius: 8))
            .frame(height: min(CGFloat(appState.hostManager.connectedClients.count) * 60 + 20, 200))
        }
    }

    // MARK: - Helpers

    private func settingRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Client Row

struct ClientRow: View {
    let client: MirageConnectedClient

    var body: some View {
        HStack {
            Image(systemName: client.deviceType.systemImage)
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(client.name)
                    .font(.headline)

                Text(client.deviceType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusDot(isActive: true)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.headline)
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(.capsule)
    }
}

// MARK: - Status Dot

struct StatusDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.gray)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Preview

#Preview("Stopped") {
    HostView()
        .environment(MirageShareState())
        .frame(width: 500, height: 400)
}
