//
//  MP3GainApp.swift
//  MP3GainExpress
//

import SwiftUI
import AppKit

@main
struct MP3GainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowResizability(.contentSize)
        .commands {
            // Insert "Check for Updates..." into the application menu (after About)
            CommandGroup(after: .appInfo) {
                Button(NSLocalizedString("Check for Updates...", comment: "Check for Updates...")) {
                    viewModel.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: .command)
            }
            // Language menu between Window and Help
            CommandMenu(NSLocalizedString("Language menu", comment: "Language")) {
                Button(NSLocalizedString("Select Language menu item", comment: "Select Language...")) {
                    viewModel.showLanguageSelector = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }

        // Adds "Settings…" / "Preferences…" menu item (⌘,) automatically
        Settings {
            PreferencesView()
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
