import { describe, expect, it } from 'vitest'
import {
  fetchRepositoryStats,
  normalizeRepositoryStats,
} from '../server/utils/github'

describe('normalizeRepositoryStats', () => {
  it('normalizes a valid GitHub response', () => {
    expect(normalizeRepositoryStats({ stargazers_count: 1284 })).toEqual({
      stars: 1284,
      formattedStars: '1.3K',
      url: 'https://github.com/pkc918/DevPilot',
    })
  })

  it.each([
    undefined,
    null,
    {},
    { stargazers_count: -1 },
    { stargazers_count: Number.NaN },
    { stargazers_count: '1284' },
  ])('returns an honest fallback for invalid input %#', (value) => {
    expect(normalizeRepositoryStats(value)).toEqual({
      stars: null,
      formattedStars: null,
      url: 'https://github.com/pkc918/DevPilot',
    })
  })
})

describe('fetchRepositoryStats', () => {
  it('requests the canonical GitHub API endpoint', async () => {
    let requestedUrl = ''
    let requestedOptions: unknown
    const stats = await fetchRepositoryStats(async (url, options) => {
      requestedUrl = url
      requestedOptions = options
      return { stargazers_count: 42 }
    })

    expect(requestedUrl).toBe('https://api.github.com/repos/pkc918/DevPilot')
    expect(requestedOptions).toMatchObject({ timeout: 4500 })
    expect(stats.stars).toBe(42)
  })

  it('keeps the page renderable when GitHub is unavailable', async () => {
    const stats = await fetchRepositoryStats(async () => {
      throw new Error('rate limited')
    })

    expect(stats.stars).toBeNull()
    expect(stats.formattedStars).toBeNull()
  })
})
