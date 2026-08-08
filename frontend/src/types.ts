export interface LatLng {
  lat: number
  lng: number
}

export type AlertSeverity = 'advisory' | 'watch' | 'warning'

export interface AlertItem {
  id: string
  source: string
  severity: AlertSeverity
  headline: string
  time: string
  distanceKm?: number
  isOfficial: boolean
}

export interface Place {
  id: string
  label: string
  position: LatLng | null
  visible: boolean
}
