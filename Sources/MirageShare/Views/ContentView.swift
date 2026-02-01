//
//  ContentView.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Main content view with tab navigation for Host and Client modes.
//

import SwiftUI

struct ContentView: View {
    @Environment(MirageShareState.self)
    private var appState

    @State
    private var selectedTab: Tab = .client

    enum Tab: String, CaseIterable {
        case client
        case host
    }

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $selectedTab) {
            ClientView()
                .tabItem {
                    Label("Connect", systemImage: "desktopcomputer")
                }
                .tag(Tab.client)

            HostView()
                .tabItem {
                    Label("Share Screen", systemImage: "display")
                }
                .tag(Tab.host)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .toggleHost)) { _ in
            Task {
                await appState.toggleHost()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(MirageShareState())
}
