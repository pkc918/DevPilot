import Foundation
import Combine

final class PortMonitorStore: ObservableObject {
    @Published var ports: [PortUsage] = []
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var diagnosticText = "尚未执行扫描"

    private let scanner = PortScanner()
    private var isScanning = false

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

    func refresh(showActivity: Bool = true) async {
        guard !isScanning else { return }

        isScanning = true
        if showActivity {
            isRefreshing = true
            errorMessage = nil
        }

        do {
            let result = try await scanner.scan()
            let nextDiagnosticText = "raw \(result.rawLineCount) lines, parsed \(result.ports.count) ports"
            let hasPortChanges = result.ports != ports

            if showActivity || hasPortChanges || errorMessage != nil {
                ports = result.ports
                lastUpdated = Date()
                diagnosticText = nextDiagnosticText
                errorMessage = nil
            }
        } catch {
            if showActivity || errorMessage != error.localizedDescription {
                errorMessage = error.localizedDescription
                diagnosticText = error.localizedDescription
            }
        }

        if showActivity {
            isRefreshing = false
        }
        isScanning = false
    }

    func closePortServices(_ usages: [PortUsage]) async {
        guard !isScanning else { return }

        let pids = Array(Set(usages.map(\.pid))).sorted()
        guard !pids.isEmpty else { return }

        isScanning = true
        isRefreshing = true
        errorMessage = nil

        do {
            try await scanner.terminateProcesses(pids: pids)
            try? await Task.sleep(for: .milliseconds(400))
            isScanning = false
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            diagnosticText = error.localizedDescription
            isRefreshing = false
            isScanning = false
        }
    }
}
