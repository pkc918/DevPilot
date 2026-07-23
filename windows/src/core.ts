export type PortProtocol = "TCP" | "UDP";
export type PortScope = "project" | "all";

export interface PortUsage {
  id: string;
  command: string;
  pid: number;
  user: string;
  protocolName: PortProtocol;
  address: string;
  port: number;
  state: string;
  executablePath: string;
  workingDirectory: string;
  parentCommand: string;
  isProjectService: boolean;
}

export interface PortFilters {
  scope: PortScope;
  protocol: PortProtocol | "all";
  query: string;
}

export interface PortGroup {
  port: number;
  usages: PortUsage[];
}

const SHELLS = new Set([
  "bash",
  "zsh",
  "fish",
  "sh",
  "dash",
  "tcsh",
  "ksh",
  "csh",
  "cmd",
  "cmd.exe",
  "powershell",
  "powershell.exe",
  "pwsh",
  "pwsh.exe",
]);

export function displayCommand(port: PortUsage): string {
  const parent = (port.parentCommand || "").trim();
  const command = (port.command || "").trim();
  if (
    port.isProjectService &&
    parent &&
    parent.toLowerCase() !== command.toLowerCase() &&
    !SHELLS.has(parent.toLowerCase())
  ) {
    return parent;
  }
  return command || "-";
}

export function shortPath(path: string): string {
  if (!path) return "";
  const parts = path.split(/[\\/]+/).filter(Boolean);
  return parts.length ? `…/${parts.at(-1)}` : path;
}

export function serverLabel(port: PortUsage): string {
  let host = port.address;
  if (["0.0.0.0", "::", "[::]", "*"].includes(host)) host = "localhost";
  if (["::1", "[::1]"].includes(host)) host = "127.0.0.1";
  return `${host}:${port.port}`;
}

export function filterPorts(ports: PortUsage[], filters: PortFilters): PortUsage[] {
  const search = filters.query.trim().toLocaleLowerCase();
  return ports.filter((port) => {
    if (filters.scope === "project" && !port.isProjectService) return false;
    if (filters.protocol !== "all" && port.protocolName !== filters.protocol) return false;
    if (!search) return true;
    return [
      port.command,
      port.parentCommand,
      port.user,
      port.address,
      port.workingDirectory,
      String(port.port),
      String(port.pid),
    ].some((value) => (value || "").toLocaleLowerCase().includes(search));
  });
}

export function groupPorts(ports: PortUsage[]): PortGroup[] {
  const byPort = new Map<number, PortUsage[]>();
  for (const port of ports) {
    const group = byPort.get(port.port) || [];
    group.push(port);
    byPort.set(port.port, group);
  }
  return [...byPort.entries()]
    .sort(([left], [right]) => left - right)
    .map(([port, usages]) => ({ port, usages }));
}

export function uniqueValues<T>(values: T[]): T[] {
  return [...new Set(values.filter((value) => value !== undefined && value !== null))];
}

export function uniquePids(usages: PortUsage[]): number[] {
  return uniqueValues(usages.map((usage) => usage.pid).filter((pid) => pid > 0)).sort(
    (left, right) => left - right,
  );
}

export function compareVersions(left: string, right: string): -1 | 0 | 1 {
  const parse = (version: string): number[] =>
    version
      .replace(/^[vV]/, "")
      .split(".")
      .map((part) => Number.parseInt(part.match(/^\d+/)?.[0] || "0", 10));
  const a = parse(left);
  const b = parse(right);
  for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
    const delta = (a[index] || 0) - (b[index] || 0);
    if (delta !== 0) return delta > 0 ? 1 : -1;
  }
  return 0;
}
