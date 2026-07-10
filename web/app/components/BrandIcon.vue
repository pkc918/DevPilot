<script setup lang="ts">
const props = defineProps<{
  name: 'github' | 'discord'
}>()

const icons = {
  github: '/icons/github.svg',
  discord: '/icons/discord.svg',
} as const
</script>

<template>
  <img
    class="brand-action-icon"
    :src="icons[props.name]"
    alt=""
    width="16"
    height="16"
    aria-hidden="true"
  >
</template>
