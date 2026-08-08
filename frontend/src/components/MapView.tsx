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
  const onMapClickRef = useRef(onMapClick)
  onMapClickRef.current = onMapClick

  const { data: warningsGeoJSON } = useWarningsOverlay()
  const { data: hubsGeoJSON } = useHubsOverlay()
  const warningsDataRef = useRef(warningsGeoJSON)
  warningsDataRef.current = warningsGeoJSON
  const hubsDataRef = useRef(hubsGeoJSON)
  hubsDataRef.current = hubsGeoJSON

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return
    let cancelled = false
    const start = center ?? WELLINGTON_CBD
    const map = new MapLibreMap({
      container: containerRef.current,
      style: STYLE_URL,
      center: [start.lng, start.lat],
      zoom: 15,
    })
    map.addControl(new NavigationControl(), 'top-right')
    requestAnimationFrame(() => map.resize())

    youMarkerRef.current = new Marker({ color: '#2f2f2f' })
      .setLngLat([start.lng, start.lat])
      .setPopup(new Popup({ offset: 16 }).setText('Approximate location'))
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

      map.addSource('hubs', {
        type: 'geojson',
        data: hubsDataRef.current as unknown as GeoJSON.FeatureCollection,
      })
      map.addLayer({
        id: 'hubs-points',
        type: 'circle',
        source: 'hubs',
        paint: {
          'circle-radius': 5,
          'circle-color': '#0057a8',
          'circle-stroke-width': 1.5,
          'circle-stroke-color': '#ffffff',
        },
      })

      map.on('click', 'warnings-fill', (event) => {
        const props = event.features?.[0]?.properties
        if (!props) return
        new Popup({ offset: 12 })
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

      map.on('click', 'hubs-points', (event) => {
        const props = event.features?.[0]?.properties
        if (!props) return
        new Popup({ offset: 12 })
          .setLngLat(event.lngLat)
          .setHTML(
            `<strong>${props.name}</strong>${props.type ? `<br/>${props.type}` : ''}${
              props.address ? `<br/>${props.address}` : ''
            }`,
          )
          .addTo(map)
      })
      map.on('mouseenter', 'hubs-points', () => {
        map.getCanvas().style.cursor = 'pointer'
      })
      map.on('mouseleave', 'hubs-points', () => {
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
    const source = mapRef.current?.getSource('hubs') as GeoJSONSource | undefined
    source?.setData(hubsGeoJSON as unknown as GeoJSON.FeatureCollection)
  }, [hubsGeoJSON])

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
            .setPopup(new Popup({ offset: 16 }).setText(place.label))
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
          className={`h-[70vh] min-h-[420px] w-full border-y-2 ${
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
