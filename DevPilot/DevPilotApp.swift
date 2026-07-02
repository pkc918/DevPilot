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
        .frame(width: 380)
        .task {
            await store.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await store.refresh(showActivity: false)
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
                Text("项目服务")
                Spacer()
                Text("\(store.projectPorts.count)")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.projectPorts) { port in
                        portCard(port)
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    private func portCard(_ port: PortUsage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(port.port, format: .number)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)

                ProtocolBadge(protocol: port.protocolName)

                Text(port.displayCommand)
                    .font(.callout)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }

            if !port.workingDirectory.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(port.shortProjectPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(port.workingDirectory)
                }
            } else if !port.executablePath.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(port.executablePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(port.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private struct ProtocolBadge: View {
        let `protocol`: PortProtocol

        var body: some View {
            Text(`protocol`.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(`protocol` == .tcp ? .green : .orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(`protocol` == .tcp ? .green.opacity(0.12) : .orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
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
