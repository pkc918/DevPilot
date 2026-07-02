//
//  DevPilotApp.swift
//  DevPilot
//
//  Created by rose on 2026/7/2.
//

import SwiftUI

@main
struct DevPilotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}
