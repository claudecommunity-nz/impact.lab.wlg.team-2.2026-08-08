// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
import VaporTesting
@testable import App

@Suite("G0 Healthz")
struct HealthzTests {
    @Test("GET /healthz returns ok")
    func healthzOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "healthz") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(HealthzResponse.self)
                #expect(body.status == "ok")
                #expect(body.uptime >= 0)
            }
        }
    }

    @Test("unknown route returns JSON 404")
    func unknownRouteJSON404() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "no-such-route") { res async throws in
                #expect(res.status == .notFound)
                let body = try res.content.decode(JSONErrorMiddleware.ErrorBody.self)
                #expect(body.error == true)
                #expect(!body.reason.isEmpty)
            }
        }
    }
}
