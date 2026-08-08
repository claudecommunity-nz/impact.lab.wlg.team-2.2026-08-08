// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import VaporTesting
@testable import App

@Suite("G5 Picture")
struct PictureTests {
    @Test("GET /v1/picture requires lat+lng or hub")
    func requiresParams() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/picture") { res async throws in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("GET /v1/picture?hub=unknown is 404")
    func unknownHub() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "v1/picture?hub=999999999") { res async throws in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("GET /v1/picture at Lyall Bay returns full contract shape")
    func lyallBayPicture() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/picture?lat=-41.3286&lng=174.7947"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(LocationPicture.self)

                #expect(body.location.lat == -41.3286)
                #expect(body.location.lng == 174.7947)
                #expect(body.location.nearestHub != nil)

                #expect(body.officialWarnings.status == "ok" || body.officialWarnings.status == "unavailable")
                #expect(body.localConditions.status == "ok" || body.localConditions.status == "unavailable")
                #expect(body.hazardContext.status == "ok" || body.hazardContext.status == "unavailable")

                // Gate: Lyall Bay has tsunami zone when hazards are ok.
                if body.hazardContext.status == "ok" {
                    let tsunami = body.hazardContext.items.filter { $0.id == "tsunami-evacuation-zones" }
                    #expect(tsunami.count >= 1)
                }

                #expect(!body.summary.isEmpty)
                #expect(!SummaryBuilder.containsBannedWords(body.summary))
                #expect(body.disclaimer == LocationPicture.disclaimerText)
                #expect(!body.sources.isEmpty)
                #expect(body.generatedAt.timeIntervalSinceNow < 60)
            }
        }
    }

    @Test("GET /v1/picture at Karori has no tsunami zone")
    func karoriPicture() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "v1/picture?lat=-41.2865&lng=174.7405"
            ) { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(LocationPicture.self)
                let tsunami = body.hazardContext.items.filter { $0.id == "tsunami-evacuation-zones" }
                #expect(tsunami.isEmpty)
                #expect(!SummaryBuilder.containsBannedWords(body.summary))
            }
        }
    }

    @Test("GET /v1/picture?hub= resolves a known hub")
    func pictureByHub() async throws {
        try await withApp(configure: configure) { app in
            // Discover a real hub id first.
            try await app.testing().test(.GET, "v1/hubs") { hubsRes async throws in
                #expect(hubsRes.status == .ok)
                let hubs = try hubsRes.content.decode(HubsEnvelope.self)
                #expect(!hubs.items.isEmpty)
                let hub = hubs.items[0]

                try await app.testing().test(.GET, "v1/picture?hub=\(hub.id)") { res async throws in
                    #expect(res.status == .ok)
                    let body = try res.content.decode(LocationPicture.self)
                    #expect(abs(body.location.lat - hub.lat) < 0.0001)
                    #expect(abs(body.location.lng - hub.lng) < 0.0001)
                    #expect(!body.summary.isEmpty)
                }
            }
        }
    }
}
