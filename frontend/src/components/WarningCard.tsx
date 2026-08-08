import { formatAge, formatUntil } from '../lib/time'
import type { Warning } from '../api/types'

export function WarningCard({ warning }: { warning: Warning }) {
  return (
    <li className="rounded-lg border-l-4 border-wcc-alert bg-orange-50 p-3 shadow-sm">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="text-base font-bold text-wcc-charcoal">{warning.event}</h3>
        <div className="flex gap-1.5 text-xs">
          {warning.severity && (
            <span className="rounded-full bg-wcc-alert px-2 py-0.5 font-medium text-wcc-white">
              {warning.severity}
            </span>
          )}
          {warning.urgency && (
            <span className="rounded-full bg-wcc-grey-mid px-2 py-0.5 font-medium text-wcc-white">
              {warning.urgency}
            </span>
          )}
        </div>
      </div>

      {warning.expires && <p className="mt-1 text-xs text-wcc-grey-dark">{formatUntil(warning.expires)}</p>}
      {warning.headline && <p className="mt-1.5 text-sm text-wcc-charcoal">{warning.headline}</p>}

      {warning.description && (
        <details className="mt-1.5 text-xs text-wcc-grey-dark">
          <summary className="cursor-pointer font-medium text-wcc-link">more</summary>
          <p className="mt-1">{warning.description}</p>
        </details>
      )}

      {warning.web && (
        <a
          href={warning.web}
          target="_blank"
          rel="noreferrer"
          className="mt-1.5 inline-block text-xs font-medium text-wcc-link hover:text-wcc-link-hover"
        >
          {warning.source.name} ↗
        </a>
      )}

      <div className="mt-1.5 text-xs text-wcc-grey-dark">
        {warning.source.name} · {formatAge(warning.source.fetchedAt)}
      </div>
    </li>
  )
}
