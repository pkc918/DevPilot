<script setup lang="ts">
import { siteContent } from '~/data/site'

defineProps<{
  starsLabel: string
}>()

const menuOpen = ref(false)
</script>

<template>
  <header class="site-header" :class="{ 'menu-is-open': menuOpen }">
    <div class="scroll-progress" aria-hidden="true" />
    <nav class="site-nav shell" aria-label="主导航">
      <a class="brand" href="#top" aria-label="返回 DevPilot 首页">
        <span class="brand-icon-wrap">
          <img src="/app-icon.png" :alt="siteContent.images.icon" width="40" height="40">
          <span class="brand-pulse" aria-hidden="true" />
        </span>
        <span class="brand-copy">
          <strong>{{ siteContent.name }}</strong>
          <small>PORT INTELLIGENCE</small>
        </span>
      </a>

      <div class="nav-links" aria-label="页面章节">
        <a
          v-for="item in siteContent.navigation"
          :key="item.href"
          :href="item.href"
        >{{ item.label }}</a>
      </div>

      <div class="nav-actions">
        <a
          class="star-chip"
          :href="siteContent.links.github"
          target="_blank"
          rel="noreferrer"
          aria-label="前往 DevPilot GitHub 仓库"
        >
          <BrandIcon name="github" />
          <span class="header-action-copy">
            <strong>GitHub</strong>
            <small>{{ starsLabel }}</small>
          </span>
        </a>
        <a
          class="discord-chip"
          :href="siteContent.links.discord"
          target="_blank"
          rel="noreferrer"
          aria-label="加入 DevPilot Discord 社区"
        >
          <BrandIcon name="discord" />
          <span>Discord</span>
        </a>
        <a
          class="nav-download"
          :href="siteContent.links.download"
          target="_blank"
          rel="noreferrer"
        >下载 <span aria-hidden="true">↗</span></a>
      </div>

      <button
        class="menu-toggle"
        type="button"
        :aria-expanded="menuOpen"
        aria-controls="mobile-navigation"
        :aria-label="menuOpen ? '关闭导航菜单' : '打开导航菜单'"
        @click="menuOpen = !menuOpen"
      >
        <span />
        <span />
      </button>
    </nav>

    <div v-if="menuOpen" id="mobile-navigation" class="mobile-navigation shell">
      <a
        v-for="item in siteContent.navigation"
        :key="item.href"
        :href="item.href"
        @click="menuOpen = false"
      >{{ item.label }} <span aria-hidden="true">↘</span></a>
      <a class="mobile-social" :href="siteContent.links.github" target="_blank" rel="noreferrer">
        <BrandIcon name="github" />
        <span>GitHub · {{ starsLabel }}</span>
        <b aria-hidden="true">↗</b>
      </a>
      <a class="mobile-social" :href="siteContent.links.discord" target="_blank" rel="noreferrer">
        <BrandIcon name="discord" />
        <span>加入 Discord</span>
        <b aria-hidden="true">↗</b>
      </a>
      <a class="mobile-download" :href="siteContent.links.download" target="_blank" rel="noreferrer">下载 macOS App</a>
    </div>
  </header>
</template>
