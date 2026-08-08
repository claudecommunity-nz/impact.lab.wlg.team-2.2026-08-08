// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Trust label attached to every data item. `community-unverified` is reserved for later.
enum Trust: String, Codable, Sendable {
    case official
    case lifeline
    case planning
    case communityUnverified = "community-unverified"
}

/// Provenance carried on every item leaving the service.
struct SourceMeta: Codable, Sendable, Equatable {
    let name: String
    let id: String
    let trust: Trust
    let fetchedAt: Date
    let url: String?
}
