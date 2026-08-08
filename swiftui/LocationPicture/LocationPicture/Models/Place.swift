// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreLocation

/// A selectable location on the map-first shell (Pulse-inspired “site” analogue).
struct Place: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case demoPoint
        case livePreset
        case hub
        case custom

        var label: String {
            switch self {
            case .demoPoint: return "Demo"
            case .livePreset: return "Live"
            case .hub: return "Hub"
            case .custom: return "Custom"
            }
        }
    }

    let id: String
    var name: String
    var subtitle: String?
    var lat: Double
    var lng: Double
    var kind: Kind
    var demoPointId: String?
    var scenarioId: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var latLng: LatLng { LatLng(lat: lat, lng: lng) }
}
