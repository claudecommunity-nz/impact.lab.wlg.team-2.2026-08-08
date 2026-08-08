// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import VaporTesting
@testable import App

@Suite("G2 Warnings")
struct WarningsTests {
    @Test("GET /v1/warnings returns schema (empty list OK on calm day)")
    func warningsSchemaNZWide() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/warnings") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(WarningsEnvelope.self)
                #expect(body.count == body.items.count)
                for item in body.items {
                    #expect(!item.id.isEmpty)
                    #expect(!item.event.isEmpty)
                    #expect(item.source.trust == .official)
                    #expect(
                        item.source.id == "metservice-warnings"
                            || item.source.id == "nema-cap-alerts"
                    )
                    // Contract fields present (may be null for optional ones)
                    _ = item.severity
                    _ = item.urgency
                    _ = item.certainty
                    _ = item.headline
                    _ = item.onset
                    _ = item.expires
                    _ = item.source.fetchedAt
                }
            }
        }
    }

    @Test("GET /v1/warnings?lat&lng accepts Lyall Bay and returns array")
    func warningsAtLyallBay() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/warnings?lat=-41.3286&lng=174.7947"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(WarningsEnvelope.self)
                #expect(body.count == body.items.count)
            }
        }
    }

    @Test("lat without lng is 400")
    func warningsPartialParams() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/warnings?lat=-41.3") { res async throws in
                #expect(res.status == .badRequest)
            }
        }
    }
}
