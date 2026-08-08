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

    func conditions(scenarioId: String, pointId: String) throws -> LocalConditionsSection {
        try picture(scenarioId: scenarioId, pointId: pointId).localConditions
    }

    func hazards(scenarioId: String, pointId: String) throws -> HazardsEnvelope {
        try picture(scenarioId: scenarioId, pointId: pointId).hazardContext
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
