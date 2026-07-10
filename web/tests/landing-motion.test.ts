import { describe, expect, it } from 'vitest'
import {
  getParticleBudget,
  shouldRunParticleLoop,
  shouldEnablePointerMotion,
} from '../app/composables/useLandingMotion'

describe('getParticleBudget', () => {
  it('disables decorative particles for reduced motion', () => {
    expect(getParticleBudget(1920, true)).toBe(0)
  })

  it('uses an adaptive, capped particle budget', () => {
    expect(getParticleBudget(390, false)).toBe(32)
    expect(getParticleBudget(1024, false)).toBe(58)
    expect(getParticleBudget(2560, false)).toBe(76)
  })
})

describe('shouldRunParticleLoop', () => {
  it('stops work when there are no particles or the page is hidden', () => {
    expect(shouldRunParticleLoop(0, true)).toBe(false)
    expect(shouldRunParticleLoop(32, false)).toBe(false)
    expect(shouldRunParticleLoop(32, true)).toBe(true)
  })
})

describe('shouldEnablePointerMotion', () => {
  it('requires a fine pointer and full-motion preference', () => {
    expect(shouldEnablePointerMotion(true, false)).toBe(true)
    expect(shouldEnablePointerMotion(false, false)).toBe(false)
    expect(shouldEnablePointerMotion(true, true)).toBe(false)
  })
})
