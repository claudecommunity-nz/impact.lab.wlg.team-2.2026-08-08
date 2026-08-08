// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import MapKit

enum MapOverlayKind: String {
    case warning, hazard, gauge, outage, water, hub, other
}

struct MapPin: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String?
    let kind: MapOverlayKind

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MapPin, rhs: MapPin) -> Bool { lhs.id == rhs.id }
}

struct OverlayPolygon: Identifiable, Hashable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let title: String
    let kind: MapOverlayKind

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: OverlayPolygon, rhs: OverlayPolygon) -> Bool { lhs.id == rhs.id }
}

enum GeoJSONMap {
    static func pins(from collection: GeoJSONFeatureCollection, defaultKind: MapOverlayKind = .other) -> [MapPin] {
        collection.features.compactMap { feature in
            guard let geometry = feature.geometry, geometry.type == "Point" else { return nil }
            guard let coord = pointCoordinate(geometry.coordinates.value) else { return nil }
            let props = feature.properties ?? [:]
            let kind = kindFromProperties(props, fallback: defaultKind)
            let title = props["site"]?.stringValue
                ?? props["locationName"]?.stringValue
                ?? props["name"]?.stringValue
                ?? props["description"]?.stringValue
                ?? props["event"]?.stringValue
                ?? kind.rawValue.capitalized
            let subtitle = props["kind"]?.stringValue
                ?? props["status"]?.stringValue
                ?? props["layer"]?.stringValue
            return MapPin(id: feature.id, coordinate: coord, title: title, subtitle: subtitle, kind: kind)
        }
    }

    static func polygons(from collection: GeoJSONFeatureCollection, defaultKind: MapOverlayKind) -> [OverlayPolygon] {
        var result: [OverlayPolygon] = []
        for feature in collection.features {
            guard let geometry = feature.geometry else { continue }
            let props = feature.properties ?? [:]
            let title = props["event"]?.stringValue
                ?? props["headline"]?.stringValue
                ?? props["layer"]?.stringValue
                ?? props["name"]?.stringValue
                ?? defaultKind.rawValue
            let kind = kindFromProperties(props, fallback: defaultKind)
            for (index, ring) in ringCoordinates(geometry: geometry).enumerated() where ring.count >= 3 {
                result.append(
                    OverlayPolygon(
                        id: "\(feature.id)-\(index)",
                        coordinates: ring,
                        title: title,
                        kind: kind
                    )
                )
            }
        }
        return result
    }

    private static func kindFromProperties(_ props: [String: AnyCodable], fallback: MapOverlayKind) -> MapOverlayKind {
        if let kind = props["kind"]?.stringValue {
            switch kind.lowercased() {
            case "gauge", "gauges": return .gauge
            case "outage", "electricity", "electricityoutage": return .outage
            case "water", "waterfault", "water_fault": return .water
            case "hub", "nearesthub": return .hub
            case "warning": return .warning
            case "hazard": return .hazard
            default: break
            }
        }
        if props["event"] != nil || props["severity"] != nil { return .warning }
        if props["layer"] != nil { return .hazard }
        return fallback
    }

    private static func pointCoordinate(_ value: Any) -> CLLocationCoordinate2D? {
        guard let arr = value as? [Any], arr.count >= 2,
              let lng = number(arr[0]), let lat = number(arr[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private static func ringCoordinates(geometry: GeoJSONGeometry) -> [[CLLocationCoordinate2D]] {
        switch geometry.type {
        case "Polygon":
            return polygonRings(geometry.coordinates.value)
        case "MultiPolygon":
            guard let multi = geometry.coordinates.value as? [Any] else { return [] }
            return multi.flatMap { polygonRings($0) }
        default:
            return []
        }
    }

    private static func polygonRings(_ value: Any) -> [[CLLocationCoordinate2D]] {
        guard let rings = value as? [Any] else { return [] }
        return rings.compactMap { ringAny -> [CLLocationCoordinate2D]? in
            guard let pairs = ringAny as? [Any] else { return nil }
            let coords: [CLLocationCoordinate2D] = pairs.compactMap { pair in
                guard let p = pair as? [Any], p.count >= 2,
                      let lng = number(p[0]), let lat = number(p[1]) else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            return coords.count >= 3 ? coords : nil
        }
    }

    private static func number(_ any: Any) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }
}
