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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppState.portStore

    var body: some Scene {
        WindowGroup("DevPilot", id: "main") {
            ContentView(store: store)
                .background(MainWindowRegistrationView())
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

private enum AppState {
    static let portStore = PortMonitorStore()
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarController.shared.configure(store: AppState.portStore)
    }
}

private final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    var openMainWindow: (() -> Void)?

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?

    func configure(store: PortMonitorStore) {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "DevPilot")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 360)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarStatusView(
                store: store,
                onRefresh: {
                    Task { await store.refresh(visibleScope: .project) }
                },
                onOpenMainWindow: { [weak self] in
                    self?.closePopover()
                    self?.showMainWindow()
                }
            )
        )

        Task { await store.refresh(visibleScope: .project) }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func showMainWindow() {
        if let openMainWindow {
            openMainWindow()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "DevPilot" }?.makeKeyAndOrderFront(nil)
    }
}

private struct MainWindowRegistrationView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                StatusBarController.shared.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}

private struct MenuBarStatusView: View {
    @ObservedObject var store: PortMonitorStore
    let onRefresh: () -> Void
    let onOpenMainWindow: () -> Void
    private let maxVisibleServices = 8

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider()

            content
        }
        .frame(width: 420)
        .task {
            await store.refresh(visibleScope: .project)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MenuBarIconButton(
                systemImage: "arrow.clockwise",
                help: "刷新",
                action: onRefresh
            )
            .symbolEffect(.rotate, value: store.isRefreshing)
            .disabled(store.isRefreshing)

            MenuBarIconButton(
                systemImage: "macwindow",
                help: "打开主窗口",
                action: onOpenMainWindow
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = store.errorMessage {
            ContentUnavailableView(
                "扫描失败",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
            .frame(height: 180)
        } else if store.projectPorts.isEmpty {
            ContentUnavailableView(
                "没有项目端口",
                systemImage: "network.slash",
                description: Text("当前没有本机项目服务监听端口。")
            )
            .frame(height: 180)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(visibleProjectPorts) { port in
                        MenuBarPortRow(port: port)

                        if port.id != visibleProjectPorts.last?.id {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }

                    if store.projectPorts.count > maxVisibleServices {
                        Text("还有 \(store.projectPorts.count - maxVisibleServices) 个项目端口")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
            }
            .frame(height: serviceListHeight)
        }
    }

    private var title: String {
        store.projectPorts.isEmpty ? "项目服务" : "项目服务 \(store.projectPorts.count)"
    }

    private var subtitle: String {
        if store.isRefreshing {
            return "正在扫描"
        }
        if store.projectPorts.isEmpty {
            return "没有项目端口"
        }
        return "\(store.projectProcessCount) 个进程"
    }

    private var visibleProjectPorts: [PortUsage] {
        Array(store.projectPorts.prefix(maxVisibleServices))
    }

    private var serviceListHeight: CGFloat {
        let rowHeight: CGFloat = 68
        let moreHeight: CGFloat = store.projectPorts.count > maxVisibleServices ? 36 : 0
        return min(CGFloat(visibleProjectPorts.count) * rowHeight + moreHeight, 420)
    }
}

private struct MenuBarIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

private struct MenuBarPortRow: View {
    let port: PortUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(port.port.formatted(.number))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .leading)

                Text(port.displayProcessName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                MenuBarTag(text: port.serverURLLabel, systemImage: "paperplane", tint: .secondary)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                MenuBarTag(text: port.protocolName.rawValue, tint: .green)
            }

            ProjectPathButton(path: port.workingDirectory, title: port.projectLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

private struct ProjectPathButton: View {
    let path: String
    let title: String

    var body: some View {
        Button {
            revealInFinder()
        } label: {
            MenuBarTag(text: title, systemImage: "folder", tint: .blue)
        }
        .buttonStyle(.plain)
        .disabled(path.isEmpty)
        .help(path.isEmpty ? "未知项目" : path)
        .contextMenu {
            if !path.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                } label: {
                    Label("拷贝路径", systemImage: "doc.on.doc")
                }

                Button {
                    revealInFinder()
                } label: {
                    Label("在 Finder 中打开", systemImage: "folder")
                }
            }
        }
    }

    private func revealInFinder() {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}

private struct MenuBarTag: View {
    let text: String
    var systemImage: String?
    let tint: Color

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private extension PortUsage {
    var displayProcessName: String {
        let resolvedCommand = displayCommand.isEmpty ? command : displayCommand
        return resolvedCommand.isEmpty ? "-" : resolvedCommand
    }

    var projectLabel: String {
        shortProjectPath.isEmpty ? "未知项目" : shortProjectPath
    }

    var serverURLLabel: String {
        "\(normalizedServerHost):\(port)"
    }

    private var normalizedServerHost: String {
        if address == "*" || address == "0.0.0.0" || address == "::" || address == "[::]" {
            return "localhost"
        }
        if address == "[::1]" || address == "::1" {
            return "127.0.0.1"
        }
        return address
    }
}
