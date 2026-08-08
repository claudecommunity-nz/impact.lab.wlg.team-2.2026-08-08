import type { AlertItem, AlertSeverity } from '../types'
import type { Warning } from './types'

const SEVERITY_ORDER: Record<string, number> = {
  extreme: 4,
  severe: 3,
  moderate: 2,
  minor: 1,
  unknown: 0,
}

export function severityRank(warning: Warning): number {
  return SEVERITY_ORDER[warning.severity?.toLowerCase() ?? 'unknown'] ?? 0
}

export function pickWorstWarning(items: Warning[]): Warning | null {
  if (items.length === 0) return null
  return [...items].sort((a, b) => severityRank(b) - severityRank(a))[0]
}

export function isWellingtonWarning(warning: { areaDesc: string | null }): boolean {
  return (warning.areaDesc ?? '').toLowerCase().includes('wellington')
}

const CARD_SEVERITY_MAP: Record<string, AlertSeverity> = {
  extreme: 'warning',
  severe: 'warning',
  moderate: 'watch',
  minor: 'advisory',
  unknown: 'advisory',
}

export function warningToAlertItem(warning: Warning): AlertItem {
  return {
    id: warning.id,
    source: warning.source.name,
    severity: CARD_SEVERITY_MAP[warning.severity?.toLowerCase() ?? 'unknown'] ?? 'advisory',
    headline: warning.headline ?? warning.event,
    time: warning.onset ?? warning.source.fetchedAt,
    isOfficial: true,
  }
}
