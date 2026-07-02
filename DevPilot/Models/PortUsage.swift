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

    nonisolated init(
        command: String,
        pid: Int,
        user: String,
        protocolName: PortProtocol,
        address: String,
        port: Int,
        state: String
    ) {
        self.command = command
        self.pid = pid
        self.user = user
        self.protocolName = protocolName
        self.address = address
        self.port = port
        self.state = state
        self.id = "\(protocolName.rawValue)-\(port)-\(pid)-\(address)"
    }

    var isProjectService: Bool {
        protocolName == .tcp
            && state == "LISTEN"
            && isLocalAddress
            && isOwnedByCurrentUser
            && isDevelopmentServerProcess
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

    private var isDevelopmentServerProcess: Bool {
        let normalizedCommand = command.lowercased()
        return Self.developmentServerCommands.contains { normalizedCommand.contains($0) }
    }

    private static let developmentServerCommands = [
        "node", "bun", "deno", "npm", "pnpm", "yarn",
        "vite", "next", "nuxt", "astro", "webpack", "rspack", "rsbuild", "parcel", "storybook",
        "python", "uvicorn", "gunicorn", "flask", "django",
        "java", "spring", "go", "air", "php", "ruby", "rails", "dotnet", "cargo", "swift",
        "redis", "postgres", "postmaster", "mysqld", "mariadbd", "mongod", "clickhouse", "influxd"
    ]
}

struct PortScanResult {
    let ports: [PortUsage]
    let rawLineCount: Int
    let commandDescription: String
}
