import { useEffect, useState } from 'react'
import { fetchWarnings } from '../api/client'
import { pickWorstWarning } from '../api/adapters'
import type { Warning } from '../api/types'
import type { Place } from '../types'
import type { FetchStatus } from './useLocationWarnings'

interface PlaceStatus {
  status: FetchStatus
  worst: Warning | null
}

export function useFavouriteWarnings(places: Place[]) {
  const [statusById, setStatusById] = useState<Record<string, PlaceStatus>>({})

  const positioned = places.filter((place) => place.position)
  const key = positioned.map((place) => `${place.id}:${place.position!.lat},${place.position!.lng}`).join('|')

  useEffect(() => {
    let cancelled = false
    positioned.forEach((place) => {
      setStatusById((prev) => ({ ...prev, [place.id]: { status: 'loading', worst: prev[place.id]?.worst ?? null } }))
      fetchWarnings({ lat: place.position!.lat, lng: place.position!.lng })
        .then((envelope) => {
          if (cancelled) return
          setStatusById((prev) => ({ ...prev, [place.id]: { status: 'ok', worst: pickWorstWarning(envelope.items) } }))
        })
        .catch(() => {
          if (cancelled) return
          setStatusById((prev) => ({ ...prev, [place.id]: { status: 'error', worst: null } }))
        })
    })
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key])

  return statusById
}
