// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

func routes(_ app: Application) throws {
    app.get("healthz") { _ -> HealthzResponse in
        // Clamp: sub-millisecond clock skew can make a brand-new process
        // report a tiny negative interval under the test runner.
        let uptime = max(0, Date().timeIntervalSince(AppStart.date))
        return HealthzResponse(status: "ok", uptime: uptime)
    }

    let v1 = app.grouped("v1")

    // G1 — community emergency hubs
    v1.get("hubs") { req -> Response in
        let bbox: GeoMath.BBox?
        if let raw = req.query[String.self, at: "bbox"] {
            guard let parsed = GeoMath.BBox.parse(raw) else {
                throw Abort(.badRequest, reason: "bbox must be w,s,e,n decimal degrees")
            }
            bbox = parsed
        } else {
            bbox = nil
        }

        let (hubs, source) = try await req.services.hubs.hubs(bbox: bbox)
        let format = (req.query[String.self, at: "format"] ?? "json").lowercased()

        if format == "geojson" {
            let collection = GeoJSONFeatureCollection(features: hubs.map { $0.asGeoJSONFeature() })
            let response = Response(status: .ok)
            try response.content.encode(collection, as: .json)
            return response
        }

        let envelope = HubsEnvelope(items: hubs, count: hubs.count, source: source)
        let response = Response(status: .ok)
        try response.content.encode(envelope, as: .json)
        return response
    }
}

struct HealthzResponse: Content {
    let status: String
    let uptime: Double
}
