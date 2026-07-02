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
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarStatusView: View {
    @ObservedObject var store: PortMonitorStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Divider()

            if store.projectPorts.isEmpty {
                ContentUnavailableView(
                    "没有项目端口",
                    systemImage: "network.slash",
                    description: Text("刷新后会显示本机开发服务端口。")
                )
                .frame(height: 120)
            } else {
                projectPortsList
            }
        }
        .padding(14)
        .frame(width: 340)
        .task {
            if store.lastUpdated == nil {
                await store.refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("项目服务端口")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await store.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("打开主窗口", systemImage: "macwindow")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
    }

    private var projectPortsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("全部项目服务")
                Spacer()
                Text("\(store.projectPorts.count)")
                    .monospacedDigit()
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(store.projectPorts) { port in
                        HStack(spacing: 8) {
                            Text(port.port, format: .number)
                                .monospacedDigit()
                                .frame(width: 48, alignment: .leading)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(port.command)
                                    .lineLimit(1)
                                Text(port.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Text(port.protocolName.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }

    private var statusText: String {
        if let errorMessage = store.errorMessage {
            return errorMessage
        }

        guard let lastUpdated = store.lastUpdated else {
            return "尚未扫描"
        }

        return "最近更新 \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }
}
