import type { AlertItem } from '../types'

export const privateAlerts: AlertItem[] = [
  {
    id: 'p1',
    source: 'MetService',
    severity: 'watch',
    headline: 'Heavy swell watch for the south coast, including Island Bay',
    time: '2026-08-08T07:30:00+12:00',
    distanceKm: 1.2,
    isOfficial: true,
  },
  {
    id: 'p2',
    source: 'Community report',
    severity: 'advisory',
    headline: 'Surface flooding reported on Shorland Park — unconfirmed',
    time: '2026-08-08T08:05:00+12:00',
    distanceKm: 0.4,
    isOfficial: false,
  },
]

export const regionalWarnings: AlertItem[] = [
  {
    id: 'r1',
    source: 'MetService',
    severity: 'warning',
    headline: 'Strong wind warning for the Wellington region',
    time: '2026-08-08T06:00:00+12:00',
    isOfficial: true,
  },
  {
    id: 'r2',
    source: 'WCC / WREMO',
    severity: 'advisory',
    headline: 'South coast road access may be affected by high tide this afternoon',
    time: '2026-08-08T05:45:00+12:00',
    isOfficial: true,
  },
]
