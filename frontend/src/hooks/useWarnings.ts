import { useEffect, useState } from 'react'
import { fetchWarnings } from '../api/client'
import { warningToAlertItem } from '../api/adapters'
import type { Warning } from '../api/types'
import type { AlertItem } from '../types'
import type { FetchStatus } from './useLocationWarnings'

interface Params {
  lat?: number
  lng?: number
  filter?: (warning: Warning) => boolean
}

export function useWarnings({ lat, lng, filter }: Params) {
  const [alerts, setAlerts] = useState<AlertItem[]>([])
  const [status, setStatus] = useState<FetchStatus>('loading')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setStatus('loading')
    fetchWarnings({ lat, lng })
      .then((envelope) => {
        if (cancelled) return
        const items = filter ? envelope.items.filter(filter) : envelope.items
        setAlerts(items.map(warningToAlertItem))
        setStatus('ok')
      })
      .catch((error: unknown) => {
        if (cancelled) return
        setErrorMessage(error instanceof Error ? error.message : 'Unknown error')
        setStatus('error')
      })
    return () => {
      cancelled = true
    }
    // filter is expected to be a stable/inline predicate; only lat/lng should retrigger a fetch
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lat, lng])

  return { alerts, status, errorMessage }
}
