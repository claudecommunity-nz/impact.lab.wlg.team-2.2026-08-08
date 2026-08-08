import { formatAge } from '../lib/time'
import { useDemoPicture } from '../hooks/useDemoPicture'
import { ConditionsSections } from './ConditionsSections'
import { WarningCard } from './WarningCard'

interface Props {
  scenario: string | null
  point: string | null
  scenarioTitle?: string
  pointName?: string
}

export function DemoPicture({ scenario, point, scenarioTitle, pointName }: Props) {
  const { picture, status, errorMessage } = useDemoPicture(scenario, point)

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <div className="mb-3 rounded-lg border-2 border-dashed border-wcc-alert bg-orange-50 px-3 py-2 text-xs font-medium text-wcc-charcoal">
        🧪 Showing demo data{scenarioTitle ? ` — ${scenarioTitle}` : ''}
        {pointName ? ` at ${pointName}` : ''}. Not live.
      </div>

      {status === 'loading' && <p className="text-sm text-wcc-grey-dark">Loading demo picture…</p>}
      {status === 'error' && (
        <p className="text-sm font-medium text-wcc-alert">
          Can&apos;t reach the demo data endpoint{errorMessage ? ` (${errorMessage})` : ''}.
        </p>
      )}

      {status === 'ok' && picture && (
        <div className="flex flex-col gap-5">
          {picture.location.nearestHub && (
            <p className="text-sm text-wcc-charcoal">
              Nearest hub: <span className="font-medium">{picture.location.nearestHub.name}</span>
              {picture.location.nearestHub.address ? `, ${picture.location.nearestHub.address}` : ''} ·{' '}
              {picture.location.nearestHub.distanceKm.toFixed(1)} km away
            </p>
          )}

          <div>
            <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">Official warnings</h3>
            {picture.officialWarnings.status === 'unavailable' ? (
              <p className="text-sm font-medium text-wcc-alert">
                Warnings unavailable
                {picture.officialWarnings.reason ? ` — ${picture.officialWarnings.reason}` : ''}.
              </p>
            ) : picture.officialWarnings.items.length === 0 ? (
              <p className="text-sm text-wcc-charcoal">No official warnings cover this location.</p>
            ) : (
              <ul className="flex flex-col gap-2">
                {picture.officialWarnings.items.map((warning) => (
                  <WarningCard key={warning.id} warning={warning} />
                ))}
              </ul>
            )}
          </div>

          <div>
            <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">Local conditions</h3>
            {picture.localConditions.status === 'unavailable' ? (
              <p className="text-sm font-medium text-wcc-alert">
                Conditions unavailable
                {picture.localConditions.reason ? ` — ${picture.localConditions.reason}` : ''}.
              </p>
            ) : (
              <ConditionsSections conditions={picture.localConditions} />
            )}
          </div>

          <div>
            <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">Hazard context</h3>
            <p className="mb-1.5 text-xs text-wcc-grey-dark">{picture.hazardContext.note}</p>
            {picture.hazardContext.items.length === 0 ? (
              <p className="text-sm text-wcc-charcoal">No planning hazard layers cover this location.</p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {picture.hazardContext.items.map((item, index) => (
                  <li key={`${item.id}-${index}`} className="text-sm text-wcc-charcoal">
                    <span className="font-medium">{item.layer}</span>: {item.value}
                    {item.detail ? ` (${item.detail})` : ''} ·{' '}
                    <span className="text-wcc-grey-dark">
                      {item.publisher} · {formatAge(item.source.fetchedAt)}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {picture.summary.length > 0 && (
            <div>
              <h3 className="mb-1 text-sm font-semibold text-wcc-charcoal">Summary</h3>
              <ul className="list-disc pl-5 text-sm text-wcc-charcoal">
                {picture.summary.map((line, index) => (
                  <li key={index}>{line}</li>
                ))}
              </ul>
            </div>
          )}

          <p className="text-xs text-wcc-grey-dark">{picture.disclaimer}</p>
        </div>
      )}
    </section>
  )
}
