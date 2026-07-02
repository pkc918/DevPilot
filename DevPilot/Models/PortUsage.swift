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

enum ServiceKind: String {
    case frontend = "前端"
    case backend = "后端"
    case database = "数据"
    case service = "服务"
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

    var endpoint: String {
        "\(address):\(port)"
    }

    var serviceKind: ServiceKind {
        let normalizedCommand = command.lowercased()

        if Self.databaseCommands.contains(where: normalizedCommand.contains) {
            return .database
        }

        if Self.frontendCommands.contains(where: normalizedCommand.contains) {
            return .frontend
        }

        if normalizedCommand.contains("node") {
            return Self.frontendPorts.contains(port) ? .frontend : .backend
        }

        if Self.backendCommands.contains(where: normalizedCommand.contains) {
            return .backend
        }

        return .service
    }

    var isProjectService: Bool {
        protocolName == .tcp
            && state == "LISTEN"
            && isLocalAddress
            && Self.projectCommands.contains { command.lowercased().contains($0) }
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

    private static let frontendPorts: Set<Int> = [
        3000, 3001, 4173, 4200, 5173, 5174, 5175, 5176, 8080
    ]

    private static let frontendCommands = [
        "vite", "next", "nuxt", "astro", "webpack", "rspack", "rsbuild", "parcel", "storybook", "ng"
    ]

    private static let backendCommands = [
        "python", "uvicorn", "gunicorn", "flask", "django", "java", "spring", "go", "air", "php", "ruby", "rails",
        "dotnet", "cargo", "target/debug", "swift", "node"
    ]

    private static let databaseCommands = [
        "redis", "postgres", "postmaster", "mysqld", "mariadbd", "mongod", "clickhouse", "influxd"
    ]

    private static let projectCommands = frontendCommands + backendCommands + databaseCommands + [
        "bun", "deno", "pnpm", "npm", "yarn"
    ]
}

struct ProcessPortSummary: Identifiable {
    let command: String
    let count: Int

    var id: String { command }
}

struct PortScanResult {
    let ports: [PortUsage]
    let rawLineCount: Int
    let commandDescription: String
}
