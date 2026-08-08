// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Wire models (per-layer attribute shapes)

/// Tsunami evacuation zone attributes (WCC MapServer/1).
struct TsunamiZoneRawAttributes: Decodable, Sendable {
    let Evac_Zone: String?
    let Zone_Class: Int?
    let Col_Code: String?
    let Location: String?
    let Info: String?
    let Heights: String?

    enum CodingKeys: String, CodingKey {
        case Evac_Zone, Zone_Class, Col_Code, Location, Info, Heights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        Evac_Zone = try c.decodeIfPresent(String.self, forKey: .Evac_Zone)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .Zone_Class) {
            Zone_Class = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .Zone_Class) {
            Zone_Class = Int(d)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .Zone_Class),
                  let i = Int(s) {
            Zone_Class = i
        } else {
            Zone_Class = nil
        }
        Col_Code = try c.decodeIfPresent(String.self, forKey: .Col_Code)
        Location = try c.decodeIfPresent(String.self, forKey: .Location)
        Info = try c.decodeIfPresent(String.self, forKey: .Info)
        Heights = try c.decodeIfPresent(String.self, forKey: .Heights)
    }
}

/// Catch-all for planning polygons where presence alone is the signal.
struct EmptyAttributes: Decodable, Sendable {}

// MARK: - Service

/// Static hazard context: server-side point-intersect against WCC planning layers.
actor HazardsService {
    static let hazardsTTL: TimeInterval = 3600
    static let planningNote =
        "Planning layers — where hazards CAN occur, not live conditions."

    private struct LayerDef: Sendable {
        let id: String
        let displayName: String
        let url: String
        let publisher: String
        let sourceName: String
        let kind: Kind

        enum Kind: Sendable {
            case tsunami
            case presence  // any feature → value "inside"
        }
    }

    private static let layers: [LayerDef] = [
        .init(
            id: "tsunami-evacuation-zones",
            displayName: "Tsunami Evacuation Zones",
            url: "https://gis.wcc.govt.nz/arcgis/rest/services/Environment/TsunamiEvacuationZones/MapServer/1",
            publisher: "Wellington City Council",
            sourceName: "WCC Tsunami Evacuation Zones",
            kind: .tsunami
        ),
        .init(
            id: "coastal-inundation-medium",
            displayName: "Coastal Inundation (Medium)",
            url: "https://gis.wcc.govt.nz/arcgis/rest/services/DistrictPlanProposed/DistrictPlanProposed/MapServer/39",
            publisher: "Wellington City Council / NIWA (2021)",
            sourceName: "WCC Proposed District Plan",
            kind: .presence
        ),
        .init(
            id: "coastal-inundation-high",
            displayName: "Coastal Inundation (High)",
            url: "https://gis.wcc.govt.nz/arcgis/rest/services/DistrictPlanProposed/DistrictPlanProposed/MapServer/40",
            publisher: "Wellington City Council / NIWA (2021)",
            sourceName: "WCC Proposed District Plan",
            kind: .presence
        ),
        .init(
            id: "stream-corridor",
            displayName: "Stream Corridor",
            url: "https://gis.wcc.govt.nz/arcgis/rest/services/DistrictPlanProposed/DistrictPlanProposed/MapServer/53",
            publisher: "Wellington City Council",
            sourceName: "WCC Proposed District Plan",
            kind: .presence
        ),
    ]

    private let arcgis: ArcGISClient
    private let cache: SourceCache
    private let logger: Logger

    init(arcgis: ArcGISClient, cache: SourceCache, logger: Logger) {
        self.arcgis = arcgis
        self.cache = cache
        self.logger = logger
    }

    func hazards(at point: GeoMath.Coordinate) async -> HazardsEnvelope {
        let cacheKey = Self.cacheKey(for: point)
        if let cached = await cache.getFresh(cacheKey, as: HazardsEnvelope.self) {
            return cached.value
        }

        // Same host for all layers — sequential to stay polite.
        var items: [HazardItem] = []
        var anySuccess = false
        var anyAttempted = false

        for layer in Self.layers {
            anyAttempted = true
            do {
                let layerItems = try await queryLayer(layer, at: point)
                anySuccess = true
                items.append(contentsOf: layerItems)
            } catch {
                logger.warning("Hazard layer \(layer.id) failed: \(error)")
            }
        }

        let status: String
        if !anyAttempted || anySuccess {
            status = "ok"
        } else {
            status = "unavailable"
        }

        let envelope = HazardsEnvelope(
            status: status,
            note: Self.planningNote,
            items: items
        )
        // Cache successes and empty ok results; still cache unavailable briefly
        // so a dead GIS host is not hammered every request.
        let ttl = status == "ok" ? Self.hazardsTTL : 60.0
        await cache.set(cacheKey, value: envelope, ttl: ttl)
        return envelope
    }

    /// Real WCC/NIWA polygon rings for map GeoJSON (`?format=geojson`).
    /// Geometry comes only from ArcGIS — never synthesised.
    func polygons(at point: GeoMath.Coordinate) async -> [(item: HazardItem, rings: [[GeoMath.Coordinate]])] {
        var out: [(HazardItem, [[GeoMath.Coordinate]])] = []
        for layer in Self.layers {
            do {
                let pairs = try await queryLayerPolygons(layer, at: point)
                out.append(contentsOf: pairs)
            } catch {
                logger.warning("Hazard polygon layer \(layer.id) failed: \(error)")
            }
        }
        return out
    }

    // MARK: - Per-layer query

    private func queryLayer(_ layer: LayerDef, at point: GeoMath.Coordinate) async throws -> [HazardItem] {
        let geometry = "\(point.lng),\(point.lat)"
        switch layer.kind {
        case .tsunami:
            let (features, fetchedAt): ([ArcGISFeature<TsunamiZoneRawAttributes>], Date) =
                try await arcgis.query(
                    layerURL: layer.url,
                    outFields: "Evac_Zone,Zone_Class,Col_Code,Location,Info,Heights",
                    geometry: geometry,
                    geometryType: "esriGeometryPoint",
                    inSR: "4326",
                    spatialRel: "esriSpatialRelIntersects"
                )
            let source = Self.sourceMeta(layer: layer, fetchedAt: fetchedAt)
            return features.map { feature in
                Self.tsunamiItem(layer: layer, source: source, raw: feature.attributes)
            }
        case .presence:
            let (features, fetchedAt): ([ArcGISFeature<EmptyAttributes>], Date) =
                try await arcgis.query(
                    layerURL: layer.url,
                    outFields: "*",
                    geometry: geometry,
                    geometryType: "esriGeometryPoint",
                    inSR: "4326",
                    spatialRel: "esriSpatialRelIntersects"
                )
            guard !features.isEmpty else { return [] }
            let source = Self.sourceMeta(layer: layer, fetchedAt: fetchedAt)
            // One item per layer for the picture envelope (not one per feature).
            return [
                HazardItem(
                    layer: layer.displayName,
                    id: layer.id,
                    value: "inside",
                    detail: features.count > 1 ? "\(features.count) polygons" : nil,
                    publisher: layer.publisher,
                    source: source
                ),
            ]
        }
    }

    /// One map feature per ArcGIS polygon that intersects the point (real rings).
    private func queryLayerPolygons(
        _ layer: LayerDef,
        at point: GeoMath.Coordinate
    ) async throws -> [(item: HazardItem, rings: [[GeoMath.Coordinate]])] {
        let geometry = "\(point.lng),\(point.lat)"
        switch layer.kind {
        case .tsunami:
            let (features, fetchedAt): ([ArcGISFeature<TsunamiZoneRawAttributes>], Date) =
                try await arcgis.query(
                    layerURL: layer.url,
                    outFields: "Evac_Zone,Zone_Class,Col_Code,Location,Info,Heights",
                    geometry: geometry,
                    geometryType: "esriGeometryPoint",
                    inSR: "4326",
                    spatialRel: "esriSpatialRelIntersects"
                )
            let source = Self.sourceMeta(layer: layer, fetchedAt: fetchedAt)
            return features.compactMap { feature -> (HazardItem, [[GeoMath.Coordinate]])? in
                guard let rings = Self.rings(from: feature.geometry) else { return nil }
                let item = Self.tsunamiItem(layer: layer, source: source, raw: feature.attributes)
                return (item, rings)
            }
        case .presence:
            let (features, fetchedAt): ([ArcGISFeature<EmptyAttributes>], Date) =
                try await arcgis.query(
                    layerURL: layer.url,
                    outFields: "*",
                    geometry: geometry,
                    geometryType: "esriGeometryPoint",
                    inSR: "4326",
                    spatialRel: "esriSpatialRelIntersects"
                )
            let source = Self.sourceMeta(layer: layer, fetchedAt: fetchedAt)
            return features.compactMap { feature -> (HazardItem, [[GeoMath.Coordinate]])? in
                guard let rings = Self.rings(from: feature.geometry) else { return nil }
                let item = HazardItem(
                    layer: layer.displayName,
                    id: layer.id,
                    value: "inside",
                    detail: nil,
                    publisher: layer.publisher,
                    source: source
                )
                return (item, rings)
            }
        }
    }

    private static func sourceMeta(layer: LayerDef, fetchedAt: Date) -> SourceMeta {
        SourceMeta(
            name: layer.sourceName,
            id: layer.id,
            trust: .planning,
            fetchedAt: fetchedAt,
            url: layer.url
        )
    }

    private static func tsunamiItem(
        layer: LayerDef,
        source: SourceMeta,
        raw: TsunamiZoneRawAttributes
    ) -> HazardItem {
        let colour = raw.Col_Code?.trimmingCharacters(in: .whitespacesAndNewlines)
        let zone = raw.Evac_Zone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String
        if let colour, !colour.isEmpty {
            let titled = colour.prefix(1).uppercased() + colour.dropFirst().lowercased()
            value = titled.lowercased().contains("zone") ? titled : "\(titled) Zone"
        } else if let zone, !zone.isEmpty {
            value = zone
        } else {
            value = "inside"
        }
        var detailParts: [String] = []
        if let zc = raw.Zone_Class {
            detailParts.append("Zone_Class \(zc)")
        }
        if let loc = raw.Location, !loc.isEmpty {
            detailParts.append(loc)
        }
        if let heights = raw.Heights, !heights.isEmpty {
            detailParts.append(heights)
        }
        if let info = raw.Info, !info.isEmpty, detailParts.isEmpty {
            detailParts.append(info)
        }
        return HazardItem(
            layer: layer.displayName,
            id: layer.id,
            value: value,
            detail: detailParts.isEmpty ? nil : detailParts.joined(separator: " — "),
            publisher: layer.publisher,
            source: source
        )
    }

    private static func rings(from geometry: ArcGISGeometry?) -> [[GeoMath.Coordinate]]? {
        guard let raw = geometry?.rings, !raw.isEmpty else { return nil }
        let rings = GeoMath.rings(fromArcGIS: raw).filter { $0.count >= 3 }
        return rings.isEmpty ? nil : rings
    }

    /// Round to ~11 m so nearby clicks share a 1 h cache entry.
    private static func cacheKey(for point: GeoMath.Coordinate) -> String {
        let lat = (point.lat * 10_000).rounded() / 10_000
        let lng = (point.lng * 10_000).rounded() / 10_000
        return "hazards:\(lat):\(lng)"
    }
}
