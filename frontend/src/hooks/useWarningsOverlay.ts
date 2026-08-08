import { useEffect, useState } from 'react'
import { fetchWarningsGeoJSON } from '../api/client'
import type { FetchStatus, GeoJSONFeatureCollection } from '../api/types'

const EMPTY: GeoJSONFeatureCollection = { type: 'FeatureCollection', features: [] }

export function useWarningsOverlay() {
  const [data, setData] = useState<GeoJSONFeatureCollection>(EMPTY)
  const [status, setStatus] = useState<FetchStatus>('loading')

  useEffect(() => {
    let cancelled = false
    fetchWarningsGeoJSON()
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
