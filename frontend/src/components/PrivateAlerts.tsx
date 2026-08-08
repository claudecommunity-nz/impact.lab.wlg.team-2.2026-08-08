import { privateAlerts } from '../mockData/alerts'
import { AlertCard } from './AlertCard'
import type { GeolocationStatus } from '../hooks/useGeolocation'

const statusText: Record<GeolocationStatus, string> = {
  loading: 'Finding your location…',
  granted: 'Using your approximate location',
  denied: 'Location unavailable — showing Wellington CBD',
  unsupported: 'Location not supported on this device',
}

export function PrivateAlerts({ locationStatus }: { locationStatus: GeolocationStatus }) {
  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <div className="mb-2 flex flex-wrap items-baseline justify-between gap-1">
        <h2 className="text-lg font-bold text-wcc-charcoal">Near you</h2>
        <span className="text-xs text-wcc-grey-dark">{statusText[locationStatus]}</span>
      </div>
      <p className="mb-3 text-xs font-medium text-wcc-alert">
        Demo data — not live. These cards show the shape of the real feed.
      </p>
      <ul className="flex flex-col gap-2">
        {privateAlerts.map((alert) => (
          <AlertCard key={alert.id} alert={alert} />
        ))}
      </ul>
    </section>
  )
}
