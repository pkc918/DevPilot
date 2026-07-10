import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const root = fileURLToPath(new URL('..', import.meta.url))
const read = (path: string) => readFileSync(`${root}/${path}`, 'utf8')

describe('production contracts', () => {
  it('declares a Node runtime compatible with the locked Nuxt toolchain', () => {
    const packageJson = JSON.parse(read('package.json')) as { engines: { node: string } }
    expect(packageJson.engines.node).toBe('^22.12.0 || ^24.11.0 || >=26.0.0')
    expect(read('README.md')).toContain('Node.js 22.12')
  })

  it('removes closed mobile navigation links from the tab order', () => {
    const header = read('app/components/SiteHeader.vue')
    expect(header).toContain('v-if="menuOpen"')
  })

  it('keeps GitHub and Discord in the header with their brand icons', () => {
    const header = read('app/components/SiteHeader.vue')
    expect(header).toContain('<BrandIcon name="github"')
    expect(header).toContain('<BrandIcon name="discord"')
    expect(header).toContain('class="discord-chip"')
    expect(header).toContain(':href="siteContent.links.discord"')

    const icon = read('app/components/BrandIcon.vue')
    expect(icon).toContain("github: '/icons/github.svg'")
    expect(icon).toContain("discord: '/icons/discord.svg'")
    expect(existsSync(`${root}/public/icons/github.svg`)).toBe(true)
    expect(existsSync(`${root}/public/icons/discord.svg`)).toBe(true)

    const packageJson = JSON.parse(read('package.json')) as { dependencies: Record<string, string> }
    expect(packageJson.dependencies).not.toHaveProperty('simple-icons')
  })

  it('preserves the responsive console scale for reduced motion', () => {
    const css = read('app/assets/css/main.css')
    const reducedMotionBlock = css.slice(css.indexOf('@media (prefers-reduced-motion: reduce)'))
    expect(reducedMotionBlock).not.toContain('.console-orbit,')
  })

  it('enables server-side caching for the GitHub endpoint', () => {
    const config = read('nuxt.config.ts')
    expect(config).toContain("'/api/github': { cache: { maxAge: 60 * 60 } }")
  })

  it('exposes the Homebrew install command in the first-screen hero', () => {
    const page = read('app/pages/index.vue')
    expect(page).toContain('class="hero-install-command"')
    expect(page).toContain('{{ siteContent.links.homebrew }}')
    expect(page.indexOf('hero-install-command')).toBeLessThan(page.indexOf('</section>'))
  })

  it('preserves the native aspect ratio of product preview images', () => {
    const page = read('app/pages/index.vue')
    expect(page).toContain('class="product-screens" data-reveal data-reveal-delay="1"')
    expect(page).not.toContain('class="product-screens" data-reveal data-reveal-delay="1" data-tilt')

    const css = read('app/assets/css/main.css')
    expect(css).toContain('aspect-ratio: 2256 / 1384;')
    expect(css).toContain('aspect-ratio: 892 / 302;')
    expect(css).toContain('object-fit: contain;')
  })
})
