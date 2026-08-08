import { useEffect, useState } from 'react'
import { fetchWarnings } from '../api/client'
import { severityRank } from '../api/adapters'
import type { Warning } from '../api/types'

export type FetchStatus = 'loading' | 'ok' | 'error'

export function useLocationWarnings(lat: number | undefined, lng: number | undefined) {
  const [warnings, setWarnings] = useState<Warning[]>([])
  const [status, setStatus] = useState<FetchStatus>('loading')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    if (lat === undefined || lng === undefined) return
    let cancelled = false
    setStatus('loading')
    fetchWarnings({ lat, lng })
      .then((envelope) => {
        if (cancelled) return
        setWarnings([...envelope.items].sort((a, b) => severityRank(b) - severityRank(a)))
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
  }, [lat, lng])

  return { warnings, status, errorMessage }
}
