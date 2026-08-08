// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import VaporTesting
@testable import App

@Suite("G3 Conditions")
struct ConditionsTests {
    @Test("GET /v1/conditions requires lat and lng")
    func requiresPoint() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/conditions") { res async throws in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("GET /v1/conditions at Lyall Bay returns gauges with units and age")
    func lyallBayConditions() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/conditions?lat=-41.3286&lng=174.7947&n=5&radiusKm=25"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(ConditionsEnvelope.self)

                // Sections always present (may be empty arrays).
                _ = body.electricityOutages
                _ = body.waterFaults

                #expect(body.gauges.count >= 1)

                let now = Date()
                for g in body.gauges {
                    #expect(!g.site.isEmpty)
                    #expect(!g.units.isEmpty)
                    #expect(g.distanceKm >= 0)
                    #expect(g.source.id == "hilltop")
                    #expect(now.timeIntervalSince(g.observedAt) <= 6 * 3600 + 60)
                    #expect(g.measurement == "Stage" || g.measurement == "Flow" || g.measurement == "Rainfall")
                }
            }
        }
    }

    @Test("Hilltop timestamps parse as Auckland local")
    func hilltopTimeParse() {
        let d = HilltopClient.parseHilltopTime("2026-08-08T10:40:00")
        #expect(d != nil)
    }
}
