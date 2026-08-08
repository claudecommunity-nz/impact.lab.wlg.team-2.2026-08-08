// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Official CAP-derived warning covering (or available for) a location.
struct Warning: Codable, Sendable, Equatable {
    let id: String
    let event: String
    let headline: String?
    let severity: String?
    let urgency: String?
    let certainty: String?
    let areaDesc: String?
    let onset: Date?
    let expires: Date?
    let description: String?
    let web: String?
    let source: SourceMeta
}

struct WarningsEnvelope: Codable, Sendable {
    let items: [Warning]
    let count: Int
}

/// Internal record retaining polygon rings for point-in-polygon filtering.
struct WarningRecord: Sendable {
    let warning: Warning
    let rings: [[GeoMath.Coordinate]]

    func covers(_ point: GeoMath.Coordinate) -> Bool {
        GeoMath.pointInPolygonRings(point: point, rings: rings)
    }
}
