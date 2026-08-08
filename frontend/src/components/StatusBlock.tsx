import { WELLINGTON_CBD } from '../constants'
import { API_BASE } from '../api/client'
import { useWarningsByLocation } from '../hooks/useWarningsByLocation'
import { WarningCard } from './WarningCard'
import type { GeolocationStatus } from '../hooks/useGeolocation'
import type { LocationPin } from '../hooks/useWarningsByLocation'
import type { LatLng, Place } from '../types'

interface Props {
  position: LatLng | null
  locationStatus: GeolocationStatus
  places: Place[]
}

export function StatusBlock({ position, locationStatus, places }: Props) {
  const resolved = locationStatus === 'loading' ? null : (position ?? WELLINGTON_CBD)

  const pins: LocationPin[] = []
  if (resolved) {
    pins.push({
      id: 'current',
      label: locationStatus === 'granted' ? 'Your location' : 'Wellington CBD',
      lat: resolved.lat,
      lng: resolved.lng,
    })
  }
  for (const place of places) {
    if (place.position) {
      pins.push({ id: place.id, label: place.label, lat: place.position.lat, lng: place.position.lng })
    }
  }

  const { entries, status, errorMessage } = useWarningsByLocation(pins)

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <h2 className="mb-1 text-lg font-bold text-wcc-charcoal">Warnings for your places</h2>
      <p className="mb-3 text-xs text-wcc-grey-dark">
        Covers your current location
        {locationStatus === 'loading'
          ? ' (finding it…)'
          : locationStatus === 'granted'
            ? ''
            : ' (unavailable — showing Wellington CBD)'}{' '}
        and everywhere you&apos;ve saved below.
      </p>

      {pins.length === 0 && (
        <p className="text-sm text-wcc-grey-dark">Add a place or allow location access to see warnings.</p>
      )}

      {pins.length > 0 && status === 'loading' && (
        <p className="text-sm text-wcc-grey-dark">Checking official warnings…</p>
      )}

      {status === 'error' && (
        <p className="text-sm font-medium text-wcc-alert">
          Can&apos;t reach the alerts service at {API_BASE}
          {errorMessage ? ` (${errorMessage})` : ''}.
        </p>
      )}

      {status === 'ok' && entries.length === 0 && pins.length > 0 && (
        <p className="text-sm text-wcc-charcoal">
          No official warnings cover your location or saved places right now.
        </p>
      )}

      {status === 'ok' && entries.length > 0 && (
        <ul className="flex flex-col gap-2">
          {entries.map(({ warning, locationLabels }) => (
            <WarningCard key={warning.id} warning={warning} locationLabels={locationLabels} />
          ))}
        </ul>
      )}
    </section>
  )
}
