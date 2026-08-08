// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreLocation

// MARK: - Shared

struct HealthzResponse: Codable, Sendable {
    let status: String
}

enum Trust: String, Codable, Sendable, Hashable {
    case official
    case lifeline
    case planning
    case communityUnverified = "community-unverified"
}

struct SourceMeta: Codable, Sendable, Hashable {
    let name: String
    let id: String
    let trust: Trust
    let fetchedAt: Date
    let url: String?
}

struct LatLng: Hashable, Sendable, Equatable {
    var lat: Double
    var lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    static let lyallBay = LatLng(lat: -41.3286, lng: 174.7947)
    static let karori = LatLng(lat: -41.2865, lng: 174.7405)
    static let wellingtonCBD = LatLng(lat: -41.2865, lng: 174.7762)
}

// MARK: - Warnings

struct Warning: Codable, Sendable, Identifiable, Hashable {
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

// MARK: - Conditions

struct GaugeReading: Codable, Sendable, Identifiable, Hashable {
    var id: String { "\(site)-\(measurement)-\(observedAt.timeIntervalSince1970)" }
    let site: String
    let lat: Double
    let lng: Double
    let distanceKm: Double
    let measurement: String
    let value: Double
    let units: String
    let observedAt: Date
    let trend: String?
    let source: SourceMeta
}

struct ElectricityOutage: Codable, Sendable, Identifiable, Hashable {
    var id: String {
        "\(locationName ?? "outage")-\(startedAt?.timeIntervalSince1970 ?? distanceKm)"
    }
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

struct WaterFault: Codable, Sendable, Identifiable, Hashable {
    var id: String {
        "\(address ?? description ?? "fault")-\(reportedAt?.timeIntervalSince1970 ?? distanceKm)"
    }
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

// MARK: - Hubs / hazards

struct NearestHub: Codable, Sendable, Hashable {
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
}

struct HazardItem: Codable, Sendable, Identifiable, Hashable {
    var id: String { "\(layerId)-\(value)" }
    let layer: String
    let layerId: String
    let value: String
    let detail: String?
    let publisher: String
    let source: SourceMeta

    enum CodingKeys: String, CodingKey {
        case layer
        case layerId = "id"
        case value, detail, publisher, source
    }
}

struct HazardsEnvelope: Codable, Sendable, Hashable {
    let status: String
    let note: String
    let items: [HazardItem]
}

// MARK: - Picture

struct PictureLocation: Codable, Sendable, Hashable {
    let lat: Double
    let lng: Double
    let nearestHub: NearestHub?
}

struct OfficialWarningsSection: Codable, Sendable, Hashable {
    let status: String
    let items: [Warning]
    let reason: String?
}

struct LocalConditionsSection: Codable, Sendable, Hashable {
    let status: String
    let gauges: [GaugeReading]
    let electricityOutages: [ElectricityOutage]
    let waterFaults: [WaterFault]
    let reason: String?
}

struct SourceStatusEntry: Codable, Sendable, Identifiable, Hashable {
    var id: String { sourceId }
    let sourceId: String
    let fetchedAt: Date?
    let status: String

    enum CodingKeys: String, CodingKey {
        case sourceId = "id"
        case fetchedAt, status
    }
}

struct LocationPicture: Codable, Sendable, Hashable {
    let location: PictureLocation
    let officialWarnings: OfficialWarningsSection
    let localConditions: LocalConditionsSection
    let hazardContext: HazardsEnvelope
    let summary: [String]
    let generatedAt: Date
    let sources: [SourceStatusEntry]
    let disclaimer: String
}

// MARK: - Demo catalogue

struct DemoPointInfo: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
}

struct DemoScenarioInfo: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let points: [DemoPointInfo]
}

struct DemoCatalog: Codable, Sendable, Hashable {
    let note: String
    let scenarios: [DemoScenarioInfo]
}

// MARK: - GeoJSON (minimal)

struct GeoJSONFeatureCollection: Codable, Sendable {
    let type: String
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Codable, Sendable, Identifiable {
    var id: String {
        if let p = properties {
            if let s = p["id"]?.stringValue { return s }
            if let kind = p["kind"]?.stringValue,
               let name = p["site"]?.stringValue ?? p["locationName"]?.stringValue {
                return "\(kind)-\(name)"
            }
            if let s = p["name"]?.stringValue { return s }
        }
        return UUID().uuidString
    }

    let type: String
    let geometry: GeoJSONGeometry?
    let properties: [String: AnyCodable]?
}

struct GeoJSONGeometry: Codable, Sendable {
    let type: String
    let coordinates: AnyCodable
}

struct AnyCodable: Codable, Sendable, Hashable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if let i = try? container.decode(Int.self) {
            value = i
        } else if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let arr as [Any]:
            try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                .init(codingPath: container.codingPath, debugDescription: "Unsupported")
            )
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }

    var stringValue: String? { value as? String }
}
