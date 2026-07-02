import Foundation
import Combine

final class PortMonitorStore: ObservableObject {
    @Published var ports: [PortUsage] = []
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var diagnosticText = "尚未执行扫描"

    private let scanner = PortScanner()

    var projectPorts: [PortUsage] {
        ports.filter(\.isProjectService)
    }

    var tcpCount: Int {
        ports.filter { $0.protocolName == .tcp }.count
    }

    var udpCount: Int {
        ports.filter { $0.protocolName == .udp }.count
    }

    var processCount: Int {
        Set(ports.map(\.pid)).count
    }

    var projectProcessCount: Int {
        Set(projectPorts.map(\.pid)).count
    }

    var topProcesses: [ProcessPortSummary] {
        topProcesses(in: ports)
    }

    var projectTopProcesses: [ProcessPortSummary] {
        topProcesses(in: projectPorts)
    }

    private func topProcesses(in ports: [PortUsage]) -> [ProcessPortSummary] {
        Dictionary(grouping: ports, by: \.command)
            .map { ProcessPortSummary(command: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.command.localizedStandardCompare($1.command) == .orderedAscending
                }

                return $0.count > $1.count
            }
            .prefix(8)
            .map { $0 }
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        do {
            let result = try await scanner.scan()
            ports = result.ports
            lastUpdated = Date()
            diagnosticText = "raw \(result.rawLineCount) lines, parsed \(result.ports.count) ports"
        } catch {
            errorMessage = error.localizedDescription
            diagnosticText = error.localizedDescription
        }

        isRefreshing = false
    }
}
