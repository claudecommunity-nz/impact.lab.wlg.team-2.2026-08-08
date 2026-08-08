import { useEffect, useState } from 'react'
import { fetchDemoScenarios } from '../api/client'
import type { DemoCatalog, FetchStatus } from '../api/types'

export function useDemoCatalog() {
  const [catalog, setCatalog] = useState<DemoCatalog | null>(null)
  const [status, setStatus] = useState<FetchStatus>('loading')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchDemoScenarios()
      .then((result) => {
        if (cancelled) return
        setCatalog(result)
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
  }, [])

  return { catalog, status, errorMessage }
}
