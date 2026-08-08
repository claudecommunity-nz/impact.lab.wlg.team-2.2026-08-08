// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Minimal GeoJSON types for list endpoints (`?format=geojson`).
struct GeoJSONFeatureCollection<P: Codable & Sendable>: Codable, Sendable {
    let type: String
    let features: [GeoJSONFeature<P>]

    init(features: [GeoJSONFeature<P>]) {
        self.type = "FeatureCollection"
        self.features = features
    }
}

struct GeoJSONFeature<P: Codable & Sendable>: Codable, Sendable {
    let type: String
    let geometry: GeoJSONGeometry
    let properties: P

    init(geometry: GeoJSONGeometry, properties: P) {
        self.type = "Feature"
        self.geometry = geometry
        self.properties = properties
    }
}

struct GeoJSONGeometry: Codable, Sendable {
    let type: String
    /// GeoJSON Point coordinates are `[lng, lat]`.
    let coordinates: [Double]

    static func point(lng: Double, lat: Double) -> GeoJSONGeometry {
        GeoJSONGeometry(type: "Point", coordinates: [lng, lat])
    }
}

/// Properties bag for hub GeoJSON features (stable keys for the map UI).
struct HubGeoJSONProperties: Codable, Sendable {
    let id: Int
    let name: String
    let type: String?
    let address: String?
    let suburb: String?
    let town: String?
    let taName: String?
    let sourceId: String
}

extension Hub {
    func asGeoJSONFeature() -> GeoJSONFeature<HubGeoJSONProperties> {
        GeoJSONFeature(
            geometry: .point(lng: lng, lat: lat),
            properties: HubGeoJSONProperties(
                id: id,
                name: name,
                type: type,
                address: address,
                suburb: suburb,
                town: town,
                taName: taName,
                sourceId: source.id
            )
        )
    }
}
