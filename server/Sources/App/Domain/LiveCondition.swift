// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Gauges (Hilltop)

struct GaugeReading: Content, Sendable, Equatable {
    let site: String
    let lat: Double
    let lng: Double
    let distanceKm: Double
    let measurement: String
    let value: Double
    let units: String
    let observedAt: Date
    /// `rising` / `falling` / `steady` — omitted when fewer than 2 readings.
    let trend: String?
    let source: SourceMeta
}

// MARK: - Electricity outages

struct ElectricityOutage: Content, Sendable, Equatable {
    let locationName: String?
    let distanceKm: Double
    let numAffected: Int?
    let status: String?
    let outageType: String?
    let distributor: String?
    let startedAt: Date?
    let link: String?
    let lat: Double?
    let lng: Double?
    let source: SourceMeta
}

// MARK: - Water network faults

struct WaterFault: Content, Sendable, Equatable {
    let description: String?
    let address: String?
    let distanceKm: Double
    let status: String?
    let priority: String?
    let reportedAt: Date?
    let lat: Double?
    let lng: Double?
    let source: SourceMeta
}

// MARK: - Envelope for GET /v1/conditions

struct ConditionsEnvelope: Content, Sendable {
    let gauges: [GaugeReading]
    let electricityOutages: [ElectricityOutage]
    let waterFaults: [WaterFault]
}
