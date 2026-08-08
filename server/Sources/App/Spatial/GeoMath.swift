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
}
