export const repositoryUrl = 'https://github.com/pkc918/DevPilot'

export interface RepositoryStats {
  stars: number | null
  formattedStars: string | null
  url: string
}

export type RepositoryFetcher = (
  url: string,
  options: { headers: Record<string, string>, timeout: number },
) => Promise<unknown>

function fallbackStats(): RepositoryStats {
  return {
    stars: null,
    formattedStars: null,
    url: repositoryUrl,
  }
}

export function normalizeRepositoryStats(value: unknown): RepositoryStats {
  if (!value || typeof value !== 'object' || !('stargazers_count' in value)) {
    return fallbackStats()
  }

  const stars = value.stargazers_count
  if (typeof stars !== 'number' || !Number.isFinite(stars) || stars < 0) {
    return fallbackStats()
  }

  return {
    stars,
    formattedStars: new Intl.NumberFormat('en', {
      notation: 'compact',
      maximumFractionDigits: 1,
    }).format(stars),
    url: repositoryUrl,
  }
}

export async function fetchRepositoryStats(
  fetcher: RepositoryFetcher,
): Promise<RepositoryStats> {
  try {
    const response = await fetcher(
      'https://api.github.com/repos/pkc918/DevPilot',
      {
        timeout: 4500,
        headers: {
          Accept: 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      },
    )
    return normalizeRepositoryStats(response)
  }
  catch {
    return fallbackStats()
  }
}
