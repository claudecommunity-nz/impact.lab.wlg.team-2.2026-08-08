import { formatAge } from '../lib/time'
import type { ConditionsEnvelope } from '../api/types'

interface Props {
  conditions: ConditionsEnvelope
  emptyLabel?: string
}

export function ConditionsSections({ conditions, emptyLabel = 'None nearby.' }: Props) {
  return (
    <div className="flex flex-col gap-4">
      <div>
        <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">River &amp; rainfall gauges</h3>
        {conditions.gauges.length === 0 ? (
          <p className="text-xs text-wcc-grey-dark">{emptyLabel}</p>
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
          <p className="text-xs text-wcc-grey-dark">{emptyLabel}</p>
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
          <p className="text-xs text-wcc-grey-dark">{emptyLabel}</p>
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
  )
}
