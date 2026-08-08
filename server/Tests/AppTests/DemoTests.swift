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
}
