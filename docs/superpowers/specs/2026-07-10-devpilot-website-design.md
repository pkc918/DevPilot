# DevPilot 官网设计规格

## 目标

在仓库根目录新增独立的 `web/` Nuxt 4 项目，为 DevPilot 提供可部署到 Vercel 的中文官网。网站必须清晰包含产品简介、GitHub 跳转、实时 Star 数、Discord 邀请和 App 下载入口，同时用高帧率、可降级的科幻动画建立鲜明品牌感。

## 受众与核心信息

主要受众是使用 AI 编码工具、本地启动多个开发服务的 macOS 开发者。核心主张是：DevPilot 把遗留在本机的服务端口放进菜单栏，让开发者看见进程、协议和项目目录，并能一键终止服务。

固定链接：

- GitHub：`https://github.com/pkc918/DevPilot`
- GitHub Star 数据：由 Nuxt 服务端请求 GitHub REST API 获取
- Discord：`http://discord.gg/JvFu49DYP`
- App 下载：`https://github.com/pkc918/DevPilot/releases/latest`
- Homebrew：`brew install --cask pkc918/tap/devpilot`

## 视觉系统

采用“量子控制台 / 端口雷达”方向。背景为接近黑色的深空蓝，主色使用 App 图标中的荧光绿，辅色为电光蓝与紫色。标题使用紧凑几何无衬线字体，数据、端口和状态使用等宽字体。整体避免模板化渐变卡片堆叠，以网格、扫描线、轨道、端口节点、HUD 边角和真实产品截图构成视觉语言。

首屏由两部分组成：左侧是价值主张、主要下载按钮、GitHub Star 和 Discord；右侧是悬浮的 DevPilot 产品窗口，窗口周围有端口轨道、扫描光束和状态节点。首屏下方显示实时状态条，强化“正在扫描本地开发服务”的产品心智。

## 页面结构

1. 顶部导航：品牌、功能锚点、GitHub Star、Discord、下载。
2. Hero：主标题、简介、下载与 GitHub CTA、动态产品视觉。
3. Problem strip：展示 AI agent 遗留端口的常见场景。
4. Workflow：发现端口、识别项目、一键终止三步扫描流程。
5. Product showcase：使用真实主窗口与菜单栏截图解释筛选、搜索、进程溯源和项目路径。
6. Feature grid：菜单栏速览、TCP/UDP 筛选、自动刷新、进程溯源等特性。
7. Community CTA：GitHub、Discord、下载和 Homebrew 命令。
8. Footer：仓库、版本下载、Discord、开源说明。

## 动效与交互

- Canvas 粒子场只在客户端运行，根据视口和设备像素比限制粒子数量。
- 鼠标移动驱动首屏聚光、产品窗口视差与轨道节点轻微偏移。
- 滚动时使用 IntersectionObserver 触发分组揭示，避免持续读取布局。
- CTA 支持轻量磁吸反馈；卡片 hover 使用边缘高光和小范围 3D 倾斜。
- 产品窗口内的端口行、扫描器和状态灯循环演示，但不妨碍阅读。
- 页面顶部显示细线滚动进度。
- `prefers-reduced-motion: reduce` 时关闭 Canvas 循环、视差、磁吸、自动漂浮和大幅滚动动画，只保留即时状态变化。
- 页面不可见时暂停 Canvas；移动端降低粒子密度并取消指针依赖交互。

## 技术架构

- Nuxt 4 + Vue 3 + TypeScript，采用 Nuxt 4 的 `app/` 目录结构。
- 单页官网由 `app/pages/index.vue` 组合小型展示组件。
- 全局视觉样式集中在 `app/assets/css/main.css`，组件内只保留与局部结构强关联的样式。
- 站点内容和外链集中在 `app/data/site.ts`，避免模板内散落常量。
- `server/api/github.get.ts` 请求 GitHub API，返回标准化 Star 数据，并设置 CDN 缓存与 stale-while-revalidate；失败时返回可渲染的空状态，不阻断页面。
- Vercel 直接识别 Nuxt/Nitro 输出，不加入平台锁定的前端代码。
- 图片从仓库已有 `assets/` 复制到 `web/public/`，不引入外部图片服务。

## 可访问性与 SEO

- 所有外链和图像有明确名称与替代文本；导航与按钮保持可见焦点。
- 使用语义化 `header`、`nav`、`main`、`section`、`footer` 与正确标题层级。
- 色彩对比满足正文可读性，状态不仅依赖颜色表达。
- 设置中文页面语言、标题、描述、Open Graph、Twitter Card、canonical 和主题色。
- 动态 Star 数据加载失败时显示“GitHub Stars”而非错误或虚假数字。

## 测试与验收

- Vitest 测试站点链接、必要内容和 GitHub 数据标准化逻辑。
- `npm test` 必须通过。
- `npm run typecheck` 必须通过。
- `npm run build` 必须生成可部署的 Nuxt/Nitro 产物。
- 最终检查桌面与移动断点、键盘焦点、减少动态效果规则和所有必要外链。

## 范围边界

本次不加入后台、CMS、用户账号、分析平台、多语言路由或自动发布 Vercel 项目。官网代码和 Vercel 兼容构建产物是交付范围，实际绑定 Vercel 账号由仓库导入流程完成。
