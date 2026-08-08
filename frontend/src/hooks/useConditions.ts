import { useEffect, useState } from 'react'
import { fetchConditions } from '../api/client'
import type { ConditionsEnvelope } from '../api/types'
import type { FetchStatus } from './useLocationWarnings'

export function useConditions(lat: number | undefined, lng: number | undefined) {
  const [conditions, setConditions] = useState<ConditionsEnvelope | null>(null)
  const [status, setStatus] = useState<FetchStatus>('loading')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    if (lat === undefined || lng === undefined) return
    let cancelled = false
    setStatus('loading')
    fetchConditions({ lat, lng })
      .then((envelope) => {
        if (cancelled) return
        setConditions(envelope)
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

  return { conditions, status, errorMessage }
}
