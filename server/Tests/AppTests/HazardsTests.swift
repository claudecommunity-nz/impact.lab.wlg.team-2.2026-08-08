// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import VaporTesting
@testable import App

@Suite("G4 Hazards")
struct HazardsTests {
    @Test("GET /v1/hazards requires lat and lng")
    func requiresPoint() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/hazards") { res async throws in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("GET /v1/hazards at Lyall Bay includes tsunami evacuation zone")
    func lyallBayTsunami() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/hazards?lat=-41.3286&lng=174.7947"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(HazardsEnvelope.self)
                #expect(body.status == "ok" || body.status == "unavailable")
                #expect(body.note.lowercased().contains("planning"))
                #expect(!body.note.isEmpty)

                // Gate pass: Lyall Bay is inside a tsunami evacuation zone.
                let tsunami = body.items.filter { $0.id == "tsunami-evacuation-zones" }
                #expect(tsunami.count >= 1)
                for item in tsunami {
                    #expect(!item.value.isEmpty)
                    #expect(item.source.trust == .planning)
                    #expect(!item.publisher.isEmpty)
                    #expect(item.source.id == "tsunami-evacuation-zones")
                }
                for item in body.items {
                    #expect(item.source.trust == .planning)
                    #expect(!item.publisher.isEmpty)
                }
            }
        }
    }

    @Test("GET /v1/hazards at Karori has no tsunami zone")
    func karoriNoTsunami() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/hazards?lat=-41.2865&lng=174.7405"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(HazardsEnvelope.self)
                let tsunami = body.items.filter { $0.id == "tsunami-evacuation-zones" }
                #expect(tsunami.isEmpty)
            }
        }
    }
}
