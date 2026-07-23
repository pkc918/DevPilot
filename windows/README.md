# DevPilot for Windows

基于 Tauri 2 的 Windows 桌面端，与 `macos/` 版本保持相同的端口监控工作流：

- 系统托盘点击后速览最多 8 个项目服务；
- 项目服务 / 全部端口、TCP / UDP 分段筛选；
- 按端口聚合，多进程或多地址占用可展开；
- 搜索端口、进程、父进程、PID、用户、地址与项目路径；
- 读取进程可执行文件、父进程与工作目录，识别本机开发服务；
- 主窗口和托盘弹层中的项目路径均可复制或在 Windows 资源管理器中打开；
- 右键端口可关闭单个进程或同端口的全部进程，托盘弹层也支持同样的快捷菜单；
- 默认每 3 秒自动刷新，可在设置中关闭并同步到主窗口与托盘弹层，`Ctrl+R` 手动刷新；
- 从 GitHub Releases 检查新版本。

## 技术实现

- Tauri 2 + Vite + TypeScript（严格类型检查，端口与命令返回值均有显式模型）；
- Rust `netstat2` 调用 Windows IP Helper API 枚举 TCP/UDP 端点，不依赖本地化的 `netstat` 输出；
- Rust `sysinfo` 获取进程名、所有者、父进程、可执行路径和当前工作目录；
- Windows `taskkill` 终止进程树，普通终止失败时回退到强制终止；
- Tauri 双 WebView：主窗口与无边框托盘弹层共享同一套数据模型和界面代码。
- Windows CI 会启动真实 TCP fixture，验证端口/PID/工作目录解析、项目服务分类和进程终止后再生成安装包。

## 开发环境

要求：

- Windows 10 1803+ 或 Windows 11；
- Rust 1.88+ MSVC toolchain；
- Microsoft C++ Build Tools 与 WebView2；
- Node.js 20.19+（运行 Vite、TypeScript、Vitest 与 Tauri CLI）。

```powershell
cd windows
npm install
npm test
npm run typecheck
npm run dev
```

## 构建安装包

```powershell
cd windows
npm ci
npm run build
```

产物位于 `src-tauri/target/release/bundle/`，配置同时生成 NSIS `.exe` 与 WiX `.msi` 安装包。默认使用当前用户安装模式，不要求管理员权限。

在非 Windows 宿主上只检查 Windows 条件编译分支（不生成资源或安装包）可使用：

```bash
DEVPILOT_CROSS_CHECK=1 cargo check --manifest-path src-tauri/Cargo.toml --target x86_64-pc-windows-msvc
```

本机也可对已启动的测试监听器运行同一后端冒烟测试：

```bash
cargo run --release --manifest-path src-tauri/Cargo.toml --bin devpilot-self-test -- --port 43191 --terminate
```

## 权限说明

普通权限可以完整管理当前用户启动的开发服务。Windows 对部分系统进程和其他用户进程会隐藏工作目录或拒绝终止；需要查看/关闭这些受保护端口时，可选择“以管理员身份运行”。应用不会主动请求提权。

项目服务的 Windows 分类规则与 macOS 版语义一致：仅包含本地地址上的 TCP `LISTEN`、属于当前用户、且工作目录或可执行文件不位于 Windows/Program Files/ProgramData/AppData 系统应用区域的进程。Node 等安装在 Program Files 中、但工作目录位于项目路径的开发服务仍会正确显示。
