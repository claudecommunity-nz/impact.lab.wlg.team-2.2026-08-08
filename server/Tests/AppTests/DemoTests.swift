// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import VaporTesting
@testable import App

@Suite("Demo scenarios")
struct DemoTests {
    @Test("GET /v1/demo/scenarios lists curated scenarios")
    func catalog() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/demo/scenarios") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(DemoCatalog.self)
                #expect(body.scenarios.count >= 3)
                let ids = Set(body.scenarios.map(\.id))
                #expect(ids.contains("southerly-storm"))
                #expect(ids.contains("calm-day"))
                #expect(ids.contains("degraded"))
            }
        }
    }

    @Test("Southerly storm: same warning, different hazards A vs B")
    func southerlyContrast() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/demo/picture?scenario=southerly-storm&point=lyall-bay"
            ) { lyall async throws in
                #expect(lyall.status == .ok)
                let a = try lyall.content.decode(LocationPicture.self)
                #expect(a.officialWarnings.items.count == 1)
                #expect(a.hazardContext.items.contains { $0.id == "tsunami-evacuation-zones" })
                #expect(!SummaryBuilder.containsBannedWords(a.summary))
                #expect(a.disclaimer == LocationPicture.disclaimerText)

                try await app.testing().test(
                    .GET,
                    "v1/demo/picture?scenario=southerly-storm&point=karori"
                ) { karori async throws in
                    #expect(karori.status == .ok)
                    let b = try karori.content.decode(LocationPicture.self)
                    #expect(b.officialWarnings.items.count == 1)
                    #expect(a.officialWarnings.items[0].id == b.officialWarnings.items[0].id)
                    #expect(b.hazardContext.items.filter { $0.id == "tsunami-evacuation-zones" }.isEmpty)
                    #expect(!SummaryBuilder.containsBannedWords(b.summary))
                }
            }
        }
    }

    @Test("Calm day has empty warnings and honest summary line")
    func calmDay() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/demo/picture?scenario=calm-day&point=lyall-bay"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(LocationPicture.self)
                #expect(body.officialWarnings.items.isEmpty)
                #expect(body.summary.contains { $0.lowercased().contains("no official warnings") })
            }
        }
    }

    @Test("Degraded scenario marks conditions unavailable")
    func degraded() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/demo/picture?scenario=degraded&point=lyall-bay"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(LocationPicture.self)
                #expect(body.localConditions.status == "unavailable")
                #expect(body.officialWarnings.status == "ok")
                #expect(body.officialWarnings.items.count == 1)
                #expect(body.sources.contains { $0.id == "hilltop" && $0.status == "unavailable" })
            }
        }
    }

    @Test("Unknown scenario is 404")
    func unknownScenario() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/demo/picture?scenario=nope&point=lyall-bay"
            ) { res async throws in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("Section endpoints mirror picture slices")
    func sectionEndpoints() async throws {
        try await withApp(configure: configure) { app in
            let q = "scenario=southerly-storm&point=lyall-bay"
            try await app.testing().test(.GET, "v1/demo/warnings?\(q)") { res async throws in
                #expect(res.status == .ok)
                let w = try res.content.decode(OfficialWarningsSection.self)
                #expect(w.items.count == 1)
            }
            try await app.testing().test(.GET, "v1/demo/hazards?\(q)") { res async throws in
                #expect(res.status == .ok)
                let h = try res.content.decode(HazardsEnvelope.self)
                #expect(h.items.contains { $0.id == "tsunami-evacuation-zones" })
            }
            try await app.testing().test(.GET, "v1/demo/conditions?\(q)") { res async throws in
                #expect(res.status == .ok)
                let c = try res.content.decode(LocalConditionsSection.self)
                #expect(c.status == "ok")
                #expect(!c.gauges.isEmpty)
            }
        }
    }

    @Test("Demo polygons: warning covers both points; tsunami only Lyall Bay")
    func demoPolygonCoverage() {
        let lyall = GeoMath.Coordinate(lat: -41.3286, lng: 174.7947)
        let karori = GeoMath.Coordinate(lat: -41.2865, lng: 174.7405)

        // Multi-vertex rings (not 4-corner boxes) — map clients must not draw squares.
        #expect(DemoScenarioData.wellingtonWarningRing.count >= 12)
        #expect(DemoScenarioData.tsunamiOrangeRing.count >= 12)
        #expect(DemoScenarioData.coastalInundationRing.count >= 10)

        #expect(GeoMath.pointInPolygon(point: lyall, ring: DemoScenarioData.wellingtonWarningRing))
        #expect(GeoMath.pointInPolygon(point: karori, ring: DemoScenarioData.wellingtonWarningRing))
        #expect(GeoMath.pointInPolygon(point: lyall, ring: DemoScenarioData.tsunamiOrangeRing))
        #expect(!GeoMath.pointInPolygon(point: karori, ring: DemoScenarioData.tsunamiOrangeRing))
        #expect(GeoMath.pointInPolygon(point: lyall, ring: DemoScenarioData.coastalInundationRing))
        #expect(!GeoMath.pointInPolygon(point: karori, ring: DemoScenarioData.coastalInundationRing))
    }

    @Test("Demo warnings GeoJSON has Polygon geometry for both points")
    func warningsGeoJSON() async throws {
        try await withApp(configure: configure) { app in
            for point in ["lyall-bay", "karori"] {
                try await app.testing().test(
                    .GET,
                    "v1/demo/warnings?scenario=southerly-storm&point=\(point)&format=geojson"
                ) { res async throws in
                    #expect(res.status == .ok)
                    let body = try res.content.decode(
                        GeoJSONPolygonFeatureCollection<WarningGeoJSONProperties>.self
                    )
                    #expect(body.type == "FeatureCollection")
                    #expect(body.features.count == 1)
                    #expect(body.features[0].geometry.type == "Polygon")
                    #expect(!body.features[0].geometry.coordinates.isEmpty)
                    #expect(body.features[0].properties.event == "rain")
                }
            }
        }
    }

    @Test("Demo hazards GeoJSON: Lyall has polygons, Karori empty")
    func hazardsGeoJSON() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/demo/hazards?scenario=southerly-storm&point=lyall-bay&format=geojson"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(
                    GeoJSONPolygonFeatureCollection<HazardGeoJSONProperties>.self
                )
                #expect(body.features.count >= 2)
                for f in body.features {
                    #expect(f.geometry.type == "Polygon")
                }
                let ids = Set(body.features.map(\.properties.id))
                #expect(ids.contains("tsunami-evacuation-zones"))
                #expect(ids.contains("coastal-inundation-medium"))
            }

            try await app.testing().test(
                .GET,
                "v1/demo/hazards?scenario=southerly-storm&point=karori&format=geojson"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(
                    GeoJSONPolygonFeatureCollection<HazardGeoJSONProperties>.self
                )
                #expect(body.features.isEmpty)
            }
        }
    }

    @Test("Demo conditions GeoJSON has Point features")
    func conditionsGeoJSON() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/demo/conditions?scenario=southerly-storm&point=lyall-bay&format=geojson"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(
                    GeoJSONFeatureCollection<DemoConditionPointProperties>.self
                )
                #expect(body.features.count >= 3)
                for f in body.features {
                    #expect(f.geometry.type == "Point")
                    #expect(f.geometry.coordinates.count == 2)
                }
                let kinds = Set(body.features.map(\.properties.kind))
                #expect(kinds.contains("gauge"))
                #expect(kinds.contains("hub"))
            }
        }
    }
}
