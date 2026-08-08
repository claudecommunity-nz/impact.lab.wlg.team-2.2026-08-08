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

    // G5 — full Location Picture (fan-out + factual summary)
    v1.get("picture") { req -> LocationPicture in
        let lat = req.query[Double.self, at: "lat"]
        let lng = req.query[Double.self, at: "lng"]
        let hubId = req.query[Int.self, at: "hub"]

        switch (lat, lng, hubId) {
        case let (lat?, lng?, _):
            // Prefer explicit coordinates when both lat/lng and hub are present.
            return await req.services.picture.picture(at: .init(lat: lat, lng: lng))
        case (nil, nil, let hubId?):
            return try await req.services.picture.picture(hubId: hubId)
        case (nil, nil, nil):
            throw Abort(.badRequest, reason: "Provide lat and lng, or hub=<id>")
        default:
            throw Abort(.badRequest, reason: "Provide both lat and lng, or hub=<id>")
        }
    }

    // Demo fixtures — curated mock data (not live). Separate namespace so
    // judges never confuse staged scenarios with production feeds.
    let demo = v1.grouped("demo")

    demo.get("scenarios") { req -> DemoCatalog in
        req.services.demo.catalog()
    }

    demo.get("picture") { req -> LocationPicture in
        let scenario = try req.query.get(String.self, at: "scenario")
        let point = try req.query.get(String.self, at: "point")
        return try req.services.demo.picture(scenarioId: scenario, pointId: point)
    }

    // Warnings JSON or polygon GeoJSON for the map
    demo.get("warnings") { req -> Response in
        let scenario = try req.query.get(String.self, at: "scenario")
        let point = try req.query.get(String.self, at: "point")
        let format = (req.query[String.self, at: "format"] ?? "json").lowercased()
        let records = try req.services.demo.warningRecords(scenarioId: scenario, pointId: point)

        if format == "geojson" {
            let collection = GeoJSONPolygonFeatureCollection(
                features: records.map { $0.asGeoJSONFeature() }
            )
            let response = Response(status: .ok)
            try response.content.encode(collection, as: .json)
            return response
        }

        let section = OfficialWarningsSection.ok(records.map(\.warning))
        let response = Response(status: .ok)
        try response.content.encode(section, as: .json)
        return response
    }

    // Conditions JSON or point GeoJSON (gauges / outages / water / hub pins)
    demo.get("conditions") { req -> Response in
        let scenario = try req.query.get(String.self, at: "scenario")
        let point = try req.query.get(String.self, at: "point")
        let format = (req.query[String.self, at: "format"] ?? "json").lowercased()

        if format == "geojson" {
            let features = try req.services.demo.conditionPointFeatures(
                scenarioId: scenario,
                pointId: point
            )
            let collection = GeoJSONFeatureCollection(features: features)
            let response = Response(status: .ok)
            try response.content.encode(collection, as: .json)
            return response
        }

        let section = try req.services.demo.conditions(scenarioId: scenario, pointId: point)
        let response = Response(status: .ok)
        try response.content.encode(section, as: .json)
        return response
    }

    // Hazards JSON or polygon GeoJSON (planning zones for the map)
    demo.get("hazards") { req -> Response in
        let scenario = try req.query.get(String.self, at: "scenario")
        let point = try req.query.get(String.self, at: "point")
        let format = (req.query[String.self, at: "format"] ?? "json").lowercased()

        if format == "geojson" {
            let polygons = try req.services.demo.hazardPolygons(
                scenarioId: scenario,
                pointId: point
            )
            let features: [GeoJSONPolygonFeature<HazardGeoJSONProperties>] = polygons.map { pair in
                GeoJSONPolygonFeature(
                    geometry: .from(rings: pair.rings),
                    properties: HazardGeoJSONProperties(
                        id: pair.item.id,
                        layer: pair.item.layer,
                        value: pair.item.value,
                        detail: pair.item.detail,
                        publisher: pair.item.publisher,
                        sourceId: pair.item.source.id
                    )
                )
            }
            let collection = GeoJSONPolygonFeatureCollection(features: features)
            let response = Response(status: .ok)
            try response.content.encode(collection, as: .json)
            return response
        }

        let section = try req.services.demo.hazards(scenarioId: scenario, pointId: point)
        let response = Response(status: .ok)
        try response.content.encode(section, as: .json)
        return response
    }
}

struct HealthzResponse: Content {
    let status: String
    let uptime: Double
}
