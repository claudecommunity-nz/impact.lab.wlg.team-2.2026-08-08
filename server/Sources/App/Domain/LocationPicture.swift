// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Location

/// Hub plus distance for the picture `location.nearestHub` field.
struct NearestHub: Content, Sendable, Equatable {
    let id: Int
    let name: String
    let type: String?
    let address: String?
    let suburb: String?
    let town: String?
    let lat: Double
    let lng: Double
    let distanceKm: Double
    let source: SourceMeta

    init(hub: Hub, distanceKm: Double) {
        id = hub.id
        name = hub.name
        type = hub.type
        address = hub.address
        suburb = hub.suburb
        town = hub.town
        lat = hub.lat
        lng = hub.lng
        self.distanceKm = (distanceKm * 10).rounded() / 10
        source = hub.source
    }
}

struct PictureLocation: Content, Sendable {
    let lat: Double
    let lng: Double
    let nearestHub: NearestHub?
}

// MARK: - Sections

struct OfficialWarningsSection: Content, Sendable {
    let status: String
    let items: [Warning]
    let reason: String?

    static func ok(_ items: [Warning]) -> OfficialWarningsSection {
        .init(status: "ok", items: items, reason: nil)
    }

    static func unavailable(_ reason: String) -> OfficialWarningsSection {
        .init(status: "unavailable", items: [], reason: reason)
    }
}

struct LocalConditionsSection: Content, Sendable {
    let status: String
    let gauges: [GaugeReading]
    let electricityOutages: [ElectricityOutage]
    let waterFaults: [WaterFault]
    let reason: String?

    static func ok(_ envelope: ConditionsEnvelope) -> LocalConditionsSection {
        .init(
            status: "ok",
            gauges: envelope.gauges,
            electricityOutages: envelope.electricityOutages,
            waterFaults: envelope.waterFaults,
            reason: nil
        )
    }

    static func unavailable(_ reason: String) -> LocalConditionsSection {
        .init(
            status: "unavailable",
            gauges: [],
            electricityOutages: [],
            waterFaults: [],
            reason: reason
        )
    }
}

// MARK: - Provenance row

struct SourceStatusEntry: Content, Sendable, Equatable {
    let id: String
    let fetchedAt: Date?
    let status: String
}

// MARK: - Full picture

struct LocationPicture: Content, Sendable {
    let location: PictureLocation
    let officialWarnings: OfficialWarningsSection
    let localConditions: LocalConditionsSection
    let hazardContext: HazardsEnvelope
    let summary: [String]
    let generatedAt: Date
    let sources: [SourceStatusEntry]
    let disclaimer: String

    static let disclaimerText =
        "Information, not advice. Hazard layers are planning data, not live conditions. In an emergency call 111."
}
