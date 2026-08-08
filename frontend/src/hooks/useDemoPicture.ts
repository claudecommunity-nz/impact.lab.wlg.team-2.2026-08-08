import { useEffect, useState } from 'react'
import { fetchDemoPicture } from '../api/client'
import type { FetchStatus, LocationPicture } from '../api/types'

export function useDemoPicture(scenario: string | null, point: string | null) {
  const [picture, setPicture] = useState<LocationPicture | null>(null)
  const [status, setStatus] = useState<FetchStatus>('loading')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    if (!scenario || !point) return
    let cancelled = false
    setStatus('loading')
    fetchDemoPicture({ scenario, point })
      .then((result) => {
        if (cancelled) return
        setPicture(result)
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
  }, [scenario, point])

  return { picture, status, errorMessage }
}
