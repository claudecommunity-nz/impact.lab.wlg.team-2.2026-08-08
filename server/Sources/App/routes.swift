// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

func routes(_ app: Application) throws {
    app.get("healthz") { _ -> HealthzResponse in
        // Clamp: sub-millisecond clock skew can make a brand-new process
        // report a tiny negative interval under the test runner.
        let uptime = max(0, Date().timeIntervalSince(AppStart.date))
        return HealthzResponse(status: "ok", uptime: uptime)
    }
}

struct HealthzResponse: Content {
    let status: String
    let uptime: Double
}
