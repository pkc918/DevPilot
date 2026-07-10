<script setup lang="ts">
import { siteContent } from '~/data/site'
</script>

<template>
  <footer class="site-footer">
    <div class="shell footer-grid">
      <div class="footer-brand">
        <img src="/app-icon.png" alt="" width="36" height="36">
        <div><strong>DevPilot</strong><span>Keep your localhost under control.</span></div>
      </div>
      <div class="footer-links">
        <a :href="siteContent.links.github" target="_blank" rel="noreferrer">GitHub</a>
        <a :href="siteContent.links.download" target="_blank" rel="noreferrer">Releases</a>
        <a :href="siteContent.links.discord" target="_blank" rel="noreferrer">Discord</a>
      </div>
      <p>Open source · Built for macOS developers</p>
    </div>
  </footer>
</template>
