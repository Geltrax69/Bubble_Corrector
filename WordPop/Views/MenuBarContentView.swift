//
//  MenuBarContentView.swift
//  WordPop
//

import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    @State private var manager = AccessibilityManager.shared
    
    var body: some View {
        VStack {
            if !manager.isTrusted {
                Text("⚠️ Permission Required")
                Button("Grant Access...") {
                    manager.checkPermissions(prompt: true)
                }
                Divider()
            } else {
                Text("✅ Monitoring Active")
                Divider()
            }
            
            Button("Settings...") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit WordPop") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
