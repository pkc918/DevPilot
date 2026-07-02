import SwiftUI

struct ContentView: View {
    @StateObject private var store = PortMonitorStore()
    @State private var searchText = ""
    @State private var selectedScope: PortScope = .project
    @State private var selectedProtocol: PortProtocol?
    @State private var selectedPort: PortUsage.ID?

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
            SidebarView(
                store: store,
                selectedScope: selectedScope,
                selectedProtocol: $selectedProtocol
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            PortTableView(
                ports: filteredPorts,
                scope: selectedScope,
                selection: $selectedPort,
                isRefreshing: store.isRefreshing,
                errorMessage: store.errorMessage,
                diagnosticText: store.diagnosticText
            )
        }
        .frame(minWidth: 980, minHeight: 620)
        .searchable(text: $searchText, prompt: "搜索端口、进程、PID、用户或地址")
        .toolbar {
            ToolbarItemGroup {
                Picker("协议", selection: $selectedProtocol) {
                    Text("全部").tag(nil as PortProtocol?)
                    ForEach(PortProtocol.allCases) { item in
                        Text(item.rawValue).tag(item as PortProtocol?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)

                Picker("范围", selection: $selectedScope) {
                    ForEach(PortScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)

                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .task {
            await store.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await store.refresh()
            }
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var store: PortMonitorStore
    let selectedScope: PortScope
    @Binding var selectedProtocol: PortProtocol?

    private var lastUpdatedText: String {
        guard let lastUpdated = store.lastUpdated else {
            return "尚未刷新"
        }

        return lastUpdated.formatted(date: .omitted, time: .standard)
    }

    var body: some View {
        List(selection: $selectedProtocol) {
            Section("概览") {
                ProtocolRow(
                    title: selectedScope == .project ? "项目端口" : "全部端口",
                    value: selectedScope == .project ? store.projectPorts.count : store.ports.count,
                    systemImage: "network",
                    selection: nil
                )
                ProtocolRow(
                    title: "TCP 监听",
                    value: store.tcpCount,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    selection: .tcp
                )
                ProtocolRow(
                    title: "UDP 使用",
                    value: store.udpCount,
                    systemImage: "dot.radiowaves.left.and.right",
                    selection: .udp
                )
            }

            Section("进程") {
                SummaryLine(
                    title: "占用进程",
                    value: "\(selectedScope == .project ? store.projectProcessCount : store.processCount)"
                )

                ForEach(topProcesses) { process in
                    ProcessBarRow(summary: process, maximum: max(topProcesses.first?.count ?? 1, 1))
                }
            }

            Section("状态") {
                SummaryLine(title: "最近刷新", value: lastUpdatedText)
                Text(store.diagnosticText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("端口监控")
    }

    private var topProcesses: [ProcessPortSummary] {
        selectedScope == .project ? store.projectTopProcesses : store.topProcesses
    }
}

private struct ProtocolRow: View {
    let title: String
    let value: Int
    let systemImage: String
    let selection: PortProtocol?

    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .tag(selection)
    }
}

private struct SummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct ProcessBarRow: View {
    let summary: ProcessPortSummary
    let maximum: Int

    private var widthRatio: Double {
        guard maximum > 0 else { return 0 }
        return Double(summary.count) / Double(maximum)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(summary.command)
                    .lineLimit(1)
                Spacer()
                Text(summary.count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.tint)
                            .frame(width: max(4, proxy.size.width * widthRatio))
                    }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 4)
    }
}

private struct PortTableView: View {
    let ports: [PortUsage]
    let scope: PortScope
    @Binding var selection: PortUsage.ID?
    let isRefreshing: Bool
    let errorMessage: String?
    let diagnosticText: String

    var body: some View {
        VStack(spacing: 0) {
            HeaderStrip(
                count: ports.count,
                isRefreshing: isRefreshing,
                errorMessage: errorMessage,
                diagnosticText: diagnosticText
            )

            if ports.isEmpty, !isRefreshing {
                ContentUnavailableView(
                    scope == .project ? "没有找到项目服务端口" : "没有找到端口占用",
                    systemImage: "network.slash",
                    description: Text(scope == .project ? "当前默认只显示常见前端、后端和数据服务的 TCP 监听端口。" : "尝试刷新，或检查应用是否有权限读取本机进程和网络状态。")
                )
            } else {
                Table(ports, selection: $selection) {
                    TableColumn("端口") { item in
                        Text(item.port, format: .number)
                            .monospacedDigit()
                    }
                    .width(min: 70, ideal: 80, max: 100)

                    TableColumn("协议") { item in
                        Text(item.protocolName.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.protocolName == .tcp ? .blue : .orange)
                    }
                    .width(min: 70, ideal: 80, max: 90)

                    TableColumn("类型") { item in
                        Text(item.serviceKind.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(kindColor(item.serviceKind))
                    }
                    .width(min: 70, ideal: 80, max: 100)

                    TableColumn("进程") { item in
                        Text(item.command)
                            .lineLimit(1)
                    }

                    TableColumn("PID") { item in
                        Text(item.pid, format: .number)
                            .monospacedDigit()
                    }
                    .width(min: 70, ideal: 80, max: 100)

                    TableColumn("用户") { item in
                        Text(item.user)
                            .lineLimit(1)
                    }
                    .width(min: 90, ideal: 120, max: 160)

                    TableColumn("地址") { item in
                        Text(item.address)
                            .lineLimit(1)
                            .font(.system(.body, design: .monospaced))
                    }

                    TableColumn("状态") { item in
                        Text(item.state.isEmpty ? "-" : item.state)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 90, ideal: 110, max: 140)
                }
            }
        }
        .navigationTitle("端口使用情况")
    }

    private func kindColor(_ kind: ServiceKind) -> Color {
        switch kind {
        case .frontend:
            .blue
        case .backend:
            .green
        case .database:
            .purple
        case .service:
            .secondary
        }
    }
}

private struct HeaderStrip: View {
    let count: Int
    let isRefreshing: Bool
    let errorMessage: String?
    let diagnosticText: String

    var body: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("正在扫描本机端口")
            } else {
                Image(systemName: errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(errorMessage == nil ? .green : .orange)
                Text(errorMessage ?? "已列出 \(count) 个端口占用")
            }

            Spacer()

            Text("\(diagnosticText) · 每 3 秒自动刷新")
                .foregroundStyle(.tertiary)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
