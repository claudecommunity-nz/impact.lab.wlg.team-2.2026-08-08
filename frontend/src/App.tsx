import { useState } from 'react'
import { Header } from './components/Header'
import { StatusBlock } from './components/StatusBlock'
import { LiveConditions } from './components/LiveConditions'
import { LocationPicker } from './components/LocationPicker'
import { MapView } from './components/MapView'
import { RegionalWarnings } from './components/RegionalWarnings'
import { useGeolocation } from './hooks/useGeolocation'
import { useSavedLocations } from './hooks/useSavedLocations'
import type { LatLng } from './types'

function App() {
  const { position, status } = useGeolocation()
  const { places, addPlace, setPosition, toggleVisible, removePlace } = useSavedLocations()
  const [armedSlot, setArmedSlot] = useState<string | null>(null)

  function handleArm(id: string) {
    setArmedSlot((current) => (current === id ? null : id))
  }

  function handleMapClick(position: LatLng) {
    if (!armedSlot) return
    setPosition(armedSlot, position)
    setArmedSlot(null)
  }

  function handleAddPlace(label: string) {
    return addPlace(label)
  }

  return (
    <div className="min-h-screen bg-wcc-white pb-8">
      <Header />
      <StatusBlock position={position} locationStatus={status} />
      <LiveConditions position={position} locationStatus={status} />
      <LocationPicker
        places={places}
        armedSlot={armedSlot}
        onArm={handleArm}
        onToggleVisible={toggleVisible}
        onRemove={removePlace}
        onAddPlace={handleAddPlace}
      />
      <MapView
        center={position}
        places={places}
        armedSlot={armedSlot}
        onMapClick={handleMapClick}
      />
      <RegionalWarnings />
    </div>
  )
}

export default App
