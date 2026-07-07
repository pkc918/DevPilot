import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject private var store: PortMonitorStore
    @AppStorage("portAutoRefresh") private var portAutoRefresh = true
    private let checkForUpdates: () -> Void
    @State private var selectedFeature: AppFeature = .ports
    @State private var searchText = ""
    @State private var selectedScope: PortScope = .project
    @State private var selectedProtocol: PortProtocol?
    @State private var selectedPort: Int?

    init(store: PortMonitorStore = PortMonitorStore(), checkForUpdates: @escaping () -> Void = {}) {
        self.store = store
        self.checkForUpdates = checkForUpdates
    }

    private var filteredPorts: [PortUsage] {
        let scopedPorts = selectedScope == .project ? store.projectPorts : store.ports

        return scopedPorts.filter { item in
            let matchesProtocol = selectedProtocol.map { item.protocolName == $0 } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard matchesProtocol else { return false }
            guard !query.isEmpty else { return true }

            return item.command.localizedCaseInsensitiveContains(query)
                || item.parentCommand.localizedCaseInsensitiveContains(query)
                || item.user.localizedCaseInsensitiveContains(query)
                || item.address.localizedCaseInsensitiveContains(query)
                || item.workingDirectory.localizedCaseInsensitiveContains(query)
                || String(item.port).contains(query)
                || String(item.pid).contains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            AppSidebarView(
                selection: $selectedFeature,
                checkForUpdates: checkForUpdates
            )
        } detail: {
            detailView
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(minWidth: 820, minHeight: 640)
        .toolbar {
            if selectedFeature == .ports {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await store.refresh(visibleScope: selectedScope) }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .keyboardShortcut("r", modifiers: [.command])
                }
            }
        }
        .onChange(of: selectedScope) { _, _ in
            store.publishLatestPortsIfNeeded()
        }
        .task(id: selectedScope) {
            await store.refresh(visibleScope: selectedScope)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if portAutoRefresh {
                    await store.refresh(showActivity: false, visibleScope: selectedScope, minimumInterval: 2.5)
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedFeature {
        case .ports:
            PortMonitorWorkspace(
                store: store,
                ports: filteredPorts,
                searchText: $searchText,
                selectedScope: selectedScope,
                selectedScopeBinding: $selectedScope,
                selectedProtocol: $selectedProtocol,
                selectedPort: $selectedPort
            )
        }
    }
}

private enum AppFeature: String, CaseIterable, Identifiable {
    case ports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ports:
            "Port"
        }
    }

    var subtitle: String {
        switch self {
        case .ports:
            "端口与进程"
        }
    }

    var systemImage: String {
        switch self {
        case .ports:
            "network"
        }
    }
}

private struct AppSidebarView: View {
    @Binding var selection: AppFeature
    let checkForUpdates: () -> Void
    @State private var showingUpdateInfo = false

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Tools") {
                    ForEach(AppFeature.allCases) { feature in
                        Label(feature.title, systemImage: feature.systemImage)
                            .tag(feature)
                            .help(feature.subtitle)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("DevPilot")

            Divider()

            Button {
                showingUpdateInfo = true
            } label: {
                HStack(spacing: 10) {
                    Text("DevPilot")
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Text(AppVersionInfo.versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .help("版本与更新")
            .sheet(isPresented: $showingUpdateInfo) {
                UpdateInfoSheet(checkForUpdates: checkForUpdates)
            }
        }
    }
}

private struct UpdateInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let checkForUpdates: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("应用", value: "DevPilot")
                    LabeledContent("版本", value: AppVersionInfo.versionText)
                    LabeledContent("构建", value: AppVersionInfo.buildText)
                }

                Section {
                    Button {
                        checkForUpdates()
                    } label: {
                        Label("检查新版本", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 380, height: 230)
    }
}

private struct PortMonitorWorkspace: View {
    @ObservedObject var store: PortMonitorStore
    let ports: [PortUsage]
    @Binding var searchText: String
    let selectedScope: PortScope
    @Binding var selectedScopeBinding: PortScope
    @Binding var selectedProtocol: PortProtocol?
    @Binding var selectedPort: Int?

    var body: some View {
        VStack(spacing: 0) {
            PortHeaderView(
                store: store,
                metadata: store.metadata,
                visibleCount: ports.count,
                selectedScope: selectedScope,
                selectedScopeBinding: $selectedScopeBinding,
                selectedProtocol: $selectedProtocol
            )

            PortTableView(
                ports: ports,
                scope: selectedScope,
                selection: $selectedPort,
                isRefreshing: store.isRefreshing,
                closePortServices: { usages in
                    await store.closePortServices(usages)
                }
            )
            .equatable()
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $searchText, prompt: "搜索端口、进程、PID")
    }
}

private struct PortHeaderView: View {
    @ObservedObject var store: PortMonitorStore
    @ObservedObject var metadata: PortRefreshMetadata
    let visibleCount: Int
    let selectedScope: PortScope
    @Binding var selectedScopeBinding: PortScope
    @Binding var selectedProtocol: PortProtocol?

    private var lastUpdatedText: String {
        guard let lastUpdated = metadata.lastUpdated else {
            return "尚未刷新"
        }
        return lastUpdated.formatted(date: .omitted, time: .standard)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Port")
                .font(.title2.weight(.semibold))
            Text("本机开发服务端口、进程和监听状态")
                .foregroundStyle(.secondary)
        }
    }

    private var filterControls: some View {
        HStack(spacing: 12) {
            Picker("协议", selection: $selectedProtocol) {
                Text("全部").tag(nil as PortProtocol?)
                ForEach(PortProtocol.allCases) { item in
                    Text(item.rawValue).tag(item as PortProtocol?)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Picker("范围", selection: $selectedScopeBinding) {
                ForEach(PortScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    titleBlock
                    Spacer()
                    filterControls
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    filterControls
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)

            HStack(spacing: 16) {
                StatusPill(
                    title: store.isRefreshing ? "正在扫描" : "已列出",
                    value: store.isRefreshing ? nil : "\(visibleCount)",
                    systemImage: store.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: store.errorMessage == nil ? .green : .orange
                )

                MetricPill(title: "TCP", value: "\(store.tcpCount)")
                MetricPill(title: "UDP", value: "\(store.udpCount)")
                MetricPill(title: "进程", value: "\(selectedScope == .project ? store.projectProcessCount : store.processCount)")

                Spacer()

                Text("\(lastUpdatedText) · \(metadata.diagnosticText)")
                    .lineLimit(1)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .padding(.horizontal, 22)
            .padding(.bottom, 12)

            Divider()
        }
        .background(.bar)
    }
}

private struct StatusPill: View {
    let title: String
    let value: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            HStack(spacing: 5) {
                Text(title)
                if let value {
                    Text(value)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }
}

private struct PortTableView: View, Equatable {
    static func == (lhs: PortTableView, rhs: PortTableView) -> Bool {
        lhs.ports == rhs.ports && lhs.scope == rhs.scope && lhs.isRefreshing == rhs.isRefreshing
    }
    let ports: [PortUsage]
    let scope: PortScope
    @Binding var selection: Int?
    let isRefreshing: Bool
    let closePortServices: ([PortUsage]) async -> Void
    @State private var expandedPorts: Set<Int> = []

    private var portGroups: [PortUsageGroup] {
        Dictionary(grouping: ports, by: \.port)
            .map { PortUsageGroup(port: $0.key, usages: $0.value) }
            .sorted { $0.port < $1.port }
    }

    private var tableRows: [PortTableRow] {
        portGroups.flatMap { group -> [PortTableRow] in
            var rows: [PortTableRow] = [.group(group)]
            if group.hasMultipleUsages, expandedPorts.contains(group.port) {
                rows.append(contentsOf: group.usages.map { .detail($0, parentPort: group.port) })
            }
            return rows
        }
    }

    private var selectedRow: Binding<PortTableRow.ID?> {
        Binding {
            selection.map { PortTableRow.groupID($0) }
        } set: { rowID in
            selection = PortTableRow.port(from: rowID)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if ports.isEmpty, !isRefreshing {
                ContentUnavailableView(
                    scope == .project ? "没有找到项目服务端口" : "没有找到端口占用",
                    systemImage: "network.slash",
                    description: Text(scope == .project ? "当前默认只显示常见前端、后端和数据服务的 TCP 监听端口。" : "尝试刷新，或检查应用是否有权限读取本机进程和网络状态。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(of: PortTableRow.self, selection: selectedRow) {
                    TableColumn("") { row in
                        disclosureCell(for: row)
                    }
                    .width(18)
                    .alignment(.center)

                    TableColumn("端口") { row in
                        if row.isDetail {
                            centeredText("")
                        } else {
                            centeredText(row.port.formatted(.number))
                                .monospacedDigit()
                        }
                    }
                    .width(min: 68, ideal: 76, max: 92)
                    .alignment(.center)

                    TableColumn("协议") { row in
                        centeredText(row.protocolText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(protocolColor(row.protocolText))
                    }
                    .width(min: 44, ideal: 52, max: 60)
                    .alignment(.center)

                    TableColumn("进程") { row in
                        ProcessCell(
                            text: row.processText,
                            executablePath: row.executablePath,
                            isMultiple: row.isMultipleGroup
                        )
                            .foregroundStyle(row.isDetail ? .secondary : .primary)
                            .help(row.processText)
                    }
                    .width(min: 120, ideal: 160, max: 220)
                    .alignment(.center)

                    TableColumn("项目") { row in
                        if row.isProjectRow, row.workingDirectoryText != "-" {
                            ProjectPathCell(path: row.workingDirectoryText)
                        } else {
                            centeredText("-")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .width(min: 120, ideal: 180, max: 300)
                    .alignment(.center)

                    TableColumn("PID") { row in
                        centeredText(row.pidText)
                            .monospacedDigit()
                            .foregroundStyle(row.isMultipleGroup ? .secondary : .primary)
                    }
                    .width(min: 64, ideal: 76, max: 92)
                    .alignment(.center)

                    TableColumn("地址") { row in
                        centeredText(row.addressText)
                            .lineLimit(1)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 120, ideal: 190, max: 350)
                    .alignment(.center)

                    TableColumn("状态") { row in
                        centeredText(row.stateText)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 82, ideal: 96, max: 120)
                    .alignment(.center)
                } rows: {
                    ForEach(tableRows) { row in
                        TableRow(row)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await closePortServices(row.targetUsages)
                                    }
                                } label: {
                                    Label(closeTitle(for: row), systemImage: "xmark.circle")
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("端口使用情况")
    }

    @ViewBuilder
    private func disclosureCell(for row: PortTableRow) -> some View {
        if let group = row.group, group.hasMultipleUsages {
            Button {
                if expandedPorts.contains(group.port) {
                    expandedPorts.remove(group.port)
                } else {
                    expandedPorts.insert(group.port)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(expandedPorts.contains(group.port) ? 90 : 0))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
        }
    }

    private func centeredText(_ text: String, minWidth: CGFloat = 0) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(minWidth: minWidth, maxWidth: .infinity, alignment: .center)
    }

    private func closeTitle(for row: PortTableRow) -> String {
        row.targetUsages.count > 1 ? "关闭此端口的所有服务" : "关闭端口服务"
    }

    private func protocolColor(_ text: String) -> Color {
        if text == PortProtocol.tcp.rawValue {
            return .green
        }
        if text == PortProtocol.udp.rawValue {
            return .orange
        }
        return .secondary
    }

}

private struct ProcessCell: View {
    let text: String
    let executablePath: String
    let isMultiple: Bool

    private var icon: ProcessIcon? {
        ProcessIcon.matching(text: text, executablePath: executablePath, isMultiple: isMultiple)
    }

    var body: some View {
        if let icon {
            iconView(for: icon)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 96, maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func iconView(for icon: ProcessIcon) -> some View {
        switch icon.kind {
        case .brand(let brand):
            Image(brand.assetName)
                .renderingMode(brand.renderingMode)
                .resizable()
                .scaledToFit()
                .foregroundStyle(brand.color)
                .frame(width: 20, height: 20)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(icon.foreground)
                .frame(width: 20, height: 20)
                .background(icon.background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        case .fileIcon(let image):
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        }
    }
}

private struct ProcessIcon {
    enum Kind {
        case brand(ProcessBrand)
        case symbol(String)
        case fileIcon(NSImage)
    }

    let kind: Kind
    let foreground: Color
    let background: Color

    static func matching(text: String, executablePath: String, isMultiple: Bool) -> ProcessIcon? {
        if isMultiple {
            return ProcessIcon(
                kind: .symbol("square.stack.3d.up.fill"),
                foreground: .indigo,
                background: .indigo.opacity(0.14)
            )
        }

        let normalized = text.lowercased()
        let normalizedPath = executablePath.lowercased()
        let searchableText = "\(normalized) \(normalizedPath)"
        let name = normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
            .first
            .map(String.init) ?? normalized

        if searchableText.contains("orbstack") {
            return ProcessIcon(kind: .brand(.orbstack), foreground: .purple, background: .clear)
        }

        if searchableText.contains("webstorm") {
            return ProcessIcon(kind: .brand(.webstorm), foreground: .cyan, background: .clear)
        }

        if searchableText.contains("intellij") || searchableText.contains("idea") {
            return ProcessIcon(kind: .brand(.intellijidea), foreground: .pink, background: .clear)
        }

        if searchableText.contains("pycharm") {
            return ProcessIcon(kind: .brand(.pycharm), foreground: .green, background: .clear)
        }

        if searchableText.contains("goland") {
            return ProcessIcon(kind: .brand(.goland), foreground: .cyan, background: .clear)
        }

        if searchableText.contains("clion") {
            return ProcessIcon(kind: .brand(.clion), foreground: .teal, background: .clear)
        }

        if searchableText.contains("datagrip") {
            return ProcessIcon(kind: .brand(.datagrip), foreground: .green, background: .clear)
        }

        if searchableText.contains("phpstorm") {
            return ProcessIcon(kind: .brand(.phpstorm), foreground: .purple, background: .clear)
        }

        if searchableText.contains("rubymine") {
            return ProcessIcon(kind: .brand(.rubymine), foreground: .red, background: .clear)
        }

        if searchableText.contains("rider") {
            return ProcessIcon(kind: .brand(.rider), foreground: .orange, background: .clear)
        }

        if searchableText.contains("jetbrains") {
            return ProcessIcon(kind: .brand(.jetbrains), foreground: .pink, background: .clear)
        }

        if searchableText.contains("google chrome") || searchableText.contains("chrome helper") || searchableText.contains("googlechrome") {
            return ProcessIcon(kind: .brand(.googlechrome), foreground: .blue, background: .clear)
        }

        if searchableText.contains("visual studio code") || searchableText.contains("vscode") || searchableText.contains("code helper") {
            return ProcessIcon(kind: .brand(.vscode), foreground: .blue, background: .clear)
        }

        if searchableText.contains("wechat") || searchableText.contains("weixin") {
            return ProcessIcon(kind: .brand(.wechat), foreground: .green, background: .clear)
        }

        if searchableText.contains("google") {
            return ProcessIcon(kind: .brand(.google), foreground: .blue, background: .clear)
        }

        if searchableText.contains("docker") {
            return ProcessIcon(kind: .brand(.docker), foreground: .blue, background: .clear)
        }

        switch name {
        case "node", "nodejs", "npm", "npx", "pnpm", "yarn", "vite", "next", "nextjs":
            return ProcessIcon(kind: .brand(.node), foreground: .green, background: .clear)
        case "go", "gopls", "air":
            return ProcessIcon(kind: .brand(.go), foreground: .cyan, background: .clear)
        case "rust", "rustc", "cargo", "rust-analyzer":
            return ProcessIcon(kind: .brand(.rust), foreground: .orange, background: .clear)
        case "python", "python3", "uv", "pytest", "gunicorn", "uvicorn":
            return ProcessIcon(kind: .brand(.python), foreground: .blue, background: .clear)
        case "ruby", "rails", "bundle":
            return ProcessIcon(kind: .brand(.ruby), foreground: .red, background: .clear)
        case "java", "gradle", "mvn", "kotlin":
            return ProcessIcon(kind: .brand(.java), foreground: .brown, background: .clear)
        case "php", "composer":
            return ProcessIcon(kind: .brand(.php), foreground: .purple, background: .clear)
        case "postgres", "postgresql", "psql":
            return ProcessIcon(kind: .brand(.postgres), foreground: .teal, background: .clear)
        case "redis", "redis-server":
            return ProcessIcon(kind: .brand(.redis), foreground: .red, background: .clear)
        case "mysql", "mysqld":
            return ProcessIcon(kind: .brand(.mysql), foreground: .orange, background: .clear)
        case "code":
            return ProcessIcon(kind: .brand(.vscode), foreground: .blue, background: .clear)
        default:
            if !executablePath.isEmpty, FileManager.default.fileExists(atPath: executablePath) {
                let image = NSWorkspace.shared.icon(forFile: executablePath)
                image.size = NSSize(width: 20, height: 20)
                return ProcessIcon(kind: .fileIcon(image), foreground: .primary, background: .clear)
            }
            return nil
        }
    }

}

private enum ProcessBrand {
    case node
    case go
    case rust
    case python
    case ruby
    case java
    case php
    case docker
    case postgres
    case redis
    case mysql
    case webstorm
    case intellijidea
    case pycharm
    case goland
    case clion
    case datagrip
    case phpstorm
    case rubymine
    case rider
    case jetbrains
    case google
    case googlechrome
    case vscode
    case wechat
    case orbstack

    var assetName: String {
        switch self {
        case .node:
            "ProcessIcons/node"
        case .go:
            "ProcessIcons/go"
        case .rust:
            "ProcessIcons/rust"
        case .python:
            "ProcessIcons/python"
        case .ruby:
            "ProcessIcons/ruby"
        case .java:
            "ProcessIcons/java"
        case .php:
            "ProcessIcons/php"
        case .docker:
            "ProcessIcons/docker"
        case .postgres:
            "ProcessIcons/postgres"
        case .redis:
            "ProcessIcons/redis"
        case .mysql:
            "ProcessIcons/mysql"
        case .webstorm:
            "ProcessIcons/webstorm"
        case .intellijidea:
            "ProcessIcons/intellijidea"
        case .pycharm:
            "ProcessIcons/pycharm"
        case .goland:
            "ProcessIcons/goland"
        case .clion:
            "ProcessIcons/clion"
        case .datagrip:
            "ProcessIcons/datagrip"
        case .phpstorm:
            "ProcessIcons/phpstorm"
        case .rubymine:
            "ProcessIcons/rubymine"
        case .rider:
            "ProcessIcons/rider"
        case .jetbrains:
            "ProcessIcons/jetbrains"
        case .google:
            "ProcessIcons/google"
        case .googlechrome:
            "ProcessIcons/googlechrome"
        case .vscode:
            "ProcessIcons/vscode"
        case .wechat:
            "ProcessIcons/wechat"
        case .orbstack:
            "ProcessIcons/orbstack"
        }
    }

    var color: Color {
        switch self {
        case .node:
            Color(red: 0.34, green: 0.62, blue: 0.19)
        case .go:
            Color(red: 0, green: 0.68, blue: 0.78)
        case .rust:
            Color(red: 0.49, green: 0.27, blue: 0.13)
        case .python:
            Color(red: 0.21, green: 0.43, blue: 0.67)
        case .ruby:
            Color(red: 0.80, green: 0.06, blue: 0.07)
        case .java:
            Color(red: 0.23, green: 0.39, blue: 0.62)
        case .php:
            Color(red: 0.31, green: 0.34, blue: 0.60)
        case .docker:
            Color(red: 0.09, green: 0.51, blue: 0.86)
        case .postgres:
            Color(red: 0.20, green: 0.43, blue: 0.62)
        case .redis:
            Color(red: 0.84, green: 0.10, blue: 0.11)
        case .mysql:
            Color(red: 0.25, green: 0.48, blue: 0.60)
        case .webstorm:
            Color(red: 0, green: 0.74, blue: 0.93)
        case .intellijidea:
            Color(red: 1, green: 0.18, blue: 0.45)
        case .pycharm:
            Color(red: 0.13, green: 0.78, blue: 0.30)
        case .goland:
            Color(red: 0, green: 0.72, blue: 0.83)
        case .clion:
            Color(red: 0, green: 0.74, blue: 0.64)
        case .datagrip:
            Color(red: 0.10, green: 0.78, blue: 0.37)
        case .phpstorm:
            Color(red: 0.58, green: 0.30, blue: 0.96)
        case .rubymine:
            Color(red: 0.87, green: 0.09, blue: 0.22)
        case .rider:
            Color(red: 1, green: 0.45, blue: 0.16)
        case .jetbrains:
            Color(red: 1, green: 0.23, blue: 0.49)
        case .google:
            Color(red: 0.26, green: 0.52, blue: 0.96)
        case .googlechrome:
            Color(red: 0.26, green: 0.52, blue: 0.96)
        case .vscode:
            Color(red: 0, green: 0.48, blue: 0.80)
        case .wechat:
            Color(red: 0.10, green: 0.72, blue: 0.23)
        case .orbstack:
            .primary
        }
    }

    var renderingMode: Image.TemplateRenderingMode {
        switch self {
        case .orbstack:
            .original
        default:
            .template
        }
    }

}

private struct PortUsageGroup: Identifiable, Hashable {
    let port: Int
    let usages: [PortUsage]

    var id: Int { port }
    var hasMultipleUsages: Bool { usages.count > 1 }
    var primaryUsage: PortUsage? { usages.first }

    var protocolsText: String {
        uniqueValues(usages.map(\.protocolName.rawValue)).joined(separator: " / ")
    }

    var processesText: String {
        if let primaryUsage, !hasMultipleUsages {
            return primaryUsage.displayCommand
        }

        let processes = uniqueValues(usages.map(\.displayCommand))
        if processes.count == 1 {
            return processes[0]
        }

        return "\(processes.count) 个进程"
    }

    var pidText: String {
        if let primaryUsage, !hasMultipleUsages {
            return "\(primaryUsage.pid)"
        }

        let pids = uniqueValues(usages.map { "\($0.pid)" })
        if pids.count == 1 {
            return pids[0]
        }

        return "\(pids.count) 项"
    }

    var usersText: String {
        let users = uniqueValues(usages.map(\.user))
        if users.count == 1 {
            return users[0]
        }

        return "\(users.count) 个用户"
    }

    var addressesText: String {
        let addresses = uniqueValues(usages.map(\.address))
        if addresses.count == 1 {
            return addresses[0]
        }

        return "\(addresses.count) 个地址"
    }

    var statesText: String {
        let states = uniqueValues(usages.map { $0.state.isEmpty ? "-" : $0.state })
        return states.joined(separator: " / ")
    }

    var workingDirectoryText: String {
        let dirs = uniqueValues(usages.map(\.workingDirectory).filter { !$0.isEmpty })
        if dirs.isEmpty { return "-" }
        if dirs.count == 1 { return dirs[0] }
        return "\(dirs.count) 个目录"
    }

    private func uniqueValues(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            if !result.contains(value) {
                result.append(value)
            }
        }
    }
}

private enum PortTableRow: Identifiable, Hashable {
    case group(PortUsageGroup)
    case detail(PortUsage, parentPort: Int)

    var id: String {
        switch self {
        case .group(let group):
            Self.groupID(group.port)
        case .detail(let usage, let parentPort):
            "detail-\(parentPort)-\(usage.protocolName.rawValue)-\(usage.pid)-\(usage.address)-\(usage.state)"
        }
    }

    var group: PortUsageGroup? {
        if case .group(let group) = self {
            return group
        }
        return nil
    }

    var usage: PortUsage? {
        switch self {
        case .group(let group):
            group.primaryUsage
        case .detail(let usage, _):
            usage
        }
    }

    var targetUsages: [PortUsage] {
        switch self {
        case .group(let group):
            group.usages
        case .detail(let usage, _):
            [usage]
        }
    }

    var port: Int {
        switch self {
        case .group(let group):
            group.port
        case .detail(_, let parentPort):
            parentPort
        }
    }

    var isDetail: Bool {
        if case .detail = self {
            return true
        }
        return false
    }

    var isMultipleGroup: Bool {
        group?.hasMultipleUsages ?? false
    }

    var protocolText: String {
        switch self {
        case .group(let group):
            group.protocolsText
        case .detail(let usage, _):
            usage.protocolName.rawValue
        }
    }

    var processText: String {
        switch self {
        case .group(let group):
            group.processesText
        case .detail(let usage, _):
            usage.displayCommand
        }
    }

    var executablePath: String {
        switch self {
        case .group(let group):
            group.primaryUsage?.executablePath ?? ""
        case .detail(let usage, _):
            usage.executablePath
        }
    }

    var isProjectRow: Bool {
        usage?.isProjectService ?? false
    }

    var pidText: String {
        switch self {
        case .group(let group):
            group.pidText
        case .detail(let usage, _):
            "\(usage.pid)"
        }
    }

    var userText: String {
        switch self {
        case .group(let group):
            group.usersText
        case .detail(let usage, _):
            usage.user
        }
    }

    var addressText: String {
        switch self {
        case .group(let group):
            group.addressesText
        case .detail(let usage, _):
            usage.address
        }
    }

    var stateText: String {
        switch self {
        case .group(let group):
            group.statesText
        case .detail(let usage, _):
            usage.state.isEmpty ? "-" : usage.state
        }
    }

    var workingDirectoryText: String {
        switch self {
        case .group(let group):
            group.workingDirectoryText
        case .detail(let usage, _):
            usage.workingDirectory.isEmpty ? "-" : usage.workingDirectory
        }
    }

    static func groupID(_ port: Int) -> String {
        "group-\(port)"
    }

    static func port(from rowID: String?) -> Int? {
        guard let rowID else { return nil }

        if rowID.hasPrefix("group-") {
            return Int(rowID.dropFirst("group-".count))
        }

        if rowID.hasPrefix("detail-") {
            let suffix = rowID.dropFirst("detail-".count)
            return Int(suffix.prefix { $0 != "-" })
        }

        return nil
    }
}

private struct ProjectPathCell: View {
    let path: String

    private var shortPath: String {
        let components = path.split(separator: "/")
        guard let last = components.last else { return path }
        return ".../" + last
    }

    var body: some View {
        Button {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        } label: {
            Text(shortPath)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .help(path)
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            } label: {
                Label("拷贝路径", systemImage: "doc.on.doc")
            }
            Button {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            } label: {
                Label("在 Finder 中打开", systemImage: "folder")
            }
        }
    }
}
