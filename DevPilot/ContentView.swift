import SwiftUI

struct ContentView: View {
    @ObservedObject private var store: PortMonitorStore
    @AppStorage("portAutoRefresh") private var portAutoRefresh = true
    @State private var selectedFeature: AppFeature = .ports
    @State private var searchText = ""
    @State private var selectedScope: PortScope = .project
    @State private var selectedProtocol: PortProtocol?
    @State private var selectedPort: Int?

    init(store: PortMonitorStore = PortMonitorStore()) {
        self.store = store
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
            AppSidebarView(selection: $selectedFeature)
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

    var body: some View {
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
                        centeredText(row.processText)
                            .lineLimit(1)
                            .foregroundStyle(row.isDetail ? .secondary : .primary)
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

    private func centeredText(_ text: String) -> some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .center)
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
