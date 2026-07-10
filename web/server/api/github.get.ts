import { fetchRepositoryStats } from '../utils/github'

export default defineEventHandler(async (event) => {
  setResponseHeader(
    event,
    'Cache-Control',
    'public, s-maxage=3600, stale-while-revalidate=86400',
  )

  return fetchRepositoryStats((url, options) => $fetch(url, options))
})
