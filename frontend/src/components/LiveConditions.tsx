import { WELLINGTON_CBD } from '../constants'
import { useConditions } from '../hooks/useConditions'
import { formatAge } from '../lib/time'
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
        <div className="flex flex-col gap-4">
          <div>
            <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">River &amp; rainfall gauges</h3>
            {conditions.gauges.length === 0 ? (
              <p className="text-xs text-wcc-grey-dark">None within {RADIUS_KM} km.</p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {conditions.gauges.map((gauge, index) => (
                  <li key={`${gauge.site}-${index}`} className="text-sm text-wcc-charcoal">
                    <span className="font-medium">{gauge.site}</span> · {gauge.measurement} {gauge.value}{' '}
                    {gauge.units}
                    {gauge.trend ? ` · ${gauge.trend}` : ''} · {gauge.distanceKm.toFixed(1)} km away ·{' '}
                    <span className="text-wcc-grey-dark">{formatAge(gauge.observedAt)}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div>
            <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">Electricity outages</h3>
            {conditions.electricityOutages.length === 0 ? (
              <p className="text-xs text-wcc-grey-dark">None within {RADIUS_KM} km.</p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {conditions.electricityOutages.map((outage, index) => (
                  <li key={index} className="text-sm text-wcc-charcoal">
                    <span className="font-medium">{outage.locationName ?? 'Unknown location'}</span>
                    {outage.numAffected !== null ? ` · ${outage.numAffected} affected` : ''} ·{' '}
                    {outage.distanceKm.toFixed(1)} km away
                    {outage.startedAt ? (
                      <>
                        {' '}
                        · <span className="text-wcc-grey-dark">{formatAge(outage.startedAt)}</span>
                      </>
                    ) : null}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div>
            <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">Water faults</h3>
            {conditions.waterFaults.length === 0 ? (
              <p className="text-xs text-wcc-grey-dark">None within {RADIUS_KM} km.</p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {conditions.waterFaults.map((fault, index) => (
                  <li key={index} className="text-sm text-wcc-charcoal">
                    <span className="font-medium">{fault.description ?? 'Water fault'}</span>
                    {fault.address ? ` · ${fault.address}` : ''}
                    {fault.status ? ` · ${fault.status}` : ''} · {fault.distanceKm.toFixed(1)} km away
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      )}
    </section>
  )
}
