import Foundation

enum PortScannerError: LocalizedError {
    case missingOutput
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingOutput:
            "没有收到端口扫描输出。"
        case .commandFailed(let message):
            message.isEmpty ? "端口扫描命令执行失败。" : message
        }
    }
}

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
            return PortScanResult(
                ports: Self.parse(output: output),
                rawLineCount: lines,
                commandDescription: "/usr/sbin/lsof -nP -F pcunPTn -iTCP -sTCP:LISTEN -iUDP"
            )
        }.value
    }

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
