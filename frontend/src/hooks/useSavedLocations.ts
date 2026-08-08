import { useEffect, useState } from 'react'
import type { LatLng, Place } from '../types'

const STORAGE_KEY = 'wellyalerts.places'

const DEFAULT_PLACES: Place[] = [{ id: 'home', label: 'Home', position: null, visible: true }]

function generateId(): string {
  return `place-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
}

function load(): Place[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return DEFAULT_PLACES
    const parsed = JSON.parse(raw) as Place[]
    return parsed.length ? parsed : DEFAULT_PLACES
  } catch {
    return DEFAULT_PLACES
  }
}

export function useSavedLocations() {
  const [places, setPlaces] = useState<Place[]>(load)

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(places))
  }, [places])

  function addPlace(label: string): string {
    const id = generateId()
    setPlaces((prev) => [...prev, { id, label, position: null, visible: true }])
    return id
  }

  function setPosition(id: string, position: LatLng) {
    setPlaces((prev) => prev.map((p) => (p.id === id ? { ...p, position, visible: true } : p)))
  }

  function toggleVisible(id: string) {
    setPlaces((prev) => prev.map((p) => (p.id === id ? { ...p, visible: !p.visible } : p)))
  }

  function removePlace(id: string) {
    if (id === 'home') return
    setPlaces((prev) => prev.filter((p) => p.id !== id))
  }

  return { places, addPlace, setPosition, toggleVisible, removePlace }
}
