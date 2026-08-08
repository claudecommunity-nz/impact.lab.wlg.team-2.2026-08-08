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

    // G3 — live local conditions (gauges, outages, water faults)
    v1.get("conditions") { req -> ConditionsEnvelope in
        guard let lat = req.query[Double.self, at: "lat"],
              let lng = req.query[Double.self, at: "lng"]
        else {
            throw Abort(.badRequest, reason: "lat and lng are required")
        }
        let n = req.query[Int.self, at: "n"] ?? 5
        let radiusKm = req.query[Double.self, at: "radiusKm"] ?? 10
        guard n > 0, n <= 20 else {
            throw Abort(.badRequest, reason: "n must be 1…20")
        }
        guard radiusKm > 0, radiusKm <= 100 else {
            throw Abort(.badRequest, reason: "radiusKm must be 0…100")
        }

        return try await req.services.conditions.conditions(
            at: .init(lat: lat, lng: lng),
            n: n,
            radiusKm: radiusKm
        )
    }

    // G4 — static hazard context (planning layers, point-intersect)
    v1.get("hazards") { req -> HazardsEnvelope in
        guard let lat = req.query[Double.self, at: "lat"],
              let lng = req.query[Double.self, at: "lng"]
        else {
            throw Abort(.badRequest, reason: "lat and lng are required")
        }
        return await req.services.hazards.hazards(at: .init(lat: lat, lng: lng))
    }
}

struct HealthzResponse: Content {
    let status: String
    let uptime: Double
}
