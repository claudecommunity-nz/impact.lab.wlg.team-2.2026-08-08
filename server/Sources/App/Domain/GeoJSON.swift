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

// MARK: - Polygon GeoJSON (warnings)

struct GeoJSONPolygonGeometry: Codable, Sendable {
    let type: String
    /// GeoJSON Polygon: array of linear rings; each ring is `[lng, lat]` pairs.
    let coordinates: [[[Double]]]

    static func from(rings: [[GeoMath.Coordinate]]) -> GeoJSONPolygonGeometry {
        let coords = rings.map { ring in
            var pairs = ring.map { [$0.lng, $0.lat] }
            // Close ring if needed.
            if let first = pairs.first, let last = pairs.last, first != last {
                pairs.append(first)
            }
            return pairs
        }
        return GeoJSONPolygonGeometry(type: "Polygon", coordinates: coords)
    }
}

struct GeoJSONPolygonFeature<P: Codable & Sendable>: Codable, Sendable {
    let type: String
    let geometry: GeoJSONPolygonGeometry
    let properties: P

    init(geometry: GeoJSONPolygonGeometry, properties: P) {
        self.type = "Feature"
        self.geometry = geometry
        self.properties = properties
    }
}

struct GeoJSONPolygonFeatureCollection<P: Codable & Sendable>: Codable, Sendable {
    let type: String
    let features: [GeoJSONPolygonFeature<P>]

    init(features: [GeoJSONPolygonFeature<P>]) {
        self.type = "FeatureCollection"
        self.features = features
    }
}

struct WarningGeoJSONProperties: Codable, Sendable {
    let id: String
    let event: String
    let headline: String?
    let severity: String?
    let urgency: String?
    let certainty: String?
    let areaDesc: String?
    let sourceId: String
}

extension WarningRecord {
    func asGeoJSONFeature() -> GeoJSONPolygonFeature<WarningGeoJSONProperties> {
        GeoJSONPolygonFeature(
            geometry: .from(rings: rings),
            properties: WarningGeoJSONProperties(
                id: warning.id,
                event: warning.event,
                headline: warning.headline,
                severity: warning.severity,
                urgency: warning.urgency,
                certainty: warning.certainty,
                areaDesc: warning.areaDesc,
                sourceId: warning.source.id
            )
        )
    }
}

// MARK: - Hazard / condition GeoJSON (demo map layers)

struct HazardGeoJSONProperties: Codable, Sendable {
    let id: String
    let layer: String
    let value: String
    let detail: String?
    let publisher: String
    let sourceId: String
}

struct DemoConditionPointProperties: Codable, Sendable {
    /// `gauge` | `outage` | `water` | `hub`
    let kind: String
    let label: String
    let detail: String?
    let sourceId: String
}
