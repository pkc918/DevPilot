export const siteContent = {
  name: 'DevPilot',
  version: 'v0.1.9',
  requirement: 'macOS 15+',
  eyebrow: 'LOCAL PORT INTELLIGENCE',
  hero: {
    titleLead: '让失控的',
    titleAccent: '开发端口',
    titleTail: '重新归队。',
    description: 'AI 编码 Agent 完成任务后，服务却还在后台运行。DevPilot 把端口、进程与项目目录送进菜单栏——看见它，然后一键结束它。',
    primaryCta: '下载 macOS App',
    secondaryCta: '查看 GitHub',
  },
  navigation: [
    { label: '工作流', href: '#workflow' },
    { label: '产品界面', href: '#product' },
    { label: '能力矩阵', href: '#features' },
    { label: '开源社区', href: '#community' },
  ],
  links: {
    github: 'https://github.com/pkc918/DevPilot',
    discord: 'http://discord.gg/JvFu49DYP',
    download: 'https://github.com/pkc918/DevPilot/releases/latest',
    homebrew: 'brew install --cask pkc918/tap/devpilot',
  },
  problemSignals: [
    'localhost:3000',
    'node · PID 14901',
    'TCP · LISTEN',
    '~/code/next-agent',
    'localhost:5173',
  ],
  workflow: [
    {
      index: '01',
      signal: 'SCAN',
      title: '发现端口',
      description: '自动扫描本机 TCP / UDP 监听状态，3 秒刷新一次，不再回到终端反复执行 lsof。',
    },
    {
      index: '02',
      signal: 'TRACE',
      title: '识别项目',
      description: '从 PID 追溯父进程和工作目录，把匿名端口还原成你真正关心的开发项目。',
    },
    {
      index: '03',
      signal: 'TERMINATE',
      title: '一键终止',
      description: '在菜单栏或主窗口直接关闭服务，自动去重 PID，以温和的 TERM 信号完成清理。',
    },
  ],
  showcase: {
    eyebrow: 'MISSION CONTROL',
    title: '所有本地服务，一张雷达图看清。',
    description: '项目端口、全部端口、TCP、UDP、进程、PID 与工作目录都在同一个原生窗口里。搜索、筛选、定位、终止，一条链路完成。',
    bullets: [
      '项目服务智能分类',
      '父进程与工作目录溯源',
      '端口 / 进程 / PID 全局搜索',
    ],
  },
  features: [
    {
      code: 'MENUBAR',
      title: '菜单栏速览',
      description: '不用切换上下文，点击菜单栏图标就能查看正在运行的项目服务。',
    },
    {
      code: 'SCOPE',
      title: '项目服务筛选',
      description: '自动排除系统与常规应用端口，把注意力留给真正的开发服务。',
    },
    {
      code: 'TRACE',
      title: '进程溯源',
      description: '识别 go run 等临时二进制的父进程，还原服务背后的真实工具链。',
    },
    {
      code: 'PATH',
      title: '项目路径',
      description: '显示工作目录，支持复制路径和在 Finder 中打开，快速回到现场。',
    },
    {
      code: 'KILL',
      title: '一键终止',
      description: '从端口直接定位并关闭服务，自动处理同一 PID 占用多个监听记录。',
    },
    {
      code: 'PULSE',
      title: '自动刷新',
      description: '默认每 3 秒扫描并以双缓冲更新界面，状态变化清晰但不闪烁。',
    },
  ],
  images: {
    product: 'DevPilot 主窗口展示项目端口、进程、协议和工作目录',
    menubar: 'DevPilot 菜单栏弹窗展示正在运行的项目服务',
    icon: 'DevPilot 应用图标',
  },
} as const
