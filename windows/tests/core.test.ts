import { describe, expect, it } from "vitest";
import {
  compareVersions,
  displayCommand,
  filterPorts,
  groupPorts,
  serverLabel,
  shortPath,
  uniquePids,
  type PortUsage,
} from "../src/core";

const ports: PortUsage[] = [
  {
    id: "TCP-3000-42-0.0.0.0",
    command: "main",
    parentCommand: "go",
    pid: 42,
    user: "rose",
    protocolName: "TCP",
    address: "0.0.0.0",
    port: 3000,
    state: "LISTEN",
    executablePath: "C:\\Users\\rose\\AppData\\Local\\Temp\\go-build\\main.exe",
    workingDirectory: "C:\\Users\\rose\\code\\api",
    isProjectService: true,
  },
  {
    id: "TCP-3000-43-127.0.0.1",
    command: "node",
    parentCommand: "pwsh",
    pid: 43,
    user: "rose",
    protocolName: "TCP",
    address: "127.0.0.1",
    port: 3000,
    state: "LISTEN",
    executablePath: "C:\\Program Files\\nodejs\\node.exe",
    workingDirectory: "C:\\Users\\rose\\code\\web",
    isProjectService: true,
  },
  {
    id: "UDP-5353-100-0.0.0.0",
    command: "svchost",
    parentCommand: "services",
    pid: 100,
    user: "SYSTEM",
    protocolName: "UDP",
    address: "0.0.0.0",
    port: 5353,
    state: "",
    executablePath: "C:\\Windows\\System32\\svchost.exe",
    workingDirectory: "C:\\Windows\\System32",
    isProjectService: false,
  },
];

describe("port view model", () => {
  it("composes project scope, protocol and search filters", () => {
    expect(filterPorts(ports, { scope: "project", protocol: "all", query: "" })).toHaveLength(2);
    expect(filterPorts(ports, { scope: "all", protocol: "UDP", query: "" })).toHaveLength(1);
    expect(filterPorts(ports, { scope: "project", protocol: "TCP", query: "web" }).map((port) => port.pid)).toEqual([43]);
    expect(filterPorts(ports, { scope: "all", protocol: "all", query: "5353" })[0].command).toBe("svchost");
  });

  it("groups same-port usages and deduplicates termination PIDs", () => {
    const groups = groupPorts(ports);
    expect(groups[0].port).toBe(3000);
    expect(groups[0].usages).toHaveLength(2);
    expect(uniquePids([ports[0], ports[0], ports[1]])).toEqual([42, 43]);
  });

  it("traces parent processes but ignores shells", () => {
    expect(displayCommand(ports[0])).toBe("go");
    expect(displayCommand(ports[1])).toBe("node");
  });

  it("formats Windows paths and wildcard listeners", () => {
    expect(shortPath("C:\\Users\\rose\\code\\api")).toBe("…/api");
    expect(serverLabel(ports[0])).toBe("localhost:3000");
  });

  it("compares versions numerically", () => {
    expect(compareVersions("1.10.0", "1.9.9")).toBe(1);
    expect(compareVersions("v2.0.0", "2.0.0")).toBe(0);
    expect(compareVersions("0.9.0", "1.0.0")).toBe(-1);
  });
});
