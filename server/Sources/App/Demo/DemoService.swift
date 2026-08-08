// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

/// Serves curated demo scenarios under `/v1/demo/*` (offline / judge-safe).
struct DemoService: Sendable {
    func catalog() -> DemoCatalog {
        DemoScenarioData.catalog()
    }

    func picture(scenarioId: String, pointId: String) throws -> LocationPicture {
        let scenario = try parseScenario(scenarioId)
        let point = try parsePoint(pointId)
        return DemoScenarioData.picture(scenario: scenario, point: point)
    }

    func warnings(scenarioId: String, pointId: String) throws -> OfficialWarningsSection {
        try picture(scenarioId: scenarioId, pointId: pointId).officialWarnings
    }

    /// Warning records with rings for `?format=geojson` map layers.
    func warningRecords(scenarioId: String, pointId: String) throws -> [WarningRecord] {
        let scenario = try parseScenario(scenarioId)
        let point = try parsePoint(pointId)
        return DemoScenarioData.warningRecords(scenario: scenario, point: point)
    }

    func conditions(scenarioId: String, pointId: String) throws -> LocalConditionsSection {
        try picture(scenarioId: scenarioId, pointId: pointId).localConditions
    }

    func hazards(scenarioId: String, pointId: String) throws -> HazardsEnvelope {
        try picture(scenarioId: scenarioId, pointId: pointId).hazardContext
    }

    /// Hazard polygons for `?format=geojson` (tsunami / coastal at Lyall Bay).
    func hazardPolygons(
        scenarioId: String,
        pointId: String
    ) throws -> [(item: HazardItem, rings: [[GeoMath.Coordinate]])] {
        let scenario = try parseScenario(scenarioId)
        let point = try parsePoint(pointId)
        return DemoScenarioData.hazardPolygons(scenario: scenario, point: point)
    }

    /// Point features: gauges, outages, water faults, nearest hub (for map pins).
    func conditionPointFeatures(
        scenarioId: String,
        pointId: String
    ) throws -> [GeoJSONFeature<DemoConditionPointProperties>] {
        let picture = try picture(scenarioId: scenarioId, pointId: pointId)
        var features: [GeoJSONFeature<DemoConditionPointProperties>] = []

        for g in picture.localConditions.gauges {
            features.append(
                GeoJSONFeature(
                    geometry: .point(lng: g.lng, lat: g.lat),
                    properties: DemoConditionPointProperties(
                        kind: "gauge",
                        label: g.site,
                        detail: "\(g.measurement) \(g.value) \(g.units)",
                        sourceId: g.source.id
                    )
                )
            )
        }
        for o in picture.localConditions.electricityOutages {
            guard let lat = o.lat, let lng = o.lng else { continue }
            features.append(
                GeoJSONFeature(
                    geometry: .point(lng: lng, lat: lat),
                    properties: DemoConditionPointProperties(
                        kind: "outage",
                        label: o.locationName ?? "Outage",
                        detail: o.numAffected.map { "\($0) customers" },
                        sourceId: o.source.id
                    )
                )
            )
        }
        for w in picture.localConditions.waterFaults {
            guard let lat = w.lat, let lng = w.lng else { continue }
            features.append(
                GeoJSONFeature(
                    geometry: .point(lng: lng, lat: lat),
                    properties: DemoConditionPointProperties(
                        kind: "water",
                        label: w.description ?? w.address ?? "Water fault",
                        detail: w.status,
                        sourceId: w.source.id
                    )
                )
            )
        }
        if let hub = picture.location.nearestHub {
            features.append(
                GeoJSONFeature(
                    geometry: .point(lng: hub.lng, lat: hub.lat),
                    properties: DemoConditionPointProperties(
                        kind: "hub",
                        label: hub.name,
                        detail: hub.address,
                        sourceId: hub.source.id
                    )
                )
            )
        }
        return features
    }

    // MARK: - Parse

    private func parseScenario(_ id: String) throws -> DemoScenarioData.ScenarioID {
        guard let s = DemoScenarioData.ScenarioID(rawValue: id) else {
            throw Abort(
                .notFound,
                reason: "Unknown scenario '\(id)'. GET /v1/demo/scenarios for the catalogue."
            )
        }
        return s
    }

    private func parsePoint(_ id: String) throws -> DemoScenarioData.PointID {
        guard let p = DemoScenarioData.PointID(rawValue: id) else {
            throw Abort(
                .notFound,
                reason: "Unknown point '\(id)'. Use lyall-bay or karori."
            )
        }
        return p
    }
}
