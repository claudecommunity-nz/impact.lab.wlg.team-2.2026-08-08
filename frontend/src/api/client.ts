import type { ConditionsEnvelope, GeoJSONFeatureCollection, WarningsEnvelope } from './types'

export const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://172.20.10.3:8080'

export class ApiError extends Error {}

async function getJSON<T>(path: string): Promise<T> {
  let response: Response
  try {
    response = await fetch(`${API_BASE}${path}`)
  } catch {
    throw new ApiError(`Can't reach ${API_BASE} — is the backend running?`)
  }
  if (!response.ok) {
    throw new ApiError(`${path} → HTTP ${response.status}`)
  }
  return response.json() as Promise<T>
}

function pointQuery(params: { lat?: number; lng?: number }): string {
  const qs = new URLSearchParams()
  if (params.lat !== undefined) qs.set('lat', String(params.lat))
  if (params.lng !== undefined) qs.set('lng', String(params.lng))
  return qs.toString()
}

export function fetchWarnings(params: { lat?: number; lng?: number } = {}): Promise<WarningsEnvelope> {
  const qs = pointQuery(params)
  return getJSON<WarningsEnvelope>(`/v1/warnings${qs ? `?${qs}` : ''}`)
}

export function fetchWarningsGeoJSON(
  params: { lat?: number; lng?: number } = {},
): Promise<GeoJSONFeatureCollection> {
  const qs = new URLSearchParams(pointQuery(params))
  qs.set('format', 'geojson')
  return getJSON<GeoJSONFeatureCollection>(`/v1/warnings?${qs}`)
}

export function fetchConditions(params: {
  lat: number
  lng: number
  n?: number
  radiusKm?: number
}): Promise<ConditionsEnvelope> {
  const qs = new URLSearchParams(pointQuery(params))
  if (params.n !== undefined) qs.set('n', String(params.n))
  if (params.radiusKm !== undefined) qs.set('radiusKm', String(params.radiusKm))
  return getJSON<ConditionsEnvelope>(`/v1/conditions?${qs}`)
}

export function fetchHubsGeoJSON(): Promise<GeoJSONFeatureCollection> {
  return getJSON<GeoJSONFeatureCollection>('/v1/hubs?format=geojson')
}
