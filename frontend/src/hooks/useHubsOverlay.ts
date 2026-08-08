import { useEffect, useState } from 'react'
import { fetchHubsGeoJSON } from '../api/client'
import type { FetchStatus, GeoJSONFeatureCollection } from '../api/types'

const EMPTY: GeoJSONFeatureCollection = { type: 'FeatureCollection', features: [] }

export function useHubsOverlay() {
  const [data, setData] = useState<GeoJSONFeatureCollection>(EMPTY)
  const [status, setStatus] = useState<FetchStatus>('loading')

  useEffect(() => {
    let cancelled = false
    fetchHubsGeoJSON()
      .then((collection) => {
        if (cancelled) return
        setData(collection)
        setStatus('ok')
      })
      .catch(() => {
        if (cancelled) return
        setStatus('error')
      })
    return () => {
      cancelled = true
    }
  }, [])

  return { data, status }
}
