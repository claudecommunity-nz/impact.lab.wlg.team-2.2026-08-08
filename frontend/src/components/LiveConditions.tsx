import { WELLINGTON_CBD } from '../constants'
import { useConditions } from '../hooks/useConditions'
import { ConditionsSections } from './ConditionsSections'
import type { GeolocationStatus } from '../hooks/useGeolocation'
import type { LatLng } from '../types'

interface Props {
  position: LatLng | null
  locationStatus: GeolocationStatus
}

const RADIUS_KM = 10

export function LiveConditions({ position, locationStatus }: Props) {
  const resolved = locationStatus === 'loading' ? null : (position ?? WELLINGTON_CBD)
  const { conditions, status } = useConditions(resolved?.lat, resolved?.lng)

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <h2 className="mb-3 text-lg font-bold text-wcc-charcoal">Live conditions near you</h2>

      {status === 'loading' && <p className="text-sm text-wcc-grey-dark">Checking live conditions…</p>}
      {status === 'error' && (
        <p className="text-sm font-medium text-wcc-alert">Can&apos;t reach the conditions feed.</p>
      )}

      {status === 'ok' && conditions && (
        <ConditionsSections conditions={conditions} emptyLabel={`None within ${RADIUS_KM} km.`} />
      )}
    </section>
  )
}
