<script setup lang="ts">
defineProps<{
  index: number
  code: string
  title: string
  description: string
}>()
</script>

<template>
  <article class="feature-card" data-reveal data-tilt>
    <div class="feature-card-head">
      <span class="feature-index">0{{ index + 1 }}</span>
      <span class="feature-code">{{ code }}</span>
    </div>
    <div class="feature-symbol" aria-hidden="true">
      <span />
      <i />
    </div>
    <h3>{{ title }}</h3>
    <p>{{ description }}</p>
    <div class="card-corner corner-top" aria-hidden="true" />
    <div class="card-corner corner-bottom" aria-hidden="true" />
  </article>
</template>
