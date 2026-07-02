# DevPilot

macOS 菜单栏端口监控工具。自动发现本机开发服务端口，不用记 `lsof -iTCP -sTCP:LISTEN` 也不用背 `kill` PID —— 看一眼菜单栏就知道哪些服务在跑、跑在哪个项目目录，一键就能关掉。AI 跑完项目残留一堆端口也不怕，菜单栏直接关，不用回命令行查。

<img src="assets/product.png" alt="DevPilot 截图" width="800">

## 功能

- **自动发现项目端口** — 自动识别当前用户启动的开发服务（TCP LISTEN），排除 WeChat、WebStorm 等桌面应用的服务端
- **菜单栏速览** — 点击菜单栏图标展开卡片式端口列表，端口号、协议、进程、项目路径一目了然
- **进程溯源** — `go run main.go` 编译出的 `main` 二进制自动关联到父进程 `go`
- **项目路径** — 显示每个服务的工作目录，hover 查看完整路径，点击在 Finder 中打开
- **一键终止** — 右键端口直接 kill 对应进程
- **每 3 秒自动刷新** — 可在设置中关闭
- **搜索过滤** — 支持端口号、进程名、PID、用户、地址、项目路径搜索

## 安装

### 直接下载

前往 [Releases](https://github.com/pkc918/DevPilot/releases) 下载最新 `DevPilot.dmg`，拖入 Applications 即可。首次打开需右键 → 打开。

### 从源码构建

```bash
git clone git@github.com:pkc918/DevPilot.git
cd DevPilot
bash script/build_and_run.sh
```

或直接用 Xcode 打开 `DevPilot.xcodeproj`，选择 Debug scheme 运行。

要求 macOS 14+，Xcode 16+。

## 项目结构

```
DevPilot/
├── DevPilotApp.swift          # 入口：主窗口 + 菜单栏 + 设置
├── ContentView.swift          # 主界面：侧边栏 + 端口表格
├── SettingsView.swift         # 设置面板
├── Models/
│   └── PortUsage.swift        # 端口数据模型 + 分类逻辑
├── Services/
│   └── PortScanner.swift      # lsof 扫描 + libproc 进程信息
├── Stores/
│   └── PortMonitorStore.swift # 状态管理 + 定时刷新
└── Views/                     # 子视图组件
```

## 分类逻辑

端口被归入「项目服务」需同时满足：

1. TCP LISTEN 状态
2. 监听本地地址（localhost / 0.0.0.0 / * 等）
3. 属于当前用户
4. 二进制不在 `/Applications/` 或系统路径（`/usr/sbin/` 等）

## 技术栈

- SwiftUI + AppKit（菜单栏集成）
- `lsof` 端口扫描
- `libproc`（`proc_pidpath` / `proc_pidinfo`）进程信息查询
- macOS 原生 `.help` tooltip + `NSWorkspace` Finder 集成
