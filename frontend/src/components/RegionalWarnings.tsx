import { regionalWarnings } from '../mockData/alerts'
import { AlertCard } from './AlertCard'

export function RegionalWarnings() {
  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <h2 className="mb-2 text-lg font-bold text-wcc-charcoal">
        Regional information and warnings
      </h2>
      <p className="mb-3 text-xs font-medium text-wcc-alert">
        Demo data — not live. Always check MetService and WCC directly for official advice. In
        an emergency, call 111.
      </p>
      <ul className="flex flex-col gap-2">
        {regionalWarnings.map((alert) => (
          <AlertCard key={alert.id} alert={alert} />
        ))}
      </ul>
    </section>
  )
}
