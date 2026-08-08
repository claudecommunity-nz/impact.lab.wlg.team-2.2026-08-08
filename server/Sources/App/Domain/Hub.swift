// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Community emergency hub (WREMO), domain model.
struct Hub: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let type: String?
    let address: String?
    let suburb: String?
    let town: String?
    let taName: String?
    let lat: Double
    let lng: Double
    let source: SourceMeta
}

struct HubsEnvelope: Codable, Sendable {
    let items: [Hub]
    let count: Int
    let source: SourceMeta
}
