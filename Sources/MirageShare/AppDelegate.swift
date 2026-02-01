//
//  AppDelegate.swift
//  MirageShare
//
//  Created by Assistant on 2/1/26.
//
//  Handles app lifecycle, menu bar, and permissions.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        checkPermissions()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: "display.2",
            accessibilityDescription: "MirageShare"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Open MirageShare",
            action: #selector(showMainWindow),
            keyEquivalent: "o"
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Toggle Host",
            action: #selector(toggleHost),
            keyEquivalent: "h"
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    private func checkPermissions() {
        // Check and request accessibility permission
        let permissionManager = MirageAccessibilityPermissionManager()
        if !permissionManager.isAccessibilityGranted {
            permissionManager.checkAndPromptIfNeeded()
        }

        // Screen recording permission will be requested automatically when needed
    }

    @objc
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows where window.title == "MirageShare" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    @objc
    private func toggleHost() {
        NotificationCenter.default.post(name: .toggleHost, object: nil)
    }
}

extension Notification.Name {
    static let toggleHost = Notification.Name("MirageShare.toggleHost")
}
