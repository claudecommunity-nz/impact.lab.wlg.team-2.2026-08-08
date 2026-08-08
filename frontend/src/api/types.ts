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

export interface DemoPointInfo {
  id: string
  name: string
  lat: number
  lng: number
}

export interface DemoScenarioInfo {
  id: string
  title: string
  description: string
  points: DemoPointInfo[]
}

export interface DemoCatalog {
  note: string
  scenarios: DemoScenarioInfo[]
}

export interface HazardItem {
  layer: string
  id: string
  value: string
  detail: string | null
  publisher: string
  source: SourceMeta
}

export interface HazardsEnvelope {
  status: string
  note: string
  items: HazardItem[]
}

export interface NearestHub {
  id: number
  name: string
  type: string | null
  address: string | null
  suburb: string | null
  town: string | null
  lat: number
  lng: number
  distanceKm: number
  source: SourceMeta
}

export interface PictureLocation {
  lat: number
  lng: number
  nearestHub: NearestHub | null
}

export interface OfficialWarningsSection {
  status: string
  items: Warning[]
  reason: string | null
}

export interface LocalConditionsSection {
  status: string
  gauges: GaugeReading[]
  electricityOutages: ElectricityOutage[]
  waterFaults: WaterFault[]
  reason: string | null
}

export interface SourceStatusEntry {
  id: string
  fetchedAt: string | null
  status: string
}

export interface LocationPicture {
  location: PictureLocation
  officialWarnings: OfficialWarningsSection
  localConditions: LocalConditionsSection
  hazardContext: HazardsEnvelope
  summary: string[]
  generatedAt: string
  sources: SourceStatusEntry[]
  disclaimer: string
}
