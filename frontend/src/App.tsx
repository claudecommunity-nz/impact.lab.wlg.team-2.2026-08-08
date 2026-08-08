import { useEffect, useState } from 'react'
import { Header } from './components/Header'
import { StatusBlock } from './components/StatusBlock'
import { LiveConditions } from './components/LiveConditions'
import { DemoModeControls } from './components/DemoModeControls'
import { DemoPicture } from './components/DemoPicture'
import { LocationPicker } from './components/LocationPicker'
import { MapView } from './components/MapView'
import { RegionalWarnings } from './components/RegionalWarnings'
import { useGeolocation } from './hooks/useGeolocation'
import { useSavedLocations } from './hooks/useSavedLocations'
import { useDemoCatalog } from './hooks/useDemoCatalog'
import { useDemoMode } from './hooks/useDemoMode'
import type { LatLng } from './types'

function App() {
  const { position, status } = useGeolocation()
  const { places, addPlace, setPosition, toggleVisible, removePlace } = useSavedLocations()
  const [armedSlot, setArmedSlot] = useState<string | null>(null)

  const { catalog, status: catalogStatus } = useDemoCatalog()
  const demoMode = useDemoMode()

  useEffect(() => {
    if (demoMode.scenarioId || !catalog) return
    const firstScenario = catalog.scenarios[0]
    const firstPoint = firstScenario?.points[0]
    if (firstScenario && firstPoint) {
      demoMode.setSelection(firstScenario.id, firstPoint.id)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [catalog, demoMode.scenarioId])

  const selectedScenario = catalog?.scenarios.find((scenario) => scenario.id === demoMode.scenarioId) ?? null
  const selectedPoint = selectedScenario?.points.find((point) => point.id === demoMode.pointId) ?? null
  const mapCenter = demoMode.enabled && selectedPoint ? { lat: selectedPoint.lat, lng: selectedPoint.lng } : position

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
      <DemoModeControls
        catalog={catalog}
        catalogStatus={catalogStatus}
        enabled={demoMode.enabled}
        scenarioId={demoMode.scenarioId}
        pointId={demoMode.pointId}
        onToggle={demoMode.setEnabled}
        onSelect={demoMode.setSelection}
      />
      {demoMode.enabled ? (
        <DemoPicture
          scenario={demoMode.scenarioId}
          point={demoMode.pointId}
          scenarioTitle={selectedScenario?.title}
          pointName={selectedPoint?.name}
        />
      ) : (
        <>
          <StatusBlock position={position} locationStatus={status} places={places} />
          <LiveConditions position={position} locationStatus={status} />
        </>
      )}
      <LocationPicker
        places={places}
        armedSlot={armedSlot}
        onArm={handleArm}
        onToggleVisible={toggleVisible}
        onRemove={removePlace}
        onAddPlace={handleAddPlace}
      />
      <MapView
        center={mapCenter}
        places={places}
        armedSlot={armedSlot}
        onMapClick={handleMapClick}
      />
      <RegionalWarnings />
    </div>
  )
}

export default App
