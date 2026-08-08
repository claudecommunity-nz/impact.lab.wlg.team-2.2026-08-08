import type { DemoCatalog, FetchStatus } from '../api/types'

interface Props {
  catalog: DemoCatalog | null
  catalogStatus: FetchStatus
  enabled: boolean
  scenarioId: string | null
  pointId: string | null
  onToggle: (enabled: boolean) => void
  onSelect: (scenarioId: string, pointId: string) => void
}

export function DemoModeControls({
  catalog,
  catalogStatus,
  enabled,
  scenarioId,
  pointId,
  onToggle,
  onSelect,
}: Props) {
  const selectedScenario = catalog?.scenarios.find((scenario) => scenario.id === scenarioId) ?? null

  return (
    <section className="mx-auto w-full max-w-5xl px-4 pt-4 sm:px-6">
      <div className="rounded-lg border-2 border-dashed border-wcc-grey-mid bg-wcc-grey-light/10 p-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <span className="text-sm font-bold text-wcc-charcoal">🧪 Demo data</span>
            <p className="text-xs text-wcc-grey-dark">
              {catalogStatus === 'error'
                ? "Can't reach the demo data endpoint."
                : catalogStatus === 'loading'
                  ? 'Loading demo data…'
                  : 'Curated, offline scenarios for the pitch — not live.'}
            </p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={enabled}
            disabled={catalogStatus !== 'ok'}
            onClick={() => onToggle(!enabled)}
            className={`rounded-full px-4 py-1.5 text-sm font-semibold transition disabled:cursor-not-allowed disabled:opacity-50 ${
              enabled ? 'bg-wcc-alert text-wcc-white' : 'border border-wcc-grey-mid text-wcc-grey-dark'
            }`}
          >
            {enabled ? 'Demo data: ON' : 'Demo data: OFF'}
          </button>
        </div>

        {enabled && catalog && (
          <div className="mt-3 flex flex-col gap-2">
            <div className="flex flex-wrap gap-2">
              {catalog.scenarios.map((scenario) => (
                <button
                  key={scenario.id}
                  type="button"
                  title={scenario.description}
                  onClick={() => {
                    const keepPoint = scenario.points.some((p) => p.id === pointId)
                      ? pointId!
                      : (scenario.points[0]?.id ?? '')
                    onSelect(scenario.id, keepPoint)
                  }}
                  className={`rounded-full border px-3 py-1 text-xs font-medium ${
                    scenario.id === scenarioId
                      ? 'border-wcc-link bg-wcc-link text-wcc-white'
                      : 'border-wcc-grey-mid text-wcc-grey-dark hover:border-wcc-link hover:text-wcc-link'
                  }`}
                >
                  {scenario.title}
                </button>
              ))}
            </div>
            {selectedScenario && (
              <div className="flex flex-wrap gap-2">
                {selectedScenario.points.map((point) => (
                  <button
                    key={point.id}
                    type="button"
                    onClick={() => onSelect(selectedScenario.id, point.id)}
                    className={`rounded-full border px-3 py-1 text-xs font-medium ${
                      point.id === pointId
                        ? 'border-wcc-yellow bg-wcc-yellow text-wcc-charcoal'
                        : 'border-wcc-grey-mid text-wcc-grey-dark hover:border-wcc-link hover:text-wcc-link'
                    }`}
                  >
                    📍 {point.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </section>
  )
}
