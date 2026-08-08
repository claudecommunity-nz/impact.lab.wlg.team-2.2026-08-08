// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import VaporTesting
@testable import App

@Suite("G1 Hubs")
struct HubsTests {
    /// Loose envelope covering WREMO hubs (Wellington + Kapiti + Wairarapa).
    /// Gate doc city bbox (174.6..175.0, -41.4..-41.1) is too tight for the full 126 regional set.
    private let regionalBBox = (west: 174.0, south: -41.8, east: 176.5, north: -40.4)

    @Test("GET /v1/hubs returns 126 hubs with WGS84 coordinates")
    func hubsCountAndCoords() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/hubs") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(HubsEnvelope.self)
                #expect(body.count == 126)
                #expect(body.items.count == 126)
                #expect(body.source.id == "community-emergency-hubs")

                for hub in body.items {
                    #expect(hub.lat != 0)
                    #expect(hub.lng != 0)
                    #expect(hub.lng >= regionalBBox.west && hub.lng <= regionalBBox.east)
                    #expect(hub.lat >= regionalBBox.south && hub.lat <= regionalBBox.north)
                    #expect(!hub.name.isEmpty)
                }
            }
        }
    }

    @Test("GET /v1/hubs?format=geojson is a FeatureCollection")
    func hubsGeoJSON() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/hubs?format=geojson") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(GeoJSONFeatureCollection<HubGeoJSONProperties>.self)
                #expect(body.type == "FeatureCollection")
                #expect(body.features.count == 126)
                if let first = body.features.first {
                    #expect(first.geometry.type == "Point")
                    #expect(first.geometry.coordinates.count == 2)
                    // GeoJSON order is [lng, lat]
                    let lng = first.geometry.coordinates[0]
                    let lat = first.geometry.coordinates[1]
                    #expect(lng >= regionalBBox.west && lng <= regionalBBox.east)
                    #expect(lat >= regionalBBox.south && lat <= regionalBBox.north)
                }
            }
        }
    }
}
