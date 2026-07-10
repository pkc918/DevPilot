<script setup lang="ts">
import {
  getParticleBudget,
  shouldRunParticleLoop,
} from '~/composables/useLandingMotion'

interface Particle {
  x: number
  y: number
  vx: number
  vy: number
  radius: number
  phase: number
}

const canvas = ref<HTMLCanvasElement>()
let frame = 0
let particles: Particle[] = []
let pageVisible = true
let cleanup = () => {}

onMounted(() => {
  const element = canvas.value
  const context = element?.getContext('2d')
  if (!element || !context) return

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  const resize = () => {
    const dpr = Math.min(window.devicePixelRatio || 1, 1.5)
    element.width = Math.floor(window.innerWidth * dpr)
    element.height = Math.floor(window.innerHeight * dpr)
    element.style.width = `${window.innerWidth}px`
    element.style.height = `${window.innerHeight}px`
    context.setTransform(dpr, 0, 0, dpr, 0, 0)

    const budget = getParticleBudget(window.innerWidth, reducedMotion)
    particles = Array.from({ length: budget }, () => ({
      x: Math.random() * window.innerWidth,
      y: Math.random() * window.innerHeight,
      vx: (Math.random() - 0.5) * 0.15,
      vy: (Math.random() - 0.5) * 0.15,
      radius: Math.random() * 1.3 + 0.35,
      phase: Math.random() * Math.PI * 2,
    }))
  }

  const draw = (time: number) => {
    frame = 0
    context.clearRect(0, 0, window.innerWidth, window.innerHeight)
    if (!shouldRunParticleLoop(particles.length, pageVisible)) return

    for (let index = 0; index < particles.length; index += 1) {
      const particle = particles[index]!
      particle.x += particle.vx
      particle.y += particle.vy
      if (particle.x < -20) particle.x = window.innerWidth + 20
      if (particle.x > window.innerWidth + 20) particle.x = -20
      if (particle.y < -20) particle.y = window.innerHeight + 20
      if (particle.y > window.innerHeight + 20) particle.y = -20

      const alpha = 0.22 + Math.sin(time * 0.0006 + particle.phase) * 0.12
      context.beginPath()
      context.fillStyle = `rgba(91, 255, 189, ${alpha})`
      context.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2)
      context.fill()

      for (let targetIndex = index + 1; targetIndex < particles.length; targetIndex += 1) {
        const target = particles[targetIndex]!
        const dx = particle.x - target.x
        const dy = particle.y - target.y
        const distance = Math.hypot(dx, dy)
        if (distance > 118) continue
        context.beginPath()
        context.strokeStyle = `rgba(71, 219, 173, ${(1 - distance / 118) * 0.075})`
        context.lineWidth = 0.6
        context.moveTo(particle.x, particle.y)
        context.lineTo(target.x, target.y)
        context.stroke()
      }
    }

    frame = window.requestAnimationFrame(draw)
  }

  resize()
  if (!particles.length) return

  const onVisibility = () => {
    pageVisible = !document.hidden
    if (!pageVisible && frame) {
      window.cancelAnimationFrame(frame)
      frame = 0
    }
    else if (pageVisible && !frame) {
      frame = window.requestAnimationFrame(draw)
    }
  }
  window.addEventListener('resize', resize, { passive: true })
  document.addEventListener('visibilitychange', onVisibility)
  frame = window.requestAnimationFrame(draw)

  cleanup = () => {
    window.removeEventListener('resize', resize)
    document.removeEventListener('visibilitychange', onVisibility)
    window.cancelAnimationFrame(frame)
  }
})

onBeforeUnmount(() => cleanup())
</script>

<template>
  <canvas ref="canvas" class="particle-field" aria-hidden="true" />
</template>
