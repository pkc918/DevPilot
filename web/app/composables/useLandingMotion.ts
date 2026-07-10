export function getParticleBudget(width: number, reducedMotion: boolean): number {
  if (reducedMotion) return 0
  if (width < 768) return 32
  if (width < 1440) return 58
  return 76
}

export function shouldEnablePointerMotion(
  pointerFine: boolean,
  reducedMotion: boolean,
): boolean {
  return pointerFine && !reducedMotion
}

export function shouldRunParticleLoop(
  particleCount: number,
  pageVisible: boolean,
): boolean {
  return particleCount > 0 && pageVisible
}

export function useLandingMotion() {
  const cleanups: Array<() => void> = []

  onMounted(() => {
    const root = document.documentElement
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const pointerFine = window.matchMedia('(pointer: fine)').matches
    const revealItems = Array.from(document.querySelectorAll<HTMLElement>('[data-reveal]'))

    if (reducedMotion || !('IntersectionObserver' in window)) {
      revealItems.forEach(item => item.classList.add('is-visible'))
    }
    else {
      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return
          entry.target.classList.add('is-visible')
          observer.unobserve(entry.target)
        })
      }, { threshold: 0.14, rootMargin: '0px 0px -7% 0px' })
      revealItems.forEach(item => observer.observe(item))
      cleanups.push(() => observer.disconnect())
    }

    let scrollFrame = 0
    const updateScroll = () => {
      scrollFrame = 0
      const max = document.documentElement.scrollHeight - window.innerHeight
      const progress = max > 0 ? window.scrollY / max : 0
      root.style.setProperty('--scroll-progress', progress.toFixed(4))
    }
    const onScroll = () => {
      if (scrollFrame) return
      scrollFrame = window.requestAnimationFrame(updateScroll)
    }
    updateScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    cleanups.push(() => {
      window.removeEventListener('scroll', onScroll)
      if (scrollFrame) window.cancelAnimationFrame(scrollFrame)
    })

    if (shouldEnablePointerMotion(pointerFine, reducedMotion)) {
      let pointerFrame = 0
      let clientX = window.innerWidth / 2
      let clientY = window.innerHeight / 2
      const updatePointer = () => {
        pointerFrame = 0
        const normalizedX = clientX / window.innerWidth - 0.5
        const normalizedY = clientY / window.innerHeight - 0.5
        root.style.setProperty('--pointer-x', `${clientX}px`)
        root.style.setProperty('--pointer-y', `${clientY}px`)
        root.style.setProperty('--parallax-x', normalizedX.toFixed(4))
        root.style.setProperty('--parallax-y', normalizedY.toFixed(4))
      }
      const onPointerMove = (event: PointerEvent) => {
        clientX = event.clientX
        clientY = event.clientY
        if (!pointerFrame) pointerFrame = window.requestAnimationFrame(updatePointer)
      }
      window.addEventListener('pointermove', onPointerMove, { passive: true })
      cleanups.push(() => {
        window.removeEventListener('pointermove', onPointerMove)
        if (pointerFrame) window.cancelAnimationFrame(pointerFrame)
      })

      document.querySelectorAll<HTMLElement>('[data-magnetic]').forEach((element) => {
        const onMove = (event: PointerEvent) => {
          const rect = element.getBoundingClientRect()
          const x = (event.clientX - rect.left - rect.width / 2) * 0.12
          const y = (event.clientY - rect.top - rect.height / 2) * 0.18
          element.style.setProperty('--magnetic-x', `${x.toFixed(2)}px`)
          element.style.setProperty('--magnetic-y', `${y.toFixed(2)}px`)
        }
        const onLeave = () => {
          element.style.setProperty('--magnetic-x', '0px')
          element.style.setProperty('--magnetic-y', '0px')
        }
        element.addEventListener('pointermove', onMove)
        element.addEventListener('pointerleave', onLeave)
        cleanups.push(() => {
          element.removeEventListener('pointermove', onMove)
          element.removeEventListener('pointerleave', onLeave)
        })
      })

      document.querySelectorAll<HTMLElement>('[data-tilt]').forEach((element) => {
        const onMove = (event: PointerEvent) => {
          const rect = element.getBoundingClientRect()
          const x = (event.clientX - rect.left) / rect.width - 0.5
          const y = (event.clientY - rect.top) / rect.height - 0.5
          element.style.setProperty('--tilt-x', `${(-y * 3.5).toFixed(2)}deg`)
          element.style.setProperty('--tilt-y', `${(x * 4).toFixed(2)}deg`)
          element.style.setProperty('--card-glow-x', `${((x + 0.5) * 100).toFixed(1)}%`)
          element.style.setProperty('--card-glow-y', `${((y + 0.5) * 100).toFixed(1)}%`)
        }
        const onLeave = () => {
          element.style.setProperty('--tilt-x', '0deg')
          element.style.setProperty('--tilt-y', '0deg')
        }
        element.addEventListener('pointermove', onMove)
        element.addEventListener('pointerleave', onLeave)
        cleanups.push(() => {
          element.removeEventListener('pointermove', onMove)
          element.removeEventListener('pointerleave', onLeave)
        })
      })
    }
  })

  onBeforeUnmount(() => cleanups.splice(0).forEach(cleanup => cleanup()))
}
