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
                || item.user.localizedCaseInsensitiveContains(query)
                || item.address.localizedCaseInsensitiveContains(query)
                || String(item.port).contains(query)
                || String(item.pid).contains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            AppSidebarView(selection: $selectedFeature, store: store)
                .navigationSplitViewColumnWidth(min: 250, ideal: 260, max: 300)
        } detail: {
            ZStack {
                detailView
                    .id(selectedFeature)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .animation(.easeInOut(duration: 0.18), value: selectedFeature)
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(minWidth: 820, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                if selectedFeature == .ports {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .keyboardShortcut("r", modifiers: [.command])
                }
            }
        }
        .task {
            await store.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if portAutoRefresh {
                    await store.refresh(showActivity: false)
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
        case .gitAccounts:
            GitAccountsWorkspace()
        }
    }
}

private enum AppFeature: String, CaseIterable, Identifiable {
    case ports
    case gitAccounts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ports:
            "Port"
        case .gitAccounts:
            "Git"
        }
    }

    var subtitle: String {
        switch self {
        case .ports:
            "端口与进程"
        case .gitAccounts:
            "身份配置"
        }
    }

    var systemImage: String {
        switch self {
        case .ports:
            "network"
        case .gitAccounts:
            "person.2.badge.gearshape"
        }
    }
}

private struct AppSidebarView: View {
    @Binding var selection: AppFeature
    @ObservedObject var store: PortMonitorStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("概览") {
                    SidebarOverviewLine(
                        title: "活动模块",
                        value: "\(AppFeature.allCases.count)",
                        systemImage: "square.grid.2x2"
                    )
                    SidebarOverviewLine(
                        title: "项目端口",
                        value: "\(store.projectPorts.count)",
                        systemImage: "network"
                    )
                    SidebarOverviewLine(
                        title: "占用进程",
                        value: "\(store.projectProcessCount)",
                        systemImage: "cpu"
                    )
                }

                Section("Tools") {
                    ForEach(AppFeature.allCases) { feature in
                        AppSidebarRow(feature: feature)
                            .tag(feature)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .navigationTitle("DevPilot")
    }
}

private struct SidebarOverviewLine: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

private struct AppSidebarRow: View {
    let feature: AppFeature

    var body: some View {
        Label {
            HStack(spacing: 6) {
                Text(feature.title)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: feature.systemImage)
        }
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
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $searchText, prompt: "搜索端口、进程、PID、用户或地址")
    }
}

private struct PortHeaderView: View {
    @ObservedObject var store: PortMonitorStore
    let visibleCount: Int
    let selectedScope: PortScope
    @Binding var selectedScopeBinding: PortScope
    @Binding var selectedProtocol: PortProtocol?

    private var lastUpdatedText: String {
        guard let lastUpdated = store.lastUpdated else {
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

                Text("\(lastUpdatedText) · \(store.diagnosticText)")
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

private struct GitAccountsWorkspace: View {
    var body: some View {
        ContentUnavailableView(
            "Git",
            systemImage: "person.2.badge.gearshape",
            description: Text("多用户配置模块")
        )
        .navigationTitle("Git")
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

private struct PortTableView: View {
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
                    .width(min: 120, ideal: 170, max: 240)
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
                    .width(min: 240, ideal: 380, max: 700)
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
            return .blue
        }
        if text == PortProtocol.udp.rawValue {
            return .orange
        }
        return .secondary
    }

    private func kindColor(_ text: String) -> Color {
        if text == ServiceKind.frontend.rawValue {
            return .blue
        }
        if text == ServiceKind.backend.rawValue {
            return .green
        }
        if text == ServiceKind.database.rawValue {
            return .purple
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

    var kindsText: String {
        uniqueValues(usages.map { $0.serviceKind.rawValue }).joined(separator: " / ")
    }

    var processesText: String {
        if let primaryUsage, !hasMultipleUsages {
            return primaryUsage.command
        }

        let processes = uniqueValues(usages.map(\.command))
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

    var kindText: String {
        switch self {
        case .group(let group):
            group.kindsText
        case .detail(let usage, _):
            usage.serviceKind.rawValue
        }
    }

    var processText: String {
        switch self {
        case .group(let group):
            group.processesText
        case .detail(let usage, _):
            usage.command
        }
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
