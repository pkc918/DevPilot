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
    private var enrichTask: Task<Void, Never>?

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

    func refresh(showActivity: Bool = true) async {
        guard !isScanning else { return }

        isScanning = true
        if showActivity {
            isRefreshing = true
            errorMessage = nil
        }

        do {
            let result = try await scanner.scan()

            lastUpdated = Date()
            let coreFields = ports.map(\.coreFields)
            let hasChanges = result.ports.map(\.coreFields) != coreFields
            if hasChanges || showActivity || errorMessage != nil {
                ports = result.ports
                diagnosticText = "raw \(result.rawLineCount) lines, parsed \(result.ports.count) ports"
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

        scheduleEnrich(for: ports)
    }

    private func scheduleEnrich(for currentPorts: [PortUsage]) {
        enrichTask?.cancel()
        guard !currentPorts.isEmpty else { return }

        let capture = currentPorts
        enrichTask = Task(priority: .background) { [weak self] in
            guard let self else { return }
            let enriched = await self.scanner.enrich(capture)
            guard !Task.isCancelled else { return }
            if enriched != self.ports {
                self.ports = enriched
            }
        }
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
