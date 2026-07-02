import Darwin
import Foundation

enum PortProtocol: String, CaseIterable, Identifiable {
    case tcp = "TCP"
    case udp = "UDP"

    var id: String { rawValue }
}

enum PortScope: String, CaseIterable, Identifiable {
    case project = "项目服务"
    case all = "全部端口"

    var id: String { rawValue }
}

struct PortUsage: Identifiable, Hashable {
    let id: String
    let command: String
    let pid: Int
    let user: String
    let protocolName: PortProtocol
    let address: String
    let port: Int
    let state: String
    let executablePath: String
    let workingDirectory: String
    let parentCommand: String

    nonisolated init(
        command: String,
        pid: Int,
        user: String,
        protocolName: PortProtocol,
        address: String,
        port: Int,
        state: String,
        executablePath: String = "",
        workingDirectory: String = "",
        parentCommand: String = ""
    ) {
        self.command = command
        self.pid = pid
        self.user = user
        self.protocolName = protocolName
        self.address = address
        self.port = port
        self.state = state
        self.executablePath = executablePath
        self.workingDirectory = workingDirectory
        self.parentCommand = parentCommand
        self.id = "\(protocolName.rawValue)-\(port)-\(pid)-\(address)"
    }

    var coreFields: PortUsage {
        PortUsage(
            command: command, pid: pid, user: user,
            protocolName: protocolName, address: address,
            port: port, state: state, executablePath: executablePath
        )
    }

    var displayCommand: String {
        if isProjectService, !parentCommand.isEmpty, parentCommand != command, !isShell(parentCommand) {
            return parentCommand
        }
        return command
    }

    var shortProjectPath: String {
        guard !workingDirectory.isEmpty else { return "" }
        let components = workingDirectory.split(separator: "/")
        guard let last = components.last else { return workingDirectory }
        return ".../" + last
    }

    private func isShell(_ cmd: String) -> Bool {
        let shells: Set<String> = ["bash", "zsh", "fish", "sh", "dash", "tcsh", "ksh", "csh"]
        return shells.contains(cmd.lowercased())
    }

    var isProjectService: Bool {
        protocolName == .tcp
            && state == "LISTEN"
            && isLocalAddress
            && isOwnedByCurrentUser
            && isUserExecutable
    }

    private var isLocalAddress: Bool {
        address == "*"
            || address == "0.0.0.0"
            || address == "::"
            || address == "[::]"
            || address == "[::1]"
            || address == "::1"
            || address.hasPrefix("127.")
            || address.localizedCaseInsensitiveContains("localhost")
    }

    private var isOwnedByCurrentUser: Bool {
        user == String(getuid())
            || user == NSUserName()
            || user == ProcessInfo.processInfo.userName
    }

    private var isUserExecutable: Bool {
        if executablePath.isEmpty {
            return isOwnedByCurrentUser
        }

        let appPrefixes = [
            "/Applications/", "\(NSHomeDirectory())/Applications/"
        ]

        if appPrefixes.contains(where: { executablePath.hasPrefix($0) }) {
            return false
        }

        let systemPrefixes = [
            "/usr/sbin/", "/usr/libexec/", "/System/Library/",
            "/sbin/", "/Library/Apple/"
        ]

        return !systemPrefixes.contains { executablePath.hasPrefix($0) }
    }
}

struct PortScanResult {
    let ports: [PortUsage]
    let rawLineCount: Int
    let commandDescription: String
}
