export type FetchStatus = 'loading' | 'ok' | 'error'

export type Trust = 'official' | 'lifeline' | 'planning' | 'community-unverified'

export interface SourceMeta {
  name: string
  id: string
  trust: Trust
  fetchedAt: string
  url?: string
}

export interface Warning {
  id: string
  event: string
  headline: string | null
  severity: string | null
  urgency: string | null
  certainty: string | null
  areaDesc: string | null
  onset: string | null
  expires: string | null
  description: string | null
  web: string | null
  source: SourceMeta
}

export interface WarningsEnvelope {
  items: Warning[]
  count: number
}

export interface GaugeReading {
  site: string
  lat: number
  lng: number
  distanceKm: number
  measurement: string
  value: number
  units: string
  observedAt: string
  trend: 'rising' | 'falling' | 'steady' | null
  source: SourceMeta
}

export interface ElectricityOutage {
  locationName: string | null
  distanceKm: number
  numAffected: number | null
  status: string | null
  outageType: string | null
  distributor: string | null
  startedAt: string | null
  link: string | null
  lat: number | null
  lng: number | null
  source: SourceMeta
}

export interface WaterFault {
  description: string | null
  address: string | null
  distanceKm: number
  status: string | null
  priority: string | null
  reportedAt: string | null
  lat: number | null
  lng: number | null
  source: SourceMeta
}

export interface ConditionsEnvelope {
  gauges: GaugeReading[]
  electricityOutages: ElectricityOutage[]
  waterFaults: WaterFault[]
}

export interface Hub {
  id: number
  name: string
  type: string | null
  address: string | null
  suburb: string | null
  town: string | null
  taName: string | null
  lat: number
  lng: number
  source: SourceMeta
}

export interface HubsEnvelope {
  items: Hub[]
  count: number
  source: SourceMeta
}

export interface GeoJSONFeatureCollection {
  type: 'FeatureCollection'
  features: Array<{
    type: 'Feature'
    geometry: { type: string; coordinates: unknown }
    properties: Record<string, unknown>
  }>
}
