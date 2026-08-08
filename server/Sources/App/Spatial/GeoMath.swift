// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Pure spatial helpers. All coordinates are WGS84 lat/lng.
enum GeoMath {
    struct Coordinate: Sendable, Equatable {
        let lat: Double
        let lng: Double
    }

    struct BBox: Sendable, Equatable {
        /// west, south, east, north
        let west: Double
        let south: Double
        let east: Double
        let north: Double

        func contains(lat: Double, lng: Double) -> Bool {
            lng >= west && lng <= east && lat >= south && lat <= north
        }

        /// Parse `w,s,e,n` query form.
        static func parse(_ raw: String) -> BBox? {
            let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 4,
                  let w = Double(parts[0]),
                  let s = Double(parts[1]),
                  let e = Double(parts[2]),
                  let n = Double(parts[3])
            else { return nil }
            return BBox(west: w, south: s, east: e, north: n)
        }
    }

    /// Earth-mean-radius haversine distance in kilometres.
    static func haversineKm(from a: Coordinate, to b: Coordinate) -> Double {
        let r = 6371.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLng = (b.lng - a.lng) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    // MARK: - Point in polygon (winding number)

    /// Cross-product test: >0 if `p` is left of directed edge a→b.
    static func isLeft(_ a: Coordinate, _ b: Coordinate, _ p: Coordinate) -> Double {
        (b.lng - a.lng) * (p.lat - a.lat) - (p.lng - a.lng) * (b.lat - a.lat)
    }

    /// Winding-number point-in-polygon for a single closed (or open) ring.
    /// More robust than ray casting at vertices / horizontal edges.
    static func pointInPolygon(point: Coordinate, ring: [Coordinate]) -> Bool {
        guard ring.count >= 3 else { return false }

        // Drop duplicate closing vertex if present so we walk unique edges.
        var pts = ring
        if let first = pts.first, let last = pts.last,
           first.lat == last.lat, first.lng == last.lng
        {
            pts.removeLast()
        }
        guard pts.count >= 3 else { return false }

        var winding = 0
        for i in 0..<pts.count {
            let a = pts[i]
            let b = pts[(i + 1) % pts.count]
            if a.lat <= point.lat {
                if b.lat > point.lat, isLeft(a, b, point) > 0 {
                    winding += 1
                }
            } else if b.lat <= point.lat, isLeft(a, b, point) < 0 {
                winding -= 1
            }
        }
        return winding != 0
    }

    /// ArcGIS-style multi-ring polygon: ring 0 is exterior; subsequent rings are holes.
    static func pointInPolygonRings(point: Coordinate, rings: [[Coordinate]]) -> Bool {
        guard let exterior = rings.first else { return false }
        guard pointInPolygon(point: point, ring: exterior) else { return false }
        for hole in rings.dropFirst() where pointInPolygon(point: point, ring: hole) {
            return false
        }
        return true
    }

    /// Convert ArcGIS `rings` (`[[[lng, lat], …], …]`) to coordinate rings.
    static func rings(fromArcGIS rings: [[[Double]]]) -> [[Coordinate]] {
        rings.map { ring in
            ring.compactMap { pair -> Coordinate? in
                guard pair.count >= 2 else { return nil }
                return Coordinate(lat: pair[1], lng: pair[0])
            }
        }
    }
}
