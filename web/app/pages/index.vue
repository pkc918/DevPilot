<script setup lang="ts">
import { siteContent } from '~/data/site'

interface RepositoryStats {
  stars: number | null
  formattedStars: string | null
  url: string
}

const config = useRuntimeConfig()
const copied = ref(false)
const { data: repository } = await useFetch<RepositoryStats>('/api/github', {
  default: () => ({
    stars: null,
    formattedStars: null,
    url: siteContent.links.github,
  }),
})

const starsLabel = computed(() => repository.value.formattedStars
  ? `${repository.value.formattedStars} Stars`
  : 'GitHub Stars')

const canonicalUrl = computed(() => {
  const base = String(config.public.siteUrl || '').replace(/\/$/, '')
  return base || undefined
})
const socialImageUrl = computed(() => canonicalUrl.value
  ? `${canonicalUrl.value}/product.png`
  : undefined)

useLandingMotion()

async function copyInstallCommand() {
  if (!navigator.clipboard) return
  try {
    await navigator.clipboard.writeText(siteContent.links.homebrew)
    copied.value = true
    window.setTimeout(() => { copied.value = false }, 1800)
  }
  catch {
    copied.value = false
  }
}

useSeoMeta({
  title: 'DevPilot — 让本地开发端口重新归队',
  description: 'DevPilot 是一款 macOS 菜单栏端口监控工具。快速查看端口、进程、协议和项目目录，一键终止遗留开发服务。',
  ogTitle: 'DevPilot — Local Port Intelligence',
  ogDescription: '看见每一个本地开发服务，然后一键结束它。',
  ogType: 'website',
  ogImage: () => socialImageUrl.value,
  twitterCard: 'summary_large_image',
  twitterTitle: 'DevPilot — Local Port Intelligence',
  twitterDescription: 'A native macOS port monitor built for AI coding workflows.',
  twitterImage: () => socialImageUrl.value,
})

useHead(() => ({
  link: canonicalUrl.value ? [{ rel: 'canonical', href: canonicalUrl.value }] : [],
}))
</script>

<template>
  <div id="top" class="site-root">
    <ParticleField />
    <div class="ambient-grid" aria-hidden="true" />
    <div class="cursor-glow" aria-hidden="true" />
    <SiteHeader :stars-label="starsLabel" />

    <main>
      <section class="hero shell" aria-labelledby="hero-title">
        <div class="hero-copy" data-reveal>
          <div class="eyebrow-row">
            <span class="signal-dot" aria-hidden="true" />
            <span>{{ siteContent.eyebrow }}</span>
            <span class="eyebrow-line" aria-hidden="true" />
          </div>
          <h1 id="hero-title">
            {{ siteContent.hero.titleLead }}
            <span>{{ siteContent.hero.titleAccent }}</span><br>
            {{ siteContent.hero.titleTail }}
          </h1>
          <p class="hero-description">{{ siteContent.hero.description }}</p>

          <div class="hero-actions">
            <a
              class="button button-primary"
              :href="siteContent.links.download"
              target="_blank"
              rel="noreferrer"
              data-magnetic
            >
              <span class="button-icon" aria-hidden="true">↓</span>
              <span><strong>{{ siteContent.hero.primaryCta }}</strong><small>{{ siteContent.requirement }} · Apple Silicon / Intel</small></span>
              <i aria-hidden="true">↗</i>
            </a>
            <a
              class="button button-ghost"
              :href="siteContent.links.github"
              target="_blank"
              rel="noreferrer"
              data-magnetic
            >
              <span aria-hidden="true">⌘</span>
              {{ siteContent.hero.secondaryCta }}
              <b>{{ starsLabel }}</b>
            </a>
          </div>

          <div class="hero-install">
            <span class="hero-install-label"><i aria-hidden="true" /> HOMEBREW</span>
            <button
              class="hero-install-command"
              type="button"
              aria-label="复制 Homebrew 安装命令"
              @click="copyInstallCommand"
            >
              <span aria-hidden="true">$</span>
              <code>{{ siteContent.links.homebrew }}</code>
              <b aria-live="polite">{{ copied ? '已复制' : '复制' }}</b>
            </button>
          </div>

          <div class="hero-meta">
            <span><i /> Native SwiftUI</span>
            <span><i /> Open Source</span>
            <span><i /> {{ siteContent.version }}</span>
          </div>
        </div>

        <div class="hero-visual" data-reveal data-reveal-delay="1">
          <div class="visual-coordinate coordinate-top">N 31.2304° / E 121.4737°</div>
          <ProductConsole />
          <div class="visual-coordinate coordinate-bottom">LOCAL NODE · SECURE CHANNEL</div>
        </div>
      </section>

      <div class="telemetry-bar" aria-label="DevPilot 当前能力摘要">
        <div class="shell telemetry-track">
          <span class="telemetry-status"><i /> SYSTEM ONLINE</span>
          <div class="telemetry-marquee">
            <span v-for="signal in siteContent.problemSignals" :key="signal">{{ signal }} <i>◆</i></span>
            <span v-for="signal in siteContent.problemSignals" :key="`copy-${signal}`" aria-hidden="true">{{ signal }} <i>◆</i></span>
          </div>
          <span class="telemetry-end">SCAN 3.0s</span>
        </div>
      </div>

      <section class="problem-section shell section-pad" aria-labelledby="problem-title">
        <div class="section-code" aria-hidden="true">01 / SIGNAL</div>
        <div class="problem-layout">
          <div data-reveal>
            <p class="section-eyebrow">THE INVISIBLE PROBLEM</p>
            <h2 id="problem-title">Agent 走了，<br><span>端口还亮着。</span></h2>
          </div>
          <div class="problem-copy" data-reveal data-reveal-delay="1">
            <p>代码生成完成、终端标签关闭、注意力切到下一个任务——但那些临时启动的 Vite、Node、Go 服务仍在后台等待。</p>
            <div class="ghost-command">
              <span>$ lsof -i :5173</span>
              <span class="command-result">vite &nbsp;14901 &nbsp;TCP *:5173 (LISTEN)</span>
              <i aria-hidden="true" />
            </div>
          </div>
        </div>
      </section>

      <section id="workflow" class="workflow-section section-pad" aria-labelledby="workflow-title">
        <div class="shell">
          <div class="section-heading" data-reveal>
            <div>
              <p class="section-eyebrow">THREE-STEP PROTOCOL</p>
              <h2 id="workflow-title">从信号到清场，<br><span>三步完成闭环。</span></h2>
            </div>
            <p>DevPilot 常驻菜单栏。它不会打断工作，只在你需要的时候，把本机服务状态变成可执行的信息。</p>
          </div>

          <div class="workflow-grid">
            <article
              v-for="(step, index) in siteContent.workflow"
              :key="step.title"
              class="workflow-card"
              data-reveal
              :data-reveal-delay="index"
            >
              <div class="workflow-visual" aria-hidden="true">
                <span class="workflow-index">{{ step.index }}</span>
                <div class="radar-ring"><i /><b /></div>
                <span class="workflow-signal">{{ step.signal }}</span>
              </div>
              <h3>{{ step.title }}</h3>
              <p>{{ step.description }}</p>
              <span class="workflow-link">PROTOCOL {{ step.index }} <i>→</i></span>
            </article>
          </div>
        </div>
      </section>

      <section id="product" class="product-section section-pad" aria-labelledby="product-title">
        <div class="shell product-layout">
          <div class="product-copy" data-reveal>
            <p class="section-eyebrow">{{ siteContent.showcase.eyebrow }}</p>
            <h2 id="product-title">{{ siteContent.showcase.title }}</h2>
            <p>{{ siteContent.showcase.description }}</p>
            <ul>
              <li v-for="bullet in siteContent.showcase.bullets" :key="bullet"><i aria-hidden="true">✓</i>{{ bullet }}</li>
            </ul>
            <a :href="siteContent.links.download" target="_blank" rel="noreferrer">打开任务控制中心 <span aria-hidden="true">→</span></a>
          </div>

          <div class="product-screens" data-reveal data-reveal-delay="1">
            <div class="screen-frame main-screen">
              <div class="screen-frame-label"><span>MAIN WINDOW</span><span>LIVE CAPTURE</span></div>
              <img src="/product.png" :alt="siteContent.images.product" width="2256" height="1384" loading="lazy">
            </div>
            <div class="screen-frame menubar-screen">
              <div class="screen-frame-label"><span>MENUBAR</span><span>01 PROCESS</span></div>
              <img src="/menubar.png" :alt="siteContent.images.menubar" width="892" height="302" loading="lazy">
            </div>
          </div>
        </div>
      </section>

      <section id="features" class="features-section section-pad" aria-labelledby="features-title">
        <div class="shell">
          <div class="section-heading compact" data-reveal>
            <div>
              <p class="section-eyebrow">CAPABILITY MATRIX</p>
              <h2 id="features-title">为本地开发，<br><span>保持绝对清醒。</span></h2>
            </div>
            <div class="matrix-status"><i /> 6 MODULES ACTIVE</div>
          </div>

          <div class="feature-grid">
            <FeatureCard
              v-for="(feature, index) in siteContent.features"
              :key="feature.code"
              :index="index"
              :code="feature.code"
              :title="feature.title"
              :description="feature.description"
            />
          </div>
        </div>
      </section>

      <section id="community" class="community-section section-pad" aria-labelledby="community-title">
        <div class="shell community-panel" data-reveal>
          <div class="community-orbit" aria-hidden="true"><span /><i /><b /></div>
          <p class="section-eyebrow">OPEN SOURCE FREQUENCY</p>
          <h2 id="community-title">加入 DevPilot 的<br><span>开放航道。</span></h2>
          <p>报告问题、提出功能想法，或和其他开发者聊聊你的本地开发工作流。</p>
          <div class="community-actions">
            <a class="button button-primary" :href="siteContent.links.github" target="_blank" rel="noreferrer" data-magnetic>
              <span class="button-icon" aria-hidden="true">⌘</span>
              <span><strong>Star on GitHub</strong><small>{{ starsLabel }} · MIT</small></span>
              <i aria-hidden="true">↗</i>
            </a>
            <a class="button button-discord" :href="siteContent.links.discord" target="_blank" rel="noreferrer" data-magnetic>
              <span aria-hidden="true">◉</span> 加入 Discord <i aria-hidden="true">↗</i>
            </a>
          </div>
          <button class="install-command" type="button" aria-live="polite" @click="copyInstallCommand">
            <span>$</span> {{ siteContent.links.homebrew }}
            <b>{{ copied ? 'COPIED' : 'COPY' }}</b>
          </button>
        </div>
      </section>
    </main>

    <SiteFooter />
  </div>
</template>
