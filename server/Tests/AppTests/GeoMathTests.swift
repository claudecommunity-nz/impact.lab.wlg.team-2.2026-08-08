// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import App

@Suite("G2 GeoMath point-in-polygon")
struct GeoMathTests {
    /// Synthetic box around Lyall Bay (~ coast).
    /// Corners: SW, SE, NE, NW (closed).
    private let lyallBayRing: [GeoMath.Coordinate] = [
        .init(lat: -41.340, lng: 174.780),
        .init(lat: -41.340, lng: 174.810),
        .init(lat: -41.315, lng: 174.810),
        .init(lat: -41.315, lng: 174.780),
        .init(lat: -41.340, lng: 174.780),
    ]

    private let lyallBay = GeoMath.Coordinate(lat: -41.3286, lng: 174.7947)
    private let karori = GeoMath.Coordinate(lat: -41.2865, lng: 174.7405)

    @Test("Lyall Bay point is inside synthetic warning polygon")
    func lyallBayInside() {
        #expect(GeoMath.pointInPolygon(point: lyallBay, ring: lyallBayRing))
        #expect(GeoMath.pointInPolygonRings(point: lyallBay, rings: [lyallBayRing]))
    }

    @Test("Karori point is outside synthetic Lyall Bay polygon")
    func karoriOutside() {
        #expect(!GeoMath.pointInPolygon(point: karori, ring: lyallBayRing))
        #expect(!GeoMath.pointInPolygonRings(point: karori, rings: [lyallBayRing]))
    }

    @Test("Hole excludes interior point")
    func holeExcludes() {
        // Outer box covers both points; hole around Lyall Bay centre.
        let outer: [GeoMath.Coordinate] = [
            .init(lat: -41.35, lng: 174.77),
            .init(lat: -41.35, lng: 174.82),
            .init(lat: -41.30, lng: 174.82),
            .init(lat: -41.30, lng: 174.77),
        ]
        let hole: [GeoMath.Coordinate] = [
            .init(lat: -41.332, lng: 174.790),
            .init(lat: -41.332, lng: 174.800),
            .init(lat: -41.325, lng: 174.800),
            .init(lat: -41.325, lng: 174.790),
        ]
        #expect(!GeoMath.pointInPolygonRings(point: lyallBay, rings: [outer, hole]))
        // Point just outside the hole but in outer (north of Lyall Bay box)
        let northOfHole = GeoMath.Coordinate(lat: -41.318, lng: 174.795)
        #expect(GeoMath.pointInPolygonRings(point: northOfHole, rings: [outer, hole]))
    }
}
