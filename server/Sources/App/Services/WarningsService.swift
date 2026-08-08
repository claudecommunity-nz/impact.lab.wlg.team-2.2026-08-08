// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Wire models (upstream field names only)

struct MetServiceWarningRaw: Decodable, Sendable {
    let identifier: String?
    let info_event: String?
    let info_headline: String?
    let info_severity: String?
    let info_urgency: String?
    let info_certainty: String?
    let info_area_areaDesc: String?
    let info_description: String?
    let info_web: String?
    let status: String?
    let onset: Date?
    let validto: Date?
    let sent: Date?

    enum CodingKeys: String, CodingKey {
        case identifier, info_event, info_headline, info_severity, info_urgency
        case info_certainty, info_area_areaDesc, info_description, info_web, status
        case onset, validto, sent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try c.decodeIfPresent(String.self, forKey: .identifier)
        info_event = try c.decodeIfPresent(String.self, forKey: .info_event)
        info_headline = try c.decodeIfPresent(String.self, forKey: .info_headline)
        info_severity = try c.decodeIfPresent(String.self, forKey: .info_severity)
        info_urgency = try c.decodeIfPresent(String.self, forKey: .info_urgency)
        info_certainty = try c.decodeIfPresent(String.self, forKey: .info_certainty)
        info_area_areaDesc = try c.decodeIfPresent(String.self, forKey: .info_area_areaDesc)
        info_description = try c.decodeIfPresent(String.self, forKey: .info_description)
        info_web = try c.decodeIfPresent(String.self, forKey: .info_web)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        onset = ArcGISDate.decode(from: c, forKey: .onset)
        validto = ArcGISDate.decode(from: c, forKey: .validto)
        sent = ArcGISDate.decode(from: c, forKey: .sent)
    }
}

struct NemaCapWarningRaw: Decodable, Sendable {
    let identifier: String?
    let event: String?
    let headline: String?
    let severity: String?
    let urgency: String?
    let certainty: String?
    let description: String?
    let status: String?
    let historic: Int?
    let sent: Date?
    let effective: Date?
    let expires: Date?

    enum CodingKeys: String, CodingKey {
        case identifier, event, headline, severity, urgency, certainty
        case description, status, historic, sent, effective, expires
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try c.decodeIfPresent(String.self, forKey: .identifier)
        event = try c.decodeIfPresent(String.self, forKey: .event)
        headline = try c.decodeIfPresent(String.self, forKey: .headline)
        severity = try c.decodeIfPresent(String.self, forKey: .severity)
        urgency = try c.decodeIfPresent(String.self, forKey: .urgency)
        certainty = try c.decodeIfPresent(String.self, forKey: .certainty)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        historic = try c.decodeIfPresent(Int.self, forKey: .historic)
        sent = ArcGISDate.decode(from: c, forKey: .sent)
        effective = ArcGISDate.decode(from: c, forKey: .effective)
        expires = ArcGISDate.decode(from: c, forKey: .expires)
    }
}

// MARK: - Service

/// Active CAP warnings from MetService (Eagle) + NEMA Emergency Mobile Alerts.
actor WarningsService {
    static let metserviceId = "metservice-warnings"
    static let nemaId = "nema-cap-alerts"
    static let metserviceURL =
        "https://services.arcgis.com/XTtANUDT8Va4DLwI/arcgis/rest/services/Metservice_Weather_Alerts/FeatureServer/0"
    /// Parentheses in the service name — URLComponents percent-encodes the path.
    static let nemaURL =
        "https://services5.arcgis.com/cJn6oR1QqErYBL5d/arcgis/rest/services/NZ_CAP_Alerts_(Read_only)/FeatureServer/0"
    static let cacheKey = "warnings-all"
    static let ttl: TimeInterval = 60

    private let arcgis: ArcGISClient
    private let cache: SourceCache
    private let logger: Logger

    init(arcgis: ArcGISClient, cache: SourceCache, logger: Logger) {
        self.arcgis = arcgis
        self.cache = cache
        self.logger = logger
    }

    /// All active NZ-wide warnings, or those whose polygon covers `point`.
    func warnings(at point: GeoMath.Coordinate? = nil) async throws -> [Warning] {
        try await warningRecords(at: point).map(\.warning)
    }

    func warningRecords(at point: GeoMath.Coordinate? = nil) async throws -> [WarningRecord] {
        let records = try await allRecords()
        guard let point else { return records }
        return records.filter { $0.covers(point) }
    }

    private func allRecords() async throws -> [WarningRecord] {
        if let cached = await cache.getFresh(Self.cacheKey, as: [WarningRecord].self) {
            return cached.value
        }

        // Sequential per host policy — different hosts, still sequential overall to keep it simple.
        async let met = fetchMetService()
        // NEMA on a different host; await after met to stay polite and surface partial results.
        let metRecords = await met
        let nemaRecords = await fetchNema()

        let combined = metRecords + nemaRecords
        let fetchedAt = Date()
        await cache.set(Self.cacheKey, value: combined, ttl: Self.ttl, fetchedAt: fetchedAt)
        return combined
    }

    private func fetchMetService() async -> [WarningRecord] {
        do {
            let (features, fetchedAt): ([ArcGISFeature<MetServiceWarningRaw>], Date) =
                try await arcgis.query(
                    layerURL: Self.metserviceURL,
                    where: "status='Actual'"
                )
            let source = SourceMeta(
                name: "MetService (via Eagle CAP feed)",
                id: Self.metserviceId,
                trust: .official,
                fetchedAt: fetchedAt,
                url: Self.metserviceURL
            )
            let now = Date()
            return features.compactMap { feature in
                mapMetService(feature, source: source, now: now)
            }
        } catch {
            logger.warning("MetService warnings fetch failed: \(error)")
            return []
        }
    }

    private func fetchNema() async -> [WarningRecord] {
        do {
            let (features, fetchedAt): ([ArcGISFeature<NemaCapWarningRaw>], Date) =
                try await arcgis.query(
                    layerURL: Self.nemaURL,
                    where: "historic=0 AND status='Actual'"
                )
            let source = SourceMeta(
                name: "NEMA Emergency Mobile Alerts",
                id: Self.nemaId,
                trust: .official,
                fetchedAt: fetchedAt,
                url: Self.nemaURL
            )
            let now = Date()
            return features.compactMap { feature in
                mapNema(feature, source: source, now: now)
            }
        } catch {
            logger.warning("NEMA CAP alerts fetch failed: \(error)")
            return []
        }
    }

    private func mapMetService(
        _ feature: ArcGISFeature<MetServiceWarningRaw>,
        source: SourceMeta,
        now: Date
    ) -> WarningRecord? {
        let raw = feature.attributes
        // Client-side expiry: validto > now when present.
        if let expires = raw.validto, expires <= now { return nil }
        guard let ringsRaw = feature.geometry?.rings, !ringsRaw.isEmpty else { return nil }
        let rings = GeoMath.rings(fromArcGIS: ringsRaw)
        guard !rings.isEmpty else { return nil }

        let id = raw.identifier ?? UUID().uuidString
        let event = raw.info_event ?? raw.info_headline ?? "Weather alert"
        let warning = Warning(
            id: id,
            event: event,
            headline: raw.info_headline,
            severity: raw.info_severity,
            urgency: raw.info_urgency,
            certainty: raw.info_certainty,
            areaDesc: raw.info_area_areaDesc,
            onset: raw.onset,
            expires: raw.validto,
            description: raw.info_description,
            web: raw.info_web,
            source: source
        )
        return WarningRecord(warning: warning, rings: rings)
    }

    private func mapNema(
        _ feature: ArcGISFeature<NemaCapWarningRaw>,
        source: SourceMeta,
        now: Date
    ) -> WarningRecord? {
        let raw = feature.attributes
        if let expires = raw.expires, expires <= now { return nil }
        guard let ringsRaw = feature.geometry?.rings, !ringsRaw.isEmpty else { return nil }
        let rings = GeoMath.rings(fromArcGIS: ringsRaw)
        guard !rings.isEmpty else { return nil }

        let id = raw.identifier ?? UUID().uuidString
        let event = raw.event ?? raw.headline ?? "CAP alert"
        let warning = Warning(
            id: id,
            event: event,
            headline: raw.headline,
            severity: raw.severity,
            urgency: raw.urgency,
            certainty: raw.certainty,
            areaDesc: nil,
            onset: raw.effective ?? raw.sent,
            expires: raw.expires,
            description: raw.description,
            web: nil,
            source: source
        )
        return WarningRecord(warning: warning, rings: rings)
    }
}

