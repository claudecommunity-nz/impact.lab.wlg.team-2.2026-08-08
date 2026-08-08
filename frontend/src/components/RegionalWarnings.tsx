import { isWellingtonWarning } from '../api/adapters'
import { useWarnings } from '../hooks/useWarnings'
import { AlertCard } from './AlertCard'

export function RegionalWarnings() {
  const { alerts, status, errorMessage } = useWarnings({ filter: isWellingtonWarning })

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <h2 className="mb-2 text-lg font-bold text-wcc-charcoal">
        Regional information and warnings
      </h2>
      <p className="mb-3 text-xs text-wcc-grey-dark">
        Official warnings mentioning Wellington. Always check MetService and WCC directly. In an
        emergency, call 111.
      </p>

      {status === 'loading' && <p className="text-sm text-wcc-grey-dark">Checking regional warnings…</p>}
      {status === 'error' && (
        <p className="text-sm font-medium text-wcc-alert">
          Can&apos;t reach the alerts service{errorMessage ? ` (${errorMessage})` : ''}.
        </p>
      )}
      {status === 'ok' && alerts.length === 0 && (
        <p className="text-sm text-wcc-charcoal">No official warnings currently cover the Wellington region.</p>
      )}
      {status === 'ok' && alerts.length > 0 && (
        <ul className="flex flex-col gap-2">
          {alerts.map((alert) => (
            <AlertCard key={alert.id} alert={alert} />
          ))}
        </ul>
      )}
    </section>
  )
}
