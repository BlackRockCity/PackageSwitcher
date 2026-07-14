//
//  PackageSwitcherApp.swift
//  PackageSwitcher
//
//  Created by BlackRockCity on 7/2/24.
//

import SwiftUI
import AppKit

enum AppLinks {
    static let support = URL(string: "https://buymeacoffee.com/blackrockcity")!
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct PackageSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 900)
        .commands {
            AboutCommands()
        }

        Window(String(localized: "about.title"), id: "about") {
            AboutView()
        }
        .defaultSize(width: 420, height: 360)
        .windowResizability(.contentSize)
    }
}

private struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "about.menu")) {
                openWindow(id: "about")
            }
        }
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 5) {
                Text(String(localized: "app.title"))
                    .font(.title.weight(.semibold))
                Text(
                    String(
                        format: String(localized: "about.version"),
                        version
                    )
                )
                .foregroundStyle(.secondary)
            }

            Text(String(localized: "about.description"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(AppLinks.support.absoluteString, destination: AppLinks.support)
                .accessibilityLabel(String(localized: "support.open_link"))

            Text(String(localized: "about.license"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 420)
    }
}
