import { useEffect, useRef } from 'react'
import { Map as MapLibreMap, Marker, NavigationControl, Popup, type MapMouseEvent } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { LatLng, Place } from '../types'

const WELLINGTON_CBD: LatLng = { lat: -41.2865, lng: 174.7762 }
const STYLE_URL = 'https://tiles.openfreemap.org/styles/liberty'

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

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return
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

    mapRef.current = map
    return () => {
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
