import { WELLINGTON_CBD } from '../constants'
import { API_BASE } from '../api/client'
import { useLocationWarnings } from '../hooks/useLocationWarnings'
import { WarningCard } from './WarningCard'
import type { GeolocationStatus } from '../hooks/useGeolocation'
import type { LatLng } from '../types'

interface Props {
  position: LatLng | null
  locationStatus: GeolocationStatus
}

export function StatusBlock({ position, locationStatus }: Props) {
  const resolved = locationStatus === 'loading' ? null : (position ?? WELLINGTON_CBD)
  const { warnings, status, errorMessage } = useLocationWarnings(resolved?.lat, resolved?.lng)

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <h2 className="mb-1 text-lg font-bold text-wcc-charcoal">Right now at your location</h2>
      <p className="mb-3 text-xs text-wcc-grey-dark">
        {locationStatus === 'granted'
          ? 'Using your approximate location'
          : locationStatus === 'loading'
            ? 'Finding your location…'
            : 'Location unavailable — showing Wellington CBD'}
      </p>

      {resolved === null && <p className="text-sm text-wcc-grey-dark">Finding your location…</p>}

      {resolved !== null && status === 'loading' && (
        <p className="text-sm text-wcc-grey-dark">Checking official warnings…</p>
      )}

      {status === 'error' && (
        <p className="text-sm font-medium text-wcc-alert">
          Can&apos;t reach the alerts service at {API_BASE}
          {errorMessage ? ` (${errorMessage})` : ''}.
        </p>
      )}

      {status === 'ok' && warnings.length === 0 && (
        <p className="text-sm text-wcc-charcoal">No official warnings cover this location right now.</p>
      )}

      {status === 'ok' && warnings.length > 0 && (
        <ul className="flex flex-col gap-2">
          {warnings.map((warning) => (
            <WarningCard key={warning.id} warning={warning} />
          ))}
        </ul>
      )}
    </section>
  )
}
