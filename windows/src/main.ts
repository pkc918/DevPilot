import { invoke as tauriInvoke } from "@tauri-apps/api/core";
import { emit, listen } from "@tauri-apps/api/event";
import {
  displayCommand,
  filterPorts,
  groupPorts,
  serverLabel,
  shortPath,
  uniquePids,
  uniqueValues,
  type PortFilters,
  type PortProtocol,
  type PortScope,
  type PortUsage,
} from "./core";

interface PortScanResult {
  ports: PortUsage[];
  rawSocketCount: number;
  diagnosticText: string;
}

interface TerminateResult {
  terminatedPids: number[];
}

interface AppInfo {
  version: string;
  build: string;
  platform: "Windows";
}

interface UpdateStatus {
  currentVersion: string;
  latestVersion: string;
  hasUpdate: boolean;
  releaseUrl: string;
}

interface AutoRefreshChanged {
  enabled: boolean;
}

interface ViewState extends PortFilters {
  ports: PortUsage[];
  scanning: boolean;
  showActivity: boolean;
  error: string;
  lastUpdated: Date | null;
  lastScanStartedAt: number;
  diagnostic: string;
  expanded: Set<number>;
  rowTargets: Map<string, PortUsage[]>;
  pathTargets: Map<string, string>;
  activeContextRow: string | null;
  autoRefresh: boolean;
  releaseUrl: string;
}

interface AggregatedRow {
  protocol: string;
  command: string;
  pid: string;
  address: string;
  state: string;
  path: string;
}

const isTray = new URLSearchParams(window.location.search).get("view") === "tray";
document.body.classList.toggle("tray-view", isTray);

const isTauriRuntime = "__TAURI_INTERNALS__" in window;

const previewPorts: PortUsage[] = [
  {
    id: "TCP-3000-4242-0.0.0.0",
    command: "node",
    pid: 4242,
    user: "rose",
    protocolName: "TCP",
    address: "0.0.0.0",
    port: 3000,
    state: "LISTEN",
    executablePath: "C:\\Program Files\\nodejs\\node.exe",
    workingDirectory: "C:\\Users\\rose\\code\\DevPilot\\web",
    parentCommand: "pnpm",
    isProjectService: true,
  },
  {
    id: "TCP-8080-5310-127.0.0.1",
    command: "main",
    pid: 5310,
    user: "rose",
    protocolName: "TCP",
    address: "127.0.0.1",
    port: 8080,
    state: "LISTEN",
    executablePath: "C:\\Users\\rose\\AppData\\Local\\Temp\\go-build\\main.exe",
    workingDirectory: "C:\\Users\\rose\\code\\api",
    parentCommand: "go",
    isProjectService: true,
  },
  {
    id: "UDP-5353-928-0.0.0.0",
    command: "svchost",
    pid: 928,
    user: "SYSTEM",
    protocolName: "UDP",
    address: "0.0.0.0",
    port: 5353,
    state: "",
    executablePath: "C:\\Windows\\System32\\svchost.exe",
    workingDirectory: "C:\\Windows\\System32",
    parentCommand: "services",
    isProjectService: false,
  },
];

async function invokePreview<T>(command: string, args: Record<string, unknown>): Promise<T> {
  await new Promise((resolve) => setTimeout(resolve, command === "scan_ports" ? 180 : 30));
  const values: Record<string, unknown> = {
    scan_ports: {
      ports: previewPorts,
      rawSocketCount: previewPorts.length,
      diagnosticText: `preview ${previewPorts.length} ports`,
    } satisfies PortScanResult,
    terminate_processes: {
      terminatedPids: (args.pids as number[] | undefined) || [],
    } satisfies TerminateResult,
    get_app_info: { version: "0.1.0", build: "0.1.0", platform: "Windows" } satisfies AppInfo,
    check_for_updates: {
      currentVersion: "0.1.0",
      latestVersion: "0.1.0",
      hasUpdate: false,
      releaseUrl: "https://github.com/pkc918/DevPilot/releases/latest",
    } satisfies UpdateStatus,
  };
  return values[command] as T;
}

const invoke = <T>(command: string, args: Record<string, unknown> = {}): Promise<T> =>
  !isTauriRuntime && import.meta.env.DEV ? invokePreview<T>(command, args) : tauriInvoke<T>(command, args);

const state: ViewState = {
  ports: [],
  scope: "project" satisfies PortScope,
  protocol: "all" satisfies PortProtocol | "all",
  query: "",
  scanning: false,
  showActivity: false,
  error: "",
  lastUpdated: null,
  lastScanStartedAt: 0,
  diagnostic: "尚未执行扫描",
  expanded: new Set<number>(),
  rowTargets: new Map<string, PortUsage[]>(),
  pathTargets: new Map<string, string>(),
  activeContextRow: null,
  autoRefresh: localStorage.getItem("portAutoRefresh") !== "false",
  releaseUrl: "",
};

const $ = <T extends HTMLElement = HTMLElement>(selector: string): T => {
  const element = document.querySelector<T>(selector);
  if (!element) throw new Error(`缺少界面元素：${selector}`);
  return element;
};
const rowsElement = $<HTMLTableSectionElement>("#port-rows");
const tableScroll = $("#table-scroll");
const emptyState = $("#empty-state");
const contextMenu = $("#context-menu");
const settingsModal = $("#settings-modal");
let toastTimer: ReturnType<typeof setTimeout> | undefined;

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function showToast(message: string, kind: "info" | "success" | "error" = "info"): void {
  const toast = $("#toast");
  toast.textContent = message;
  toast.dataset.kind = kind;
  toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    toast.hidden = true;
  }, 3200);
}

function errorMessage(error: unknown): string {
  if (typeof error === "string") return error;
  return error instanceof Error ? error.message : String(error || "未知错误");
}

function eventElement(event: Event): Element | null {
  return event.target instanceof Element ? event.target : null;
}

function processBrand(port: PortUsage): string {
  const haystack = `${displayCommand(port)} ${port.command} ${port.executablePath}`.toLowerCase();
  const brands: ReadonlyArray<readonly [string, string]> = [
    ["visual studio code", "vscode"], ["code.exe", "vscode"], ["vscode", "vscode"],
    ["intellij", "intellijidea"], ["webstorm", "webstorm"], ["phpstorm", "phpstorm"],
    ["pycharm", "pycharm"], ["goland", "goland"], ["rubymine", "rubymine"],
    ["datagrip", "datagrip"], ["clion", "clion"], ["rider", "rider"],
    ["google chrome", "googlechrome"], ["chrome.exe", "googlechrome"],
    ["docker", "docker"], ["orbstack", "orbstack"], ["postgres", "postgres"],
    ["mysql", "mysql"], ["redis", "redis"], ["node", "node"], ["python", "python"],
    ["java", "java"], ["ruby", "ruby"], ["rust", "rust"], ["cargo", "rust"],
    ["golang", "go"], ["go.exe", "go"], ["wechat", "wechat"], ["微信", "wechat"],
  ];
  return brands.find(([needle]) => haystack.includes(needle))?.[1] || "";
}

function processCell(port: PortUsage, text: string, multiple = false): string {
  if (multiple) {
    return `<span class="process-cell"><span class="process-stack">◫</span><span>${escapeHtml(text)}</span></span>`;
  }
  const brand = processBrand(port);
  const icon = brand
    ? `<img src="./process-icons/${brand}.${brand === "orbstack" ? "png" : "svg"}" alt="" />`
    : `<span class="process-fallback">${escapeHtml((text || "?").slice(0, 1).toUpperCase())}</span>`;
  return `<span class="process-cell">${icon}<span title="${escapeHtml(text)}">${escapeHtml(text)}</span></span>`;
}

function pathButton(path: string): string {
  if (!path || path === "-") return `<span class="muted">-</span>`;
  const key = `path-${state.pathTargets.size}`;
  state.pathTargets.set(key, path);
  return `<button class="path-button" type="button" data-path-key="${key}" title="${escapeHtml(path)}">${escapeHtml(shortPath(path))}</button>`;
}

function aggregate(usages: PortUsage[]): AggregatedRow {
  const protocols = uniqueValues(usages.map((port) => port.protocolName));
  const commands = uniqueValues(usages.map(displayCommand));
  const pids = uniqueValues(usages.map((port) => port.pid));
  const addresses = uniqueValues(usages.map((port) => port.address));
  const states = uniqueValues(usages.map((port) => port.state || "-"));
  const paths = uniqueValues(usages.map((port) => port.workingDirectory).filter(Boolean));
  return {
    protocol: protocols.join(" / "),
    command: commands.length === 1 ? commands[0] : `${commands.length} 个进程`,
    pid: pids.length === 1 ? String(pids[0]) : `${pids.length} 项`,
    address: addresses.length === 1 ? addresses[0] : `${addresses.length} 个地址`,
    state: states.join(" / "),
    path: paths.length === 1 ? paths[0] : paths.length ? `${paths.length} 个目录` : "-",
  };
}

function currentPorts(): PortUsage[] {
  return filterPorts(state.ports, state);
}

function rowMarkup(
  usages: PortUsage[],
  { detail = false, groupPort = null }: { detail?: boolean; groupPort?: number | null } = {},
): string {
  const primary = usages[0];
  const multiple = usages.length > 1 && !detail;
  const values = detail
    ? {
        protocol: primary.protocolName,
        command: displayCommand(primary),
        pid: String(primary.pid),
        address: primary.address,
        state: primary.state || "-",
        path: primary.workingDirectory || "-",
      }
    : aggregate(usages);
  const port = groupPort ?? primary.port;
  const key = `row-${state.rowTargets.size}`;
  state.rowTargets.set(key, usages);
  const isExpanded = state.expanded.has(port);
  const disclosure = multiple
    ? `<button type="button" class="disclosure ${isExpanded ? "expanded" : ""}" data-expand-port="${port}" aria-label="展开端口 ${port}">›</button>`
    : "";
  const projectPath = !detail && values.path.includes(" 个目录") ? "-" : values.path;
  return `<tr data-row-key="${key}" class="${detail ? "detail-row" : "group-row"}">
    <td>${disclosure}</td>
    <td class="port-number">${detail ? "" : port.toLocaleString()}</td>
    <td><span class="protocol ${values.protocol === "TCP" ? "tcp" : values.protocol === "UDP" ? "udp" : ""}">${escapeHtml(values.protocol)}</span></td>
    <td>${processCell(primary, values.command, multiple)}</td>
    <td>${primary.isProjectService ? pathButton(projectPath) : '<span class="muted">-</span>'}</td>
    <td class="mono ${multiple ? "muted" : ""}">${escapeHtml(values.pid)}</td>
    <td class="mono address" title="${escapeHtml(values.address)}">${escapeHtml(values.address)}</td>
    <td class="muted">${escapeHtml(values.state)}</td>
  </tr>`;
}

function renderMain(): void {
  if (isTray) return;
  const visiblePorts = currentPorts();
  const groups = groupPorts(visiblePorts);
  state.rowTargets.clear();
  state.pathTargets.clear();

  const html: string[] = [];
  for (const group of groups) {
    html.push(rowMarkup(group.usages));
    if (group.usages.length > 1 && state.expanded.has(group.port)) {
      for (const usage of group.usages) html.push(rowMarkup([usage], { detail: true, groupPort: group.port }));
    }
  }
  rowsElement.innerHTML = html.join("");

  const isEmpty = visiblePorts.length === 0 && !state.scanning;
  emptyState.hidden = !isEmpty;
  tableScroll.hidden = isEmpty;
  $("#empty-title").textContent = state.error
    ? "扫描失败"
    : state.scope === "project"
      ? "没有找到项目服务端口"
      : "没有找到端口占用";
  $("#empty-message").textContent = state.error
    || (state.scope === "project"
      ? "当前默认只显示本机开发服务的 TCP 监听端口。"
      : "尝试刷新，或以管理员身份运行以读取受保护的系统进程。");

  const tcpCount = state.ports.filter((port) => port.protocolName === "TCP").length;
  const udpCount = state.ports.filter((port) => port.protocolName === "UDP").length;
  const processSource = state.scope === "project"
    ? state.ports.filter((port) => port.isProjectService)
    : state.ports;
  $("#tcp-count").textContent = String(tcpCount);
  $("#udp-count").textContent = String(udpCount);
  $("#process-count").textContent = String(new Set(processSource.map((port) => port.pid).filter(Boolean)).size);
  $("#visible-count").textContent = state.showActivity ? "" : String(visiblePorts.length);
  $("#status-label").textContent = state.showActivity ? "正在扫描" : state.error ? "扫描失败" : "已列出";
  $("#status-dot").className = state.error ? "error" : state.showActivity ? "loading" : "ok";
  $("#diagnostic").textContent = `${state.lastUpdated ? state.lastUpdated.toLocaleTimeString() : "尚未刷新"} · ${state.diagnostic}`;
  $("#refresh-button").classList.toggle("spinning", state.showActivity);
  $<HTMLButtonElement>("#refresh-button").disabled = state.scanning;
}

function renderTray(): void {
  if (!isTray) return;
  const projectPorts = state.ports.filter((port) => port.isProjectService);
  $("#tray-title").textContent = projectPorts.length ? `项目服务 ${projectPorts.length}` : "项目服务";
  $("#tray-subtitle").textContent = state.showActivity
    ? "正在扫描"
    : state.error
      ? "扫描失败"
      : projectPorts.length
        ? `${new Set(projectPorts.map((port) => port.pid)).size} 个进程`
        : "没有项目端口";
  $("#tray-refresh").classList.toggle("spinning", state.showActivity);
  $<HTMLButtonElement>("#tray-refresh").disabled = state.scanning;

  const content = $("#tray-content");
  if (state.error) {
    content.innerHTML = `<div class="tray-empty"><strong>扫描失败</strong><span>${escapeHtml(state.error)}</span></div>`;
    return;
  }
  if (!projectPorts.length && !state.scanning) {
    content.innerHTML = '<div class="tray-empty"><strong>没有项目端口</strong><span>当前没有本机项目服务监听端口。</span></div>';
    return;
  }

  state.rowTargets.clear();
  state.pathTargets.clear();
  const rows = projectPorts.slice(0, 8).map((port) => {
    const key = `tray-path-${state.pathTargets.size}`;
    const rowKey = `tray-row-${state.rowTargets.size}`;
    state.pathTargets.set(key, port.workingDirectory);
    state.rowTargets.set(rowKey, [port]);
    const command = displayCommand(port);
    return `<button class="tray-port-row" type="button" data-path-key="${key}" data-row-key="${rowKey}" title="${escapeHtml(port.workingDirectory || "未知项目")}">
      <span class="tray-port-top"><strong>${port.port.toLocaleString()}</strong>${processCell(port, command)}<em>${escapeHtml(serverLabel(port))}</em><i>TCP</i></span>
      <span class="tray-project">▱ ${escapeHtml(shortPath(port.workingDirectory) || "未知项目")}</span>
    </button>`;
  });
  if (projectPorts.length > 8) rows.push(`<div class="tray-more">还有 ${projectPorts.length - 8} 个项目端口</div>`);
  content.innerHTML = rows.join("");
}

function render(): void {
  renderMain();
  renderTray();
}

async function scanPorts(showActivity = true): Promise<void> {
  if (state.scanning) return;
  const now = Date.now();
  if (!showActivity && now - state.lastScanStartedAt < 2500) return;
  state.scanning = true;
  state.showActivity = showActivity;
  state.lastScanStartedAt = now;
  if (showActivity) state.error = "";
  render();
  try {
    const result = await invoke<PortScanResult>("scan_ports");
    state.ports = result.ports;
    state.diagnostic = result.diagnosticText;
    state.lastUpdated = new Date();
    state.error = "";
  } catch (error) {
    state.error = errorMessage(error);
    state.diagnostic = state.error;
  } finally {
    state.scanning = false;
    state.showActivity = false;
    render();
  }
}

async function terminate(usages: PortUsage[]): Promise<void> {
  const pids = uniquePids(usages);
  if (!pids.length) {
    showToast("没有可关闭的进程", "error");
    return;
  }
  hideContextMenu();
  try {
    const result = await invoke<TerminateResult>("terminate_processes", { pids });
    showToast(`已关闭 PID ${result.terminatedPids.join(", ")}`, "success");
    await new Promise((resolve) => setTimeout(resolve, 400));
    await scanPorts(true);
  } catch (error) {
    showToast(errorMessage(error), "error");
  }
}

async function revealPath(path: string | undefined): Promise<void> {
  if (!path || path.includes(" 个目录")) return;
  try {
    await invoke<void>("reveal_in_explorer", { path });
  } catch (error) {
    showToast(errorMessage(error), "error");
  }
}

async function copyPath(path: string | undefined): Promise<void> {
  if (!path || path.includes(" 个目录")) return;
  try {
    await invoke<void>("copy_text", { text: path });
    showToast("已拷贝项目路径", "success");
  } catch (error) {
    showToast(errorMessage(error), "error");
  }
}

function showContextMenu(event: MouseEvent, rowKey: string): void {
  const usages = state.rowTargets.get(rowKey);
  if (!usages) return;
  event.preventDefault();
  state.activeContextRow = rowKey;
  const paths = uniqueValues(usages.map((port) => port.workingDirectory).filter(Boolean));
  const hasSinglePath = paths.length === 1;
  contextMenu.querySelectorAll<HTMLElement>(".path-action").forEach((item) => {
    item.hidden = !hasSinglePath;
  });
  $("#context-close-service span:last-child").textContent = usages.length > 1
    ? "关闭此端口的所有服务"
    : "关闭端口服务";
  contextMenu.hidden = false;
  const rect = contextMenu.getBoundingClientRect();
  contextMenu.style.left = `${Math.min(event.clientX, window.innerWidth - rect.width - 8)}px`;
  contextMenu.style.top = `${Math.min(event.clientY, window.innerHeight - rect.height - 8)}px`;
}

function hideContextMenu(): void {
  contextMenu.hidden = true;
  state.activeContextRow = null;
}

function openSettings(): void {
  settingsModal.hidden = false;
  $<HTMLInputElement>("#auto-refresh-toggle").checked = state.autoRefresh;
  $("#update-result").textContent = "";
  $<HTMLButtonElement>("#check-update").focus();
}

function closeSettings(): void {
  settingsModal.hidden = true;
}

function applyAutoRefresh(enabled: boolean): void {
  state.autoRefresh = enabled;
  localStorage.setItem("portAutoRefresh", String(enabled));
  if (!isTray) {
    $<HTMLInputElement>("#auto-refresh-toggle").checked = enabled;
  }
}

async function loadAppInfo(): Promise<void> {
  try {
    const info = await invoke<AppInfo>("get_app_info");
    $("#sidebar-version").textContent = `v${info.version}`;
    $("#settings-version").textContent = `v${info.version}`;
    $("#settings-build").textContent = info.build;
  } catch {
    // Static browser previews keep the manifest version already present in the HTML.
  }
}

async function checkForUpdates(): Promise<void> {
  const button = $<HTMLButtonElement>("#check-update");
  const resultElement = $("#update-result");
  button.disabled = true;
  resultElement.textContent = "正在检查…";
  try {
    const result = await invoke<UpdateStatus>("check_for_updates");
    state.releaseUrl = result.releaseUrl;
    if (result.hasUpdate) {
      resultElement.innerHTML = `发现 v${escapeHtml(result.latestVersion)} · <button id="open-release" type="button">打开下载页</button>`;
      $("#open-release").addEventListener("click", () => {
        void invoke<void>("open_release_url", { url: state.releaseUrl });
      });
    } else {
      resultElement.textContent = `当前已是最新版本（v${result.currentVersion}）`;
    }
  } catch (error) {
    resultElement.textContent = errorMessage(error);
  } finally {
    button.disabled = false;
  }
}

if (!isTray) {
  $("#search-input").addEventListener("input", (event) => {
    state.query = (event.target as HTMLInputElement).value;
    render();
  });
  $("#refresh-button").addEventListener("click", () => scanPorts(true));
  $("#protocol-filter").addEventListener("click", (event) => {
    const button = eventElement(event)?.closest<HTMLButtonElement>("button[data-value]");
    if (!button) return;
    const protocol = button.dataset.value;
    if (protocol !== "all" && protocol !== "TCP" && protocol !== "UDP") return;
    state.protocol = protocol;
    $("#protocol-filter").querySelectorAll("button").forEach((item) => item.classList.toggle("active", item === button));
    render();
  });
  $("#scope-filter").addEventListener("click", (event) => {
    const button = eventElement(event)?.closest<HTMLButtonElement>("button[data-value]");
    if (!button) return;
    const scope = button.dataset.value;
    if (scope !== "project" && scope !== "all") return;
    state.scope = scope;
    $("#scope-filter").querySelectorAll("button").forEach((item) => item.classList.toggle("active", item === button));
    render();
  });
  rowsElement.addEventListener("click", (event) => {
    const disclosure = eventElement(event)?.closest<HTMLElement>("[data-expand-port]");
    if (disclosure) {
      const port = Number(disclosure.dataset.expandPort);
      state.expanded.has(port) ? state.expanded.delete(port) : state.expanded.add(port);
      render();
      return;
    }
    const path = eventElement(event)?.closest<HTMLElement>("[data-path-key]");
    const pathKey = path?.dataset.pathKey;
    if (pathKey) revealPath(state.pathTargets.get(pathKey));
  });
  rowsElement.addEventListener("contextmenu", (event) => {
    const row = eventElement(event)?.closest<HTMLTableRowElement>("tr[data-row-key]");
    if (row?.dataset.rowKey) showContextMenu(event, row.dataset.rowKey);
  });
  $("#version-button").addEventListener("click", openSettings);
  $("#auto-refresh-toggle").addEventListener("change", (event) => {
    const enabled = (event.target as HTMLInputElement).checked;
    applyAutoRefresh(enabled);
    if (isTauriRuntime) void emit<AutoRefreshChanged>("auto-refresh-changed", { enabled });
  });
  $("#check-update").addEventListener("click", checkForUpdates);
  document.querySelectorAll<HTMLElement>(".modal-close").forEach((button) => button.addEventListener("click", closeSettings));
  settingsModal.addEventListener("mousedown", (event) => {
    if (event.target === settingsModal) closeSettings();
  });
  loadAppInfo();
} else {
  $("#tray-refresh").addEventListener("click", () => scanPorts(true));
  $("#tray-open-main").addEventListener("click", () => {
    void invoke<void>("show_main_window");
  });
  $("#tray-content").addEventListener("click", (event) => {
    const path = eventElement(event)?.closest<HTMLElement>("[data-path-key]");
    const pathKey = path?.dataset.pathKey;
    if (pathKey) revealPath(state.pathTargets.get(pathKey));
  });
  $("#tray-content").addEventListener("contextmenu", (event) => {
    const row = eventElement(event)?.closest<HTMLElement>("[data-row-key]");
    if (row?.dataset.rowKey) showContextMenu(event, row.dataset.rowKey);
  });
}

$("#context-close-service").addEventListener("click", () => {
  const usages = state.activeContextRow ? state.rowTargets.get(state.activeContextRow) : undefined;
  if (usages) terminate(usages);
});
$("#context-copy-path").addEventListener("click", () => {
  const usages = state.activeContextRow ? state.rowTargets.get(state.activeContextRow) || [] : [];
  const path = uniqueValues(usages.map((port) => port.workingDirectory).filter(Boolean))[0];
  hideContextMenu();
  copyPath(path);
});
$("#context-open-path").addEventListener("click", () => {
  const usages = state.activeContextRow ? state.rowTargets.get(state.activeContextRow) || [] : [];
  const path = uniqueValues(usages.map((port) => port.workingDirectory).filter(Boolean))[0];
  hideContextMenu();
  revealPath(path);
});

document.addEventListener("mousedown", (event) => {
  if (!eventElement(event)?.closest("#context-menu")) hideContextMenu();
});
document.addEventListener("keydown", (event) => {
  if (event.ctrlKey && event.key.toLowerCase() === "r") {
    event.preventDefault();
    scanPorts(true);
  }
  if (event.key === "Escape") {
    hideContextMenu();
    if (!settingsModal.hidden) closeSettings();
  }
});

if (isTauriRuntime) {
  void listen("refresh-ports", () => scanPorts(true));
  void listen<AutoRefreshChanged>("auto-refresh-changed", (event) => {
    applyAutoRefresh(event.payload.enabled);
  });
  if (!isTray) void listen("open-settings", openSettings);
}

window.addEventListener("storage", (event) => {
  if (event.key === "portAutoRefresh" && event.newValue !== null) {
    applyAutoRefresh(event.newValue !== "false");
  }
});

setInterval(() => {
  if (state.autoRefresh) scanPorts(false);
}, 3000);

render();
scanPorts(true);
