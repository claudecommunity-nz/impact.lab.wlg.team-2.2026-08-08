// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

/// Catalog entry for `GET /v1/demo/scenarios`.
struct DemoScenarioInfo: Content, Sendable {
    let id: String
    let title: String
    let description: String
    /// Fixed demo points available under this scenario.
    let points: [DemoPointInfo]
}

struct DemoPointInfo: Content, Sendable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
}

struct DemoCatalog: Content, Sendable {
    let note: String
    let scenarios: [DemoScenarioInfo]
}

struct DemoUnavailable: Content, Sendable {
    let error: Bool
    let reason: String
}
