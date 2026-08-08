import { useEffect, useState } from 'react'
import { fetchWarnings } from '../api/client'
import { severityRank } from '../api/adapters'
import type { FetchStatus, Warning } from '../api/types'

export interface LocationPin {
  id: string
  label: string
  lat: number
  lng: number
}

export interface WarningWithLocations {
  warning: Warning
  locationLabels: string[]
}

export function useWarningsByLocation(pins: LocationPin[]) {
  const [entries, setEntries] = useState<WarningWithLocations[]>([])
  const [status, setStatus] = useState<FetchStatus>('loading')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const key = pins.map((pin) => `${pin.id}:${pin.lat},${pin.lng}`).join('|')

  useEffect(() => {
    if (pins.length === 0) {
      setEntries([])
      setStatus('ok')
      return
    }
    let cancelled = false
    setStatus('loading')
    Promise.allSettled(
      pins.map((pin) => fetchWarnings({ lat: pin.lat, lng: pin.lng }).then((envelope) => ({ pin, items: envelope.items }))),
    ).then((results) => {
      if (cancelled) return
      const byId = new Map<string, WarningWithLocations>()
      let firstError: string | null = null
      let anySucceeded = false

      for (const result of results) {
        if (result.status === 'rejected') {
          if (!firstError) {
            firstError = result.reason instanceof Error ? result.reason.message : 'Unknown error'
          }
          continue
        }
        anySucceeded = true
        const { pin, items } = result.value
        for (const warning of items) {
          const existing = byId.get(warning.id)
          if (existing) {
            if (!existing.locationLabels.includes(pin.label)) existing.locationLabels.push(pin.label)
          } else {
            byId.set(warning.id, { warning, locationLabels: [pin.label] })
          }
        }
      }

      setEntries([...byId.values()].sort((a, b) => severityRank(b.warning) - severityRank(a.warning)))
      if (anySucceeded) {
        setStatus('ok')
      } else {
        setErrorMessage(firstError)
        setStatus('error')
      }
    })
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key])

  return { entries, status, errorMessage }
}
