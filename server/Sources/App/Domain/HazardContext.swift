// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

/// One planning-layer hit for a point (static hazard context, not live conditions).
struct HazardItem: Content, Sendable, Equatable {
    /// Human display name for the layer.
    let layer: String
    /// Dataset id from the catalogue (e.g. `tsunami-evacuation-zones`).
    let id: String
    /// Primary value shown to clients (e.g. "Red Zone", "inside").
    let value: String
    /// Optional detail (zone class, heights, etc.).
    let detail: String?
    let publisher: String
    let source: SourceMeta
}

/// Envelope for `GET /v1/hazards`.
struct HazardsEnvelope: Content, Sendable {
    /// `ok` when at least one layer answered; `unavailable` if all failed.
    let status: String
    /// Always present — planning data disclaimer.
    let note: String
    let items: [HazardItem]
}
