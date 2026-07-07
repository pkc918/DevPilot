import Foundation
import Darwin

// MARK: - libproc bridge

nonisolated private func commandFromBSDInfo(_ info: proc_bsdshortinfo) -> String {
    var command = info.pbsi_comm
    return withUnsafeBytes(of: &command) { rawBuffer in
        let bytes = rawBuffer.bindMemory(to: CChar.self)
        let utf8Bytes = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8Bytes, as: UTF8.self)
    }
}

// MARK: - CWD resolution via lsof

nonisolated private func resolveCWDsViaLsof(for pids: Set<Int>) -> [Int: String] {
    let sortedPIDs = pids.filter { $0 > 0 }.sorted()
    guard !sortedPIDs.isEmpty else { return [:] }

    var result: [Int: String] = [:]
    let batchSize = 100

    for batchStart in stride(from: 0, to: sortedPIDs.count, by: batchSize) {
        let batch = Array(sortedPIDs[batchStart..<min(batchStart + batchSize, sortedPIDs.count)])
        let pidArg = batch.map(String.init).joined(separator: ",")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-a", "-d", "cwd", "-p", pidArg, "-F", "pn"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { continue }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { continue }

            var currentPID = 0
            for line in output.split(whereSeparator: \.isNewline).map(String.init) {
                guard let marker = line.first else { continue }
                let value = String(line.dropFirst())
                if marker == "p", let pid = Int(value) {
                    currentPID = pid
                } else if marker == "n", currentPID > 0 {
                    result[currentPID] = value
                    currentPID = 0
                }
            }
        } catch {
            continue
        }
    }

    return result
}

// MARK: - Errors

enum PortScannerError: LocalizedError {
    case missingOutput
    case commandFailed(String)
    case terminateFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingOutput:
            "没有收到端口扫描输出。"
        case .commandFailed(let message):
            message.isEmpty ? "端口扫描命令执行失败。" : message
        case .terminateFailed(let message):
            message.isEmpty ? "关闭端口服务失败。" : message
        }
    }
}

// MARK: - Scanner

struct PortScanner {
    func scan() async throws -> PortScanResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-nP", "-F", "pcunPTn", "-iTCP", "-sTCP:LISTEN", "-iUDP"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let message = String(data: errorData, encoding: .utf8) ?? ""
                throw PortScannerError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            guard let output = String(data: outputData, encoding: .utf8) else {
                throw PortScannerError.missingOutput
            }

            let lines = output.split(whereSeparator: \.isNewline).count
            let rawPorts = Self.parse(output: output)
            let pids = Set(rawPorts.map(\.pid))
            let exePaths = Self.resolveExecutablePaths(for: pids)
            let parentCommands = Self.resolveParentCommands(for: pids)

            let ports = rawPorts.map { port in
                PortUsage(
                    command: port.command,
                    pid: port.pid,
                    user: port.user,
                    protocolName: port.protocolName,
                    address: port.address,
                    port: port.port,
                    state: port.state,
                    executablePath: exePaths[port.pid] ?? "",
                    parentCommand: parentCommands[port.pid] ?? ""
                )
            }

            return PortScanResult(
                ports: ports,
                rawLineCount: lines,
                commandDescription: "/usr/sbin/lsof -nP -F pcunPTn -iTCP -sTCP:LISTEN -iUDP"
            )
        }.value
    }

    func enrich(_ ports: [PortUsage]) async -> [PortUsage] {
        let pids = Set(ports.map(\.pid))
        let needsCWD = ports.contains { $0.workingDirectory.isEmpty }
        let needsParent = ports.contains { $0.parentCommand.isEmpty }

        guard needsCWD || needsParent else { return ports }

        return await Task.detached(priority: .background) {
            let cwds = needsCWD ? resolveCWDsViaLsof(for: pids) : [:]
            let parentCommands = needsParent ? Self.resolveParentCommands(for: pids) : [:]

            return ports.map { port in
                PortUsage(
                    command: port.command,
                    pid: port.pid,
                    user: port.user,
                    protocolName: port.protocolName,
                    address: port.address,
                    port: port.port,
                    state: port.state,
                    executablePath: port.executablePath,
                    workingDirectory: cwds[port.pid] ?? port.workingDirectory,
                    parentCommand: parentCommands[port.pid] ?? port.parentCommand
                )
            }
        }.value
    }

    // MARK: - Executable path (fast, via proc_pidpath)

    nonisolated private static func resolveExecutablePaths(for pids: Set<Int>) -> [Int: String] {
        var result: [Int: String] = [:]
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))

        for pid in pids where pid > 0 {
            let len = proc_pidpath(Int32(pid), &buffer, UInt32(MAXPATHLEN))
            if len > 0 {
                result[pid] = String(cString: buffer)
            }
        }

        return result
    }

    func terminateProcesses(pids: [Int]) async throws {
        let uniquePIDs = Array(Set(pids.filter { $0 > 0 })).sorted()
        guard !uniquePIDs.isEmpty else { return }

        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/kill")
            process.arguments = ["-TERM"] + uniquePIDs.map(String.init)

            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: errorData, encoding: .utf8) ?? ""
                throw PortScannerError.terminateFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }.value
    }

    nonisolated private static func resolveParentCommands(for pids: Set<Int>) -> [Int: String] {
        var pidToParentPID: [Int: Int] = [:]
        var uniqueParentPIDs = Set<Int>()
        let infoSize = Int32(MemoryLayout<proc_bsdshortinfo>.size)

        for pid in pids where pid > 0 {
            var info = proc_bsdshortinfo()
            let ret = proc_pidinfo(Int32(pid), PROC_PIDT_SHORTBSDINFO, 0, &info, infoSize)
            guard ret > 0 else { continue }

            let ppid = Int(info.pbsi_ppid)
            guard ppid > 0, ppid != pid else { continue }

            pidToParentPID[pid] = ppid
            uniqueParentPIDs.insert(ppid)
        }

        var parentCommand: [Int: String] = [:]

        for ppid in uniqueParentPIDs {
            var info = proc_bsdshortinfo()
            let ret = proc_pidinfo(Int32(ppid), PROC_PIDT_SHORTBSDINFO, 0, &info, infoSize)
            guard ret > 0 else { continue }

            let name = commandFromBSDInfo(info)
            guard !name.isEmpty else { continue }
            parentCommand[ppid] = name
        }

        var result: [Int: String] = [:]
        for (pid, ppid) in pidToParentPID {
            if let cmd = parentCommand[ppid] {
                result[pid] = cmd
            }
        }

        return result
    }

    // MARK: - lsof output parsing

    nonisolated private static func parse(output: String) -> [PortUsage] {
        var currentPID = 0
        var currentCommand = ""
        var currentUser = ""
        var currentProtocol: PortProtocol?
        var currentState = ""
        var ports: [PortUsage] = []

        func appendEndpoint(_ value: String) {
            guard let currentProtocol,
                  let endpoint = parseEndpoint(value)
            else {
                return
            }

            ports.append(
                PortUsage(
                    command: currentCommand,
                    pid: currentPID,
                    user: currentUser,
                    protocolName: currentProtocol,
                    address: endpoint.address,
                    port: endpoint.port,
                    state: currentState.isEmpty && currentProtocol == .tcp ? "LISTEN" : currentState
                )
            )
        }

        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            guard let marker = line.first else { continue }
            let value = String(line.dropFirst())

            switch marker {
            case "p":
                currentPID = Int(value) ?? 0
                currentProtocol = nil
                currentState = ""
            case "c":
                currentCommand = value
            case "u":
                currentUser = value
            case "P":
                currentProtocol = PortProtocol(rawValue: value)
                currentState = currentProtocol == .udp ? "" : currentState
            case "T":
                if value.hasPrefix("ST=") {
                    currentState = String(value.dropFirst(3))
                }
            case "n":
                appendEndpoint(value)
            default:
                break
            }
        }

        return ports.sorted {
            if $0.port == $1.port {
                return $0.command.localizedStandardCompare($1.command) == .orderedAscending
            }

            return $0.port < $1.port
        }
    }

    nonisolated private static func parseEndpoint(_ text: String) -> (address: String, port: Int)? {
        let endpoint = text.split(separator: "->", maxSplits: 1).first.map(String.init) ?? text
        guard let separatorIndex = endpoint.lastIndex(of: ":"),
              let port = Int(endpoint[endpoint.index(after: separatorIndex)...])
        else {
            return nil
        }

        var address = String(endpoint[..<separatorIndex])
        if address.isEmpty {
            address = "*"
        }

        return (address, port)
    }
}
