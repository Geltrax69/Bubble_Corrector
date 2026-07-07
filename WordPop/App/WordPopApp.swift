//
//  WordPopApp.swift
//  WordPop
//

import SwiftUI

@main
struct WordPopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // macOS 13+ native menu bar extra implementation
    var body: some Scene {
        MenuBarExtra("WordPop", systemImage: "text.bubble") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.menu)
        
        // Standard settings window accessible from the menu bar
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        WordPopLogger.log("WordPop launched from \(Bundle.main.bundlePath)")

        let isTrusted = AccessibilityManager.shared.checkPermissions(prompt: true)
        WordPopLogger.log("Accessibility trusted: \(isTrusted)")
        
        if isTrusted {
            KeyboardMonitorService.shared.start()
        } else {
            WordPopLogger.log("Accessibility permission not granted. Waiting for permission.")
            startPermissionPolling()
        }
    }
    
    private func startPermissionPolling() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AccessibilityManager.shared.checkPermissions(prompt: false) {
                WordPopLogger.log("Accessibility permission granted. Starting keyboard monitor.")
                KeyboardMonitorService.shared.start()
                timer.invalidate()
            }
        }
    }
}
