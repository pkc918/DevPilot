import { describe, expect, it } from 'vitest'
import { siteContent } from '../app/data/site'

describe('siteContent', () => {
  it('keeps every required destination in one source of truth', () => {
    expect(siteContent.links).toEqual({
      github: 'https://github.com/pkc918/DevPilot',
      discord: 'http://discord.gg/JvFu49DYP',
      download: 'https://github.com/pkc918/DevPilot/releases/latest',
      homebrew: 'brew install --cask pkc918/tap/devpilot',
    })
  })

  it('describes a complete product workflow', () => {
    expect(siteContent.workflow.map(step => step.title)).toEqual([
      '发现端口',
      '识别项目',
      '一键终止',
    ])
    expect(siteContent.features.length).toBeGreaterThanOrEqual(6)
  })

  it('provides the navigation and primary conversion copy', () => {
    expect(siteContent.navigation.map(item => item.label)).toEqual([
      '工作流',
      '产品界面',
      '能力矩阵',
      '开源社区',
    ])
    expect(siteContent.hero.primaryCta).toBe('下载 macOS App')
  })

  it('keeps product image alternatives meaningful', () => {
    expect(Object.values(siteContent.images).every(alt => alt.length >= 8)).toBe(true)
  })
})
