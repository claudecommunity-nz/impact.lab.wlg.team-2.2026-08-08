import { useEffect, useState } from 'react'
import type { LatLng } from '../types'

export type GeolocationStatus = 'loading' | 'granted' | 'denied' | 'unsupported'

export function useGeolocation() {
  const [position, setPosition] = useState<LatLng | null>(null)
  const [status, setStatus] = useState<GeolocationStatus>('loading')

  useEffect(() => {
    if (!('geolocation' in navigator)) {
      setStatus('unsupported')
      return
    }

    navigator.geolocation.getCurrentPosition(
      (result) => {
        setPosition({ lat: result.coords.latitude, lng: result.coords.longitude })
        setStatus('granted')
      },
      () => {
        setStatus('denied')
      },
      { enableHighAccuracy: false, timeout: 8000 },
    )
  }, [])

  return { position, status }
}
