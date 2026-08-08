import { useFavouriteWarnings } from '../hooks/useFavouriteWarnings'
import type { Place } from '../types'

export function FavouritesStatus({ places }: { places: Place[] }) {
  const statusById = useFavouriteWarnings(places)
  const positioned = places.filter((place) => place.position)

  if (positioned.length === 0) return null

  return (
    <ul className="mt-3 flex flex-col gap-1.5">
      {positioned.map((place) => {
        const entry = statusById[place.id]
        return (
          <li key={place.id} className="flex items-baseline gap-2 text-sm">
            <span className="font-medium text-wcc-charcoal">
              {place.id === 'home' ? '🏠' : '📍'} {place.label}
            </span>
            <span className="text-wcc-grey-dark">
              {!entry || entry.status === 'loading'
                ? 'Checking…'
                : entry.status === 'error'
                  ? "Can't reach the alerts service"
                  : entry.worst
                    ? entry.worst.event
                    : 'No warnings'}
            </span>
          </li>
        )
      })}
    </ul>
  )
}
