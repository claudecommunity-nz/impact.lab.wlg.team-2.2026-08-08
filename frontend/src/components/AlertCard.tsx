import type { AlertItem } from '../types'

const severityStyles: Record<AlertItem['severity'], string> = {
  warning: 'border-wcc-alert bg-orange-50',
  watch: 'border-wcc-link bg-blue-50',
  advisory: 'border-wcc-grey-mid bg-gray-50',
}

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-NZ', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function AlertCard({ alert }: { alert: AlertItem }) {
  return (
    <li className={`rounded-lg border-l-4 p-3 shadow-sm ${severityStyles[alert.severity]}`}>
      <div className="flex items-center justify-between gap-2 text-xs">
        <span className="font-semibold uppercase tracking-wide text-wcc-grey-dark">
          {alert.source}
        </span>
        <span
          className={`rounded-full px-2 py-0.5 font-medium text-wcc-white ${
            alert.isOfficial ? 'bg-wcc-link' : 'bg-wcc-alert'
          }`}
        >
          {alert.isOfficial ? 'Official' : 'Unverified report'}
        </span>
      </div>
      <p className="mt-1.5 text-sm font-medium text-wcc-charcoal">{alert.headline}</p>
      <div className="mt-1.5 flex items-center gap-2 text-xs text-wcc-grey-dark">
        <span>{formatTime(alert.time)}</span>
        {alert.distanceKm !== undefined && <span>· {alert.distanceKm} km away</span>}
      </div>
    </li>
  )
}
