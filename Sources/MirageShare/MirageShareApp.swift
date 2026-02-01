//
//  MirageShareApp.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Main app entry point for MirageShare.
//

import SwiftUI

@main
struct MirageShareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    @State
    private var appState = MirageShareState()

    var body: some Scene {
        WindowGroup("MirageShare") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 500, height: 400)
        }
    }
}
