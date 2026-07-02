//
//  DevPilotApp.swift
//  DevPilot
//
//  Created by rose on 2026/7/2.
//

import SwiftUI
import AppKit

@main
struct DevPilotApp: App {
    @StateObject private var store = PortMonitorStore()

    var body: some Scene {
        WindowGroup("DevPilot", id: "main") {
            ContentView(store: store)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("DevPilot", systemImage: "network") {
            MenuBarStatusView(store: store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarStatusView: View {
    @ObservedObject var store: PortMonitorStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let errorMessage = store.errorMessage {
            Text(errorMessage)
        } else if store.projectPorts.isEmpty {
            Text("没有项目端口")
        } else {
            Text("项目服务 \(store.projectPorts.count)")

            Divider()

            ForEach(store.projectPorts.prefix(8)) { port in
                Button {
                    openMainWindow()
                } label: {
                    Label(port.menuTitle, systemImage: "network")
                }
            }

            if store.projectPorts.count > 8 {
                Text("还有 \(store.projectPorts.count - 8) 个项目端口")
            }
        }

        Divider()

        Button {
            Task { await store.refresh(visibleScope: .project) }
        } label: {
            Label(store.isRefreshing ? "正在刷新" : "刷新", systemImage: "arrow.clockwise")
        }
        .disabled(store.isRefreshing)

        Button {
            openMainWindow()
        } label: {
            Label("打开主窗口", systemImage: "macwindow")
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension PortUsage {
    var menuTitle: String {
        let resolvedCommand = displayCommand.isEmpty ? command : displayCommand
        if resolvedCommand.isEmpty {
            return "\(port) \(protocolName.rawValue)"
        }
        return "\(port) \(resolvedCommand)"
    }
}
