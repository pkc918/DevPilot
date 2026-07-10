# DevPilot Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cinematic, accessible Nuxt 4 marketing site for DevPilot in `web/`, ready for Vercel deployment.

**Architecture:** A Nuxt 4 SSR site renders a single composed landing page from focused Vue components and centralized site data. A Nitro API route proxies GitHub repository stats with CDN caching, while client-only Canvas and DOM motion utilities provide adaptive animation with reduced-motion fallbacks.

**Tech Stack:** Nuxt 4, Vue 3, TypeScript, CSS, Canvas 2D, Vitest, Nitro, Vercel.

## Global Constraints

- The site lives entirely under `web/` and must not change the macOS app.
- Required links are GitHub `https://github.com/pkc918/DevPilot`, Discord `http://discord.gg/JvFu49DYP`, latest release `https://github.com/pkc918/DevPilot/releases/latest`, and Homebrew `brew install --cask pkc918/tap/devpilot`.
- GitHub Stars must come from a server route and degrade to a label without inventing a number.
- Motion must pause or simplify for `prefers-reduced-motion`, hidden pages, touch devices, and narrow screens.
- Existing product images are reused from the repository.
- No CMS, authentication, analytics, persistence, or additional routes are included.

---

### Task 1: Establish the Nuxt project and test contract

**Files:**
- Create: `web/package.json`
- Create: `web/nuxt.config.ts`
- Create: `web/tsconfig.json`
- Create: `web/vitest.config.ts`
- Create: `web/tests/site-content.test.ts`
- Create: `web/tests/github-stats.test.ts`

**Interfaces:**
- Consumes: the fixed URLs and content requirements from the design spec.
- Produces: `siteContent`, `normalizeRepositoryStats(value)`, and the npm scripts used by every later task.

- [ ] **Step 1: Add the test runner and project configuration**

Create npm scripts `dev`, `build`, `preview`, `test`, and `typecheck`. Configure Vitest for TypeScript tests and Nuxt with global CSS, SSR, SEO head defaults, and one-hour SWR for `/api/github`.

- [ ] **Step 2: Write failing content tests**

Test that `siteContent.links` contains the exact GitHub, Discord, release, and Homebrew values, and that at least three product features are defined.

- [ ] **Step 3: Write failing repository-normalization tests**

The wished-for function has this exact interface:

```ts
export interface RepositoryStats {
  stars: number | null
  formattedStars: string | null
  url: string
}

export function normalizeRepositoryStats(value: unknown): RepositoryStats
```

Test valid numbers, compact formatting, missing values, negative values, and non-object input.

- [ ] **Step 4: Install dependencies and verify RED**

Run `npm install`, then `npm test`. Expected: both suites fail because `app/data/site.ts` and `server/utils/github.ts` do not exist.

### Task 2: Implement content and GitHub data flow

**Files:**
- Create: `web/app/data/site.ts`
- Create: `web/server/utils/github.ts`
- Create: `web/server/api/github.get.ts`

**Interfaces:**
- Consumes: the contracts from Task 1.
- Produces: typed marketing content and `GET /api/github` returning `RepositoryStats`.

- [ ] **Step 1: Implement the minimum centralized content**

Export `siteContent` with product name, Chinese headline, introduction, the four exact links, workflow steps, features, and minimum macOS requirement.

- [ ] **Step 2: Implement repository data normalization**

Accept only finite, non-negative `stargazers_count` values. Return compact `Intl.NumberFormat('en', { notation: 'compact' })` output for valid data and `null` values otherwise.

- [ ] **Step 3: Verify GREEN for unit tests**

Run `npm test`. Expected: all content and normalization tests pass.

- [ ] **Step 4: Add the cached Nitro endpoint**

Fetch `https://api.github.com/repos/pkc918/DevPilot` with GitHub API headers, normalize the response, set `Cache-Control: public, s-maxage=3600, stale-while-revalidate=86400`, and return the null fallback when GitHub is unavailable.

### Task 3: Build the semantic landing page

**Files:**
- Create: `web/app/app.vue`
- Create: `web/app/pages/index.vue`
- Create: `web/app/components/SiteHeader.vue`
- Create: `web/app/components/ProductConsole.vue`
- Create: `web/app/components/FeatureCard.vue`
- Create: `web/app/components/SiteFooter.vue`
- Copy: `assets/devpilot-app-icon-master.png` to `web/public/app-icon.png`
- Copy: `assets/product.png` to `web/public/product.png`
- Copy: `assets/menubar.png` to `web/public/menubar.png`

**Interfaces:**
- Consumes: `siteContent` and `GET /api/github`.
- Produces: the complete semantic DOM, all required calls to action, and real product imagery.

- [ ] **Step 1: Add a smoke test for the page contract**

Extend `site-content.test.ts` to assert the navigation labels, workflow order, primary CTA label, and non-empty image alt text stored in `siteContent`. Run the test and confirm it fails before extending the data.

- [ ] **Step 2: Complete the data contract and verify GREEN**

Add those labels and alt strings to `siteContent`; run `npm test` and confirm the suite passes.

- [ ] **Step 3: Compose the page**

Render header, hero, problem strip, three-step workflow, product showcase, feature grid, community CTA, and footer. Fetch `/api/github` with `useFetch`; render the formatted number only when non-null and otherwise render `GitHub Stars`.

- [ ] **Step 4: Add responsive navigation and accessible controls**

Use a native button for the mobile menu with `aria-expanded`, close it after an anchor selection, include visible focus styles, and make external destinations explicit.

### Task 4: Create the quantum-console visual system

**Files:**
- Create: `web/app/assets/css/main.css`
- Create: `web/app/components/ParticleField.client.vue`
- Create: `web/app/composables/useLandingMotion.ts`

**Interfaces:**
- Consumes: semantic elements marked with `data-reveal`, `data-parallax`, and `data-magnetic`.
- Produces: adaptive particle animation, reveal state classes, pointer CSS variables, and teardown-safe listeners.

- [ ] **Step 1: Add tests for motion preference policy**

Add pure helpers `getParticleBudget(width, reducedMotion)` and `shouldEnablePointerMotion(pointerFine, reducedMotion)` to the composable module. Test that reduced motion returns zero particles and disables pointer motion, mobile widths use a smaller budget, and large screens remain capped. Run tests and verify RED.

- [ ] **Step 2: Implement the minimum policy helpers and verify GREEN**

Use deterministic thresholds: zero for reduced motion, 32 particles below 768px, 58 below 1440px, and 76 otherwise. Pointer motion requires a fine pointer and no reduced-motion preference.

- [ ] **Step 3: Implement adaptive client motion**

Create a DPR-capped Canvas particle field, pause it on `visibilitychange`, reveal sections with one IntersectionObserver, update pointer variables inside one `requestAnimationFrame`, and remove every observer/listener during Vue teardown.

- [ ] **Step 4: Implement the visual system**

Define the dark navy, phosphor green, electric blue, violet, border, surface, text, mono, spacing, and radius tokens. Style the HUD navigation, hero orbit, product console, scanning line, workflow rail, screenshots, feature cards, CTA, footer, mobile breakpoints, and reduced-motion overrides.

### Task 5: Vercel, SEO, and final verification

**Files:**
- Create: `web/README.md`
- Create: `web/.gitignore`
- Modify: `web/nuxt.config.ts`
- Modify: `web/app/pages/index.vue`

**Interfaces:**
- Consumes: the completed site.
- Produces: documented local/Vercel usage, complete metadata, and verified deployment output.

- [ ] **Step 1: Add deployment documentation**

Document Node 20+, `npm install`, `npm run dev`, `npm test`, `npm run typecheck`, `npm run build`, and Vercel import with Root Directory set to `web`.

- [ ] **Step 2: Add page metadata**

Set Chinese title, description, canonical URL when `NUXT_PUBLIC_SITE_URL` is configured, Open Graph metadata, Twitter card metadata, theme color, and favicon/app icon.

- [ ] **Step 3: Run full verification**

Run `npm test`, `npm run typecheck`, and `npm run build` from `web/`. Expected: zero failed tests, successful type checking, and a Nitro Vercel-compatible `.output` build.

- [ ] **Step 4: Audit requirements and source changes**

Check all four required links, dynamic Star fallback, product introduction, desktop and mobile navigation, reduced-motion rules, copied images, Vercel instructions, and `git status --short`. Do not modify unrelated app files.
