/// <reference types="geojson" />
import { useEffect, useRef } from 'react'
import {
  Map as MapLibreMap,
  Marker,
  NavigationControl,
  Popup,
  type GeoJSONSource,
  type MapMouseEvent,
} from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import '../lib/maplibreWorker'
import { WELLINGTON_CBD } from '../constants'
import { useWarningsOverlay } from '../hooks/useWarningsOverlay'
import { useHubsOverlay } from '../hooks/useHubsOverlay'
import { useConditions } from '../hooks/useConditions'
import { formatAge } from '../lib/time'
import type { LatLng, Place } from '../types'

const STYLE_URL = 'https://tiles.openfreemap.org/styles/liberty'

const SEVERITY_COLOR_EXPRESSION = [
  'match',
  ['downcase', ['coalesce', ['get', 'severity'], 'unknown']],
  'extreme',
  '#f07000',
  'severe',
  '#f07000',
  'moderate',
  '#ffdd00',
  '#949494',
] as const

const HOME_COLOR = '#ffdd00'
const PLACE_COLORS = ['#0057a8', '#f07000', '#2f2f2f', '#595959']

function colorForPlace(place: Place, nonHomeIndex: number) {
  if (place.id === 'home') return HOME_COLOR
  return PLACE_COLORS[nonHomeIndex % PLACE_COLORS.length]
}

function createBadgeElement(emoji: string, borderColor: string): HTMLDivElement {
  const el = document.createElement('div')
  el.textContent = emoji
  el.className =
    'flex h-7 w-7 items-center justify-center rounded-full border-2 bg-wcc-white text-base shadow'
  el.style.borderColor = borderColor
  return el
}

interface Props {
  center: LatLng | null
  places: Place[]
  armedSlot: string | null
  onMapClick: (position: LatLng) => void
}

export function MapView({ center, places, armedSlot, onMapClick }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<MapLibreMap | null>(null)
  const youMarkerRef = useRef<Marker | null>(null)
  const markersRef = useRef<Record<string, Marker>>({})
  const hubMarkersRef = useRef<Record<string, Marker>>({})
  const waterFaultMarkersRef = useRef<Marker[]>([])
  const onMapClickRef = useRef(onMapClick)
  onMapClickRef.current = onMapClick

  const { data: warningsGeoJSON } = useWarningsOverlay()
  const { data: hubsGeoJSON } = useHubsOverlay()
  const { conditions } = useConditions(center?.lat, center?.lng)
  const warningsDataRef = useRef(warningsGeoJSON)
  warningsDataRef.current = warningsGeoJSON

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return
    let cancelled = false
    const start = center ?? WELLINGTON_CBD
    const isTouch = window.matchMedia('(pointer: coarse)').matches
    const map = new MapLibreMap({
      container: containerRef.current,
      style: STYLE_URL,
      center: [start.lng, start.lat],
      zoom: 15,
      cooperativeGestures: isTouch,
    })
    map.addControl(new NavigationControl(), 'top-right')
    requestAnimationFrame(() => map.resize())

    youMarkerRef.current = new Marker({ color: '#2f2f2f' })
      .setLngLat([start.lng, start.lat])
      .setPopup(new Popup({ offset: 16, maxWidth: '280px' }).setText('Approximate location'))
      .addTo(map)

    map.on('click', (event: MapMouseEvent) => {
      onMapClickRef.current({ lat: event.lngLat.lat, lng: event.lngLat.lng })
    })

    map.on('load', () => {
      if (cancelled) return
      map.addSource('warnings', {
        type: 'geojson',
        data: warningsDataRef.current as unknown as GeoJSON.FeatureCollection,
      })
      map.addLayer({
        id: 'warnings-fill',
        type: 'fill',
        source: 'warnings',
        paint: { 'fill-color': SEVERITY_COLOR_EXPRESSION as unknown as string, 'fill-opacity': 0.25 },
      })
      map.addLayer({
        id: 'warnings-outline',
        type: 'line',
        source: 'warnings',
        paint: { 'line-color': SEVERITY_COLOR_EXPRESSION as unknown as string, 'line-width': 2, 'line-opacity': 0.7 },
      })

      map.on('click', 'warnings-fill', (event) => {
        const props = event.features?.[0]?.properties
        if (!props) return
        new Popup({ offset: 12, maxWidth: '280px' })
          .setLngLat(event.lngLat)
          .setHTML(
            `<strong>${props.event}</strong><br/>${[props.severity, props.urgency].filter(Boolean).join(' · ')}${
              props.areaDesc ? `<br/>${props.areaDesc}` : ''
            }`,
          )
          .addTo(map)
      })
      map.on('mouseenter', 'warnings-fill', () => {
        map.getCanvas().style.cursor = 'pointer'
      })
      map.on('mouseleave', 'warnings-fill', () => {
        map.getCanvas().style.cursor = ''
      })
    })

    mapRef.current = map
    return () => {
      cancelled = true
      map.remove()
      mapRef.current = null
    }
    // Runs once on mount only; later position updates are handled by the effect below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (!center || !mapRef.current) return
    mapRef.current.flyTo({ center: [center.lng, center.lat], zoom: 15 })
    youMarkerRef.current?.setLngLat([center.lng, center.lat])
  }, [center])

  useEffect(() => {
    const source = mapRef.current?.getSource('warnings') as GeoJSONSource | undefined
    source?.setData(warningsGeoJSON as unknown as GeoJSON.FeatureCollection)
  }, [warningsGeoJSON])

  useEffect(() => {
    const map = mapRef.current
    if (!map) return

    const seenIds = new Set<string>()
    for (const feature of hubsGeoJSON.features) {
      const props = feature.properties as { id: number | string; name: string; type?: string; address?: string }
      const coords = feature.geometry.coordinates as [number, number]
      const id = String(props.id)
      seenIds.add(id)
      const existing = hubMarkersRef.current[id]
      if (existing) {
        existing.setLngLat(coords)
      } else {
        hubMarkersRef.current[id] = new Marker({ element: createBadgeElement('🛟', '#0057a8') })
          .setLngLat(coords)
          .setPopup(
            new Popup({ offset: 16, maxWidth: '280px' }).setHTML(
              `<strong>${props.name}</strong>${props.type ? `<br/>${props.type}` : ''}${
                props.address ? `<br/>${props.address}` : ''
              }`,
            ),
          )
          .addTo(map)
      }
    }

    Object.keys(hubMarkersRef.current).forEach((id) => {
      if (!seenIds.has(id)) {
        hubMarkersRef.current[id].remove()
        delete hubMarkersRef.current[id]
      }
    })
  }, [hubsGeoJSON])

  useEffect(() => {
    const map = mapRef.current
    if (!map) return

    waterFaultMarkersRef.current.forEach((marker) => marker.remove())
    waterFaultMarkersRef.current = []

    if (!conditions) return
    for (const fault of conditions.waterFaults) {
      if (fault.lat === null || fault.lng === null) continue
      const marker = new Marker({ element: createBadgeElement('🚰', '#0057a8') })
        .setLngLat([fault.lng, fault.lat])
        .setPopup(
          new Popup({ offset: 16, maxWidth: '280px' }).setHTML(
            `<strong>${fault.description ?? 'Water fault'}</strong>${
              fault.address ? `<br/>${fault.address}` : ''
            }${fault.status ? `<br/>${fault.status}` : ''}${
              fault.reportedAt ? `<br/><span style="color:#595959">${formatAge(fault.reportedAt)}</span>` : ''
            }`,
          ),
        )
        .addTo(map)
      waterFaultMarkersRef.current.push(marker)
    }
  }, [conditions])

  useEffect(() => {
    const map = mapRef.current
    if (!map) return

    let nonHomeIndex = 0
    const seenIds = new Set<string>()
    places.forEach((place) => {
      const color = colorForPlace(place, place.id === 'home' ? -1 : nonHomeIndex++)
      seenIds.add(place.id)
      const existing = markersRef.current[place.id]
      if (place.position && place.visible) {
        if (existing) {
          existing.setLngLat([place.position.lng, place.position.lat])
        } else {
          markersRef.current[place.id] = new Marker({ color })
            .setLngLat([place.position.lng, place.position.lat])
            .setPopup(new Popup({ offset: 16, maxWidth: '280px' }).setText(place.label))
            .addTo(map)
        }
      } else if (existing) {
        existing.remove()
        delete markersRef.current[place.id]
      }
    })

    Object.keys(markersRef.current).forEach((id) => {
      if (!seenIds.has(id)) {
        markersRef.current[id].remove()
        delete markersRef.current[id]
      }
    })
  }, [places])

  return (
    <div>
      <div className="relative">
        <div
          ref={containerRef}
          className={`h-[55dvh] min-h-[320px] w-full border-y-2 sm:h-[70dvh] ${
            armedSlot ? 'border-wcc-alert' : 'border-wcc-grey-light'
          }`}
        />
        {armedSlot && (
          <div className="absolute left-1/2 top-4 -translate-x-1/2 rounded-full bg-wcc-alert px-3 py-1 text-xs font-semibold text-wcc-white shadow">
            Tap the map to set {armedSlot}
          </div>
        )}
      </div>
      <p className="mx-auto max-w-5xl px-4 py-2 text-xs text-wcc-grey-dark sm:px-6">
        Map data © OpenFreeMap, © OpenStreetMap contributors.
      </p>
    </div>
  )
}
