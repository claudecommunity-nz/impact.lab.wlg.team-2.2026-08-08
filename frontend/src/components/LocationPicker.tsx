import { useState } from 'react'
import type { Place } from '../types'

interface Props {
  places: Place[]
  armedSlot: string | null
  onArm: (id: string) => void
  onToggleVisible: (id: string) => void
  onRemove: (id: string) => void
  onAddPlace: (label: string) => string
}

export function LocationPicker({
  places,
  armedSlot,
  onArm,
  onToggleVisible,
  onRemove,
  onAddPlace,
}: Props) {
  const [isAdding, setIsAdding] = useState(false)
  const [newLabel, setNewLabel] = useState('')

  function submitNewPlace() {
    const label = newLabel.trim()
    if (!label) return
    const id = onAddPlace(label)
    onArm(id)
    setNewLabel('')
    setIsAdding(false)
  }

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-4 sm:px-6">
      <h2 className="mb-1 text-lg font-bold text-wcc-charcoal">Your places</h2>
      <p className="mb-3 text-xs text-wcc-grey-dark">
        Set Home so we can show what&apos;s happening near you, then add anywhere else you care
        about. Tap a place, then tap the map to set it.
      </p>
      <div className="flex flex-wrap items-center gap-2">
        {places.map((place) => {
          const isArmed = armedSlot === place.id
          return (
            <div key={place.id} className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => onArm(place.id)}
                className={`rounded-full border px-3 py-1.5 text-sm font-medium transition ${
                  isArmed
                    ? 'border-wcc-alert bg-wcc-alert text-wcc-white'
                    : place.position
                      ? 'border-wcc-link text-wcc-link hover:bg-blue-50'
                      : 'border-wcc-grey-mid text-wcc-grey-dark hover:border-wcc-link hover:text-wcc-link'
                }`}
              >
                {place.id === 'home' ? '🏠' : '📍'} {place.label}
                {isArmed ? ' — tap the map' : !place.position ? ' — set' : ''}
              </button>
              {place.position && (
                <button
                  type="button"
                  onClick={() => onToggleVisible(place.id)}
                  title={place.visible ? 'Hide on map' : 'Show on map'}
                  className={`flex min-h-[36px] min-w-[36px] items-center justify-center rounded-full px-2 py-1 text-xs font-medium ${
                    place.visible
                      ? 'bg-wcc-yellow text-wcc-charcoal'
                      : 'bg-wcc-grey-light/40 text-wcc-grey-dark'
                  }`}
                >
                  {place.visible ? 'Shown' : 'Hidden'}
                </button>
              )}
              {place.id !== 'home' && (
                <button
                  type="button"
                  onClick={() => onRemove(place.id)}
                  title={`Remove ${place.label}`}
                  className="flex min-h-[36px] min-w-[36px] items-center justify-center rounded-full text-xs font-medium text-wcc-grey-dark hover:text-wcc-alert"
                >
                  ×
                </button>
              )}
            </div>
          )
        })}

        {isAdding ? (
          <div className="flex items-center gap-1">
            <input
              autoFocus
              type="text"
              value={newLabel}
              onChange={(event) => setNewLabel(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') submitNewPlace()
                if (event.key === 'Escape') {
                  setIsAdding(false)
                  setNewLabel('')
                }
              }}
              placeholder="Place name"
              className="rounded-full border border-wcc-grey-mid px-3 py-1.5 text-sm text-wcc-charcoal outline-none focus:border-wcc-link"
            />
            <button
              type="button"
              onClick={submitNewPlace}
              className="rounded-full bg-wcc-link px-3 py-1.5 text-sm font-medium text-wcc-white hover:bg-wcc-link-hover"
            >
              Add
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setIsAdding(true)}
            className="rounded-full border border-dashed border-wcc-grey-mid px-3 py-1.5 text-sm font-medium text-wcc-grey-dark hover:border-wcc-link hover:text-wcc-link"
          >
            + Add place
          </button>
        )}
      </div>
    </section>
  )
}
