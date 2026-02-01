//
//  SettingsView.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  App settings view for configuring MirageShare.
//

import SwiftUI
@preconcurrency import ScreenCaptureKit

struct SettingsView: View {
    @Environment(MirageShareState.self)
    private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            qualitySettings
                .tabItem {
                    Label("Quality", systemImage: "gauge.with.dots.needle.67percent")
                }

            networkSettings
                .tabItem {
                    Label("Network", systemImage: "network")
                }
        }
        .padding()
        .frame(width: 500, height: 400)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section {
                TextField("Host Name", text: Bindable(appState).hostName)
                    .textFieldStyle(.roundedBorder)

                Toggle("Show in Menu Bar", isOn: Bindable(appState).showInMenuBar)

                Toggle("Allow Remote Control", isOn: Bindable(appState).allowRemoteControl)

                Text("When enabled, connected Macs can control your mouse and keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Host Settings")
                    .font(.headline)
            }

            Section {
                Button("Check Permissions") {
                    checkPermissions()
                }
            } header: {
                Text("Permissions")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Quality Settings

    private var qualitySettings: some View {
        Form {
            Section {
                Picker("Quality Preset", selection: Bindable(appState).qualityPreset) {
                    ForEach(MirageQualityPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName)
                            .tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    qualityDescription(for: appState.qualityPreset)
                }
                .padding(.top, 8)
            } header: {
                Text("Streaming Quality")
                    .font(.headline)
            }

            Section {
                Picker("Default Frame Rate", selection: Bindable(appState).defaultFrameRate) {
                    Text("60 FPS").tag(60)
                    Text("120 FPS").tag(120)
                }
                .pickerStyle(.segmented)

                Text("Higher frame rates provide smoother motion but require more bandwidth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Frame Rate")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Network Settings

    private var networkSettings: some View {
        Form {
            Section {
                Toggle("Enable Peer-to-Peer", isOn: Bindable(appState).enablePeerToPeer)

                Text("Allows direct connections between Macs without requiring the same WiFi network (uses AWDL)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Connection")
                    .font(.headline)
            }

            Section {
                HStack {
                    Text("Protocol Version")
                    Spacer()
                    Text("\(MirageKit.protocolVersion)")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("Service Type")
                    Spacer()
                    Text(MirageKit.serviceType)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("Advanced")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func qualityDescription(for preset: MirageQualityPreset) -> some View {
        let config = preset.encoderConfiguration(for: 60)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Resolution:")
                    .foregroundStyle(.secondary)
                Text("Up to 5K")
            }

            HStack {
                Text("Color Space:")
                    .foregroundStyle(.secondary)
                Text(config.colorSpace.displayName)
            }

            HStack {
                Text("Pixel Format:")
                    .foregroundStyle(.secondary)
                Text(config.pixelFormat.displayName)
            }

            HStack {
                Text("Quality:")
                    .foregroundStyle(.secondary)
                Text("\(Int(config.frameQuality * 100))%")
            }
        }
        .font(.caption)
    }

    private func checkPermissions() {
        // Check and request accessibility permission (only when user explicitly clicks)
        let permissionManager = MirageAccessibilityPermissionManager()
        permissionManager.checkAndPromptIfNeeded()

        // Check and request screen recording permission (uses SCShareableContent)
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            } catch {
                MirageLogger.error(.host, "Screen recording permission needed: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(MirageShareState())
}
