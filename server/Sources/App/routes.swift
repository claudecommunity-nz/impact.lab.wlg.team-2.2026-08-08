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

    // G2 — official CAP warnings (MetService + NEMA)
    v1.get("warnings") { req -> Response in
        let lat = req.query[Double.self, at: "lat"]
        let lng = req.query[Double.self, at: "lng"]
        let point: GeoMath.Coordinate?
        switch (lat, lng) {
        case (nil, nil):
            point = nil
        case let (lat?, lng?):
            point = GeoMath.Coordinate(lat: lat, lng: lng)
        default:
            throw Abort(.badRequest, reason: "Provide both lat and lng, or neither for NZ-wide list")
        }

        let records = try await req.services.warnings.warningRecords(at: point)
        let format = (req.query[String.self, at: "format"] ?? "json").lowercased()

        if format == "geojson" {
            let collection = GeoJSONPolygonFeatureCollection(
                features: records.map { $0.asGeoJSONFeature() }
            )
            let response = Response(status: .ok)
            try response.content.encode(collection, as: .json)
            return response
        }

        let items = records.map(\.warning)
        let envelope = WarningsEnvelope(items: items, count: items.count)
        let response = Response(status: .ok)
        try response.content.encode(envelope, as: .json)
        return response
    }
}

struct HealthzResponse: Content {
    let status: String
    let uptime: Double
}
