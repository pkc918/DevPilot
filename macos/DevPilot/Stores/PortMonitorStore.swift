import Foundation
import Combine

@MainActor
final class PortRefreshMetadata: ObservableObject {
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var diagnosticText = "尚未执行扫描"

    func update(lastUpdated: Date, diagnosticText: String) {
        self.lastUpdated = lastUpdated
        if self.diagnosticText != diagnosticText {
            self.diagnosticText = diagnosticText
        }
    }

    func updateDiagnosticText(_ diagnosticText: String) {
        guard self.diagnosticText != diagnosticText else { return }
        self.diagnosticText = diagnosticText
    }
}

@MainActor
final class PortMonitorStore: ObservableObject {
    @Published var ports: [PortUsage] = []
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    let metadata = PortRefreshMetadata()
    private(set) var projectPorts: [PortUsage] = []
    private(set) var tcpCount = 0
    private(set) var udpCount = 0
    private(set) var processCount = 0
    private(set) var projectProcessCount = 0

    private let scanner = PortScanner()
    private var isScanning = false
    private var enrichTask: Task<Void, Never>?
    private var latestPorts: [PortUsage] = []
    private var lastScanDate: Date?

    func publishLatestPortsIfNeeded() {
        guard visibleFields(ports, scope: .all) != visibleFields(latestPorts, scope: .all) else {
            return
        }

        publishPorts(latestPorts)
    }

    func refresh(
        showActivity: Bool = true,
        visibleScope: PortScope? = nil,
        minimumInterval: TimeInterval? = nil
    ) async {
        guard !isScanning else { return }
        if let minimumInterval,
           let lastScanDate,
           Date().timeIntervalSince(lastScanDate) < minimumInterval {
            return
        }

        isScanning = true
        if showActivity {
            setRefreshing(true)
            setErrorMessage(nil)
        }

        var shouldEnrichLatestPorts = false

        do {
            let result = try await scanner.scan()
            lastScanDate = Date()

            let rawChanged = scanIdentityFields(latestPorts, scope: .all) != scanIdentityFields(result.ports, scope: .all)
            let candidatePorts = rawChanged ? result.ports : latestPorts
            let visibleChanged = hasVisibleChanges(from: ports, to: candidatePorts, visibleScope: visibleScope)
            shouldEnrichLatestPorts = visibleChanged

            if rawChanged {
                latestPorts = result.ports
            }

            let resolvedError = errorMessage
            publishScanMetadata(
                rawLineCount: result.rawLineCount,
                portCount: result.ports.count
            )
            if visibleChanged {
                setErrorMessage(nil)
                publishPorts(candidatePorts)
            } else if resolvedError != nil {
                setErrorMessage(nil)
            }

        } catch {
            if showActivity || errorMessage != error.localizedDescription {
                setDiagnosticText(error.localizedDescription)
                setErrorMessage(error.localizedDescription)
            }
        }

        if showActivity {
            setRefreshing(false)
        }
        isScanning = false

        let needsEnrich = latestPorts.contains { $0.workingDirectory.isEmpty }
        guard shouldEnrichLatestPorts else { return }
        guard needsEnrich else { return }

        enrichTask?.cancel()
        let capture = latestPorts
        let scope = visibleScope
        enrichTask = Task(priority: .background) { [weak self] in
            guard let self else { return }
            let enriched = await self.scanner.enrich(capture)
            guard !Task.isCancelled else { return }

            let shouldPublish = self.hasVisibleChanges(from: self.ports, to: enriched, visibleScope: scope)
            self.latestPorts = enriched

            if shouldPublish {
                self.publishPorts(enriched)
            }
        }
    }

    func closePortServices(_ usages: [PortUsage]) async {
        guard !isScanning else { return }

        let pids = Array(Set(usages.map(\.pid))).sorted()
        guard !pids.isEmpty else { return }

        isScanning = true
        setRefreshing(true)
        setErrorMessage(nil)

        do {
            try await scanner.terminateProcesses(pids: pids)
            try? await Task.sleep(for: .milliseconds(400))
            isScanning = false
            await refresh()
        } catch {
            setDiagnosticText(error.localizedDescription)
            setErrorMessage(error.localizedDescription)
            setRefreshing(false)
            isScanning = false
        }
    }

    private func publishPorts(_ ports: [PortUsage]) {
        guard visibleFields(self.ports, scope: .all) != visibleFields(ports, scope: .all) else {
            return
        }

        refreshDerivedPortData(from: ports)
        self.ports = ports
    }

    private func publishScanMetadata(rawLineCount: Int, portCount: Int) {
        metadata.update(
            lastUpdated: Date(),
            diagnosticText: "raw \(rawLineCount) lines, parsed \(portCount) ports"
        )
    }

    private func setRefreshing(_ value: Bool) {
        guard isRefreshing != value else { return }
        isRefreshing = value
    }

    private func setErrorMessage(_ value: String?) {
        guard errorMessage != value else { return }
        errorMessage = value
    }

    private func setDiagnosticText(_ value: String) {
        metadata.updateDiagnosticText(value)
    }

    private func hasVisibleChanges(
        from oldPorts: [PortUsage],
        to newPorts: [PortUsage],
        visibleScope: PortScope?
    ) -> Bool {
        switch visibleScope {
        case .project:
            visibleFields(oldPorts, scope: .project) != visibleFields(newPorts, scope: .project)
        case .all:
            visibleFields(oldPorts, scope: .all) != visibleFields(newPorts, scope: .all)
        case nil:
            visibleFields(oldPorts, scope: .all) != visibleFields(newPorts, scope: .all)
        }
    }

    private func scanIdentityFields(_ ports: [PortUsage], scope: PortScope) -> [PortUsage] {
        switch scope {
        case .project:
            ports.filter(\.isProjectService).map(\.scanIdentityFields)
        case .all:
            ports.map(\.scanIdentityFields)
        }
    }

    private func visibleFields(_ ports: [PortUsage], scope: PortScope) -> [PortUsage] {
        switch scope {
        case .project:
            ports.filter(\.isProjectService).map(\.visibleFields)
        case .all:
            ports.map(\.visibleFields)
        }
    }

    private func refreshDerivedPortData(from ports: [PortUsage]) {
        projectPorts = ports.filter(\.isProjectService)
        tcpCount = ports.reduce(0) { $0 + ($1.protocolName == .tcp ? 1 : 0) }
        udpCount = ports.reduce(0) { $0 + ($1.protocolName == .udp ? 1 : 0) }
        processCount = Set(ports.map(\.pid)).count
        projectProcessCount = Set(projectPorts.map(\.pid)).count
    }
}
