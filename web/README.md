# DevPilot Website

DevPilot 的 Nuxt 4 官网，可直接部署到 Vercel。

## 本地开发

需要 Node.js 22.12+（22.x LTS）、Node.js 24.11+（24.x）或更高的偶数版本，以及 pnpm 11。

```bash
pnpm install
pnpm dev
```

默认访问 `http://localhost:3000`。

## 验证

```bash
pnpm test
pnpm typecheck
pnpm build
```

## 部署到 Vercel

1. 在 Vercel 导入 `pkc918/DevPilot` 仓库。
2. 将 **Root Directory** 设置为 `web`。
3. Framework Preset 选择 **Nuxt.js**；构建和输出设置保持默认。
4. 可选设置 `NUXT_PUBLIC_SITE_URL` 为正式域名，用于生成 canonical 地址。
5. 部署。Nuxt 的 Nitro 服务端路由会自动成为 Vercel Function，`/api/github` 用于读取并缓存实时 Star 数。

GitHub 接口不可用或达到匿名请求限制时，首页会保留 GitHub 入口并隐藏具体数字，不会显示虚假 Star 数。
