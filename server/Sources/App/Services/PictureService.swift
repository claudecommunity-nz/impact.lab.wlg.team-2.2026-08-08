// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

/// Joins hubs, warnings, conditions, and hazards into one Location Picture.
actor PictureService {
    private let hubs: HubsService
    private let warnings: WarningsService
    private let conditions: ConditionsService
    private let hazards: HazardsService
    private let logger: Logger

    init(
        hubs: HubsService,
        warnings: WarningsService,
        conditions: ConditionsService,
        hazards: HazardsService,
        logger: Logger
    ) {
        self.hubs = hubs
        self.warnings = warnings
        self.conditions = conditions
        self.hazards = hazards
        self.logger = logger
    }

    /// Build a picture for explicit coordinates.
    func picture(at point: GeoMath.Coordinate) async -> LocationPicture {
        await assemble(point: point)
    }

    /// Resolve hub id → coordinates, then assemble. Throws 404 if unknown.
    func picture(hubId: Int) async throws -> LocationPicture {
        let (all, _) = try await hubs.allHubs()
        guard let hub = all.first(where: { $0.id == hubId }) else {
            throw Abort(.notFound, reason: "Unknown hub id \(hubId)")
        }
        return await assemble(point: .init(lat: hub.lat, lng: hub.lng))
    }

    // MARK: - Assemble

    private func assemble(point: GeoMath.Coordinate) async -> LocationPicture {
        async let hubTask = fetchNearestHub(at: point)
        async let warningsTask = fetchWarnings(at: point)
        async let conditionsTask = fetchConditions(at: point)
        async let hazardsTask = hazards.hazards(at: point)

        let (nearest, hubSourceStatus) = await hubTask
        let (warningsSection, warningSources) = await warningsTask
        let (conditionsSection, conditionSources) = await conditionsTask
        let hazardSection = await hazardsTask

        let summary = SummaryBuilder.build(
            warnings: warningsSection,
            conditions: conditionsSection,
            hazards: hazardSection,
            nearestHub: nearest
        )

        var sources = warningSources + conditionSources + hazardSources(from: hazardSection)
        if let hubStatus = hubSourceStatus {
            sources.append(hubStatus)
        }
        sources = dedupeSources(sources)

        return LocationPicture(
            location: PictureLocation(
                lat: point.lat,
                lng: point.lng,
                nearestHub: nearest
            ),
            officialWarnings: warningsSection,
            localConditions: conditionsSection,
            hazardContext: hazardSection,
            summary: summary,
            generatedAt: Date(),
            sources: sources,
            disclaimer: LocationPicture.disclaimerText
        )
    }

    // MARK: - Per-section fetches (never throw out of assemble)

    private func fetchNearestHub(
        at point: GeoMath.Coordinate
    ) async -> (NearestHub?, SourceStatusEntry?) {
        do {
            let (all, source) = try await hubs.allHubs()
            let origin = GeoMath.Coordinate(lat: point.lat, lng: point.lng)
            guard let best = all.min(by: {
                GeoMath.haversineKm(from: origin, to: .init(lat: $0.lat, lng: $0.lng))
                    < GeoMath.haversineKm(from: origin, to: .init(lat: $1.lat, lng: $1.lng))
            }) else {
                return (
                    nil,
                    SourceStatusEntry(id: source.id, fetchedAt: source.fetchedAt, status: "ok")
                )
            }
            let d = GeoMath.haversineKm(
                from: origin,
                to: .init(lat: best.lat, lng: best.lng)
            )
            return (
                NearestHub(hub: best, distanceKm: d),
                SourceStatusEntry(id: source.id, fetchedAt: source.fetchedAt, status: "ok")
            )
        } catch {
            logger.warning("Picture nearest hub failed: \(error)")
            return (
                nil,
                SourceStatusEntry(
                    id: HubsService.catalogueId,
                    fetchedAt: nil,
                    status: "unavailable"
                )
            )
        }
    }

    private func fetchWarnings(
        at point: GeoMath.Coordinate
    ) async -> (OfficialWarningsSection, [SourceStatusEntry]) {
        do {
            let items = try await warnings.warnings(at: point)
            var byId: [String: SourceStatusEntry] = [:]
            for w in items {
                byId[w.source.id] = SourceStatusEntry(
                    id: w.source.id,
                    fetchedAt: w.source.fetchedAt,
                    status: "ok"
                )
            }
            // Always list expected warning catalogues when ok (even if empty).
            if byId.isEmpty {
                byId["metservice-warnings"] = SourceStatusEntry(
                    id: "metservice-warnings",
                    fetchedAt: Date(),
                    status: "ok"
                )
                byId["nema-cap-alerts"] = SourceStatusEntry(
                    id: "nema-cap-alerts",
                    fetchedAt: Date(),
                    status: "ok"
                )
            }
            return (.ok(items), Array(byId.values))
        } catch {
            logger.warning("Picture warnings failed: \(error)")
            return (
                .unavailable(String(describing: error)),
                [
                    SourceStatusEntry(id: "metservice-warnings", fetchedAt: nil, status: "unavailable"),
                    SourceStatusEntry(id: "nema-cap-alerts", fetchedAt: nil, status: "unavailable"),
                ]
            )
        }
    }

    private func fetchConditions(
        at point: GeoMath.Coordinate
    ) async -> (LocalConditionsSection, [SourceStatusEntry]) {
        do {
            let envelope = try await conditions.conditions(at: point, n: 5, radiusKm: 10)
            var byId: [String: SourceStatusEntry] = [:]
            for g in envelope.gauges {
                byId[g.source.id] = SourceStatusEntry(
                    id: g.source.id,
                    fetchedAt: g.source.fetchedAt,
                    status: "ok"
                )
            }
            for o in envelope.electricityOutages {
                byId[o.source.id] = SourceStatusEntry(
                    id: o.source.id,
                    fetchedAt: o.source.fetchedAt,
                    status: "ok"
                )
            }
            for f in envelope.waterFaults {
                byId[f.source.id] = SourceStatusEntry(
                    id: f.source.id,
                    fetchedAt: f.source.fetchedAt,
                    status: "ok"
                )
            }
            // Catalogue rows even when a sub-source returned nothing.
            if byId["hilltop"] == nil {
                byId["hilltop"] = SourceStatusEntry(id: "hilltop", fetchedAt: Date(), status: "ok")
            }
            if byId["electricity-outages"] == nil {
                byId["electricity-outages"] = SourceStatusEntry(
                    id: "electricity-outages",
                    fetchedAt: Date(),
                    status: "ok"
                )
            }
            if byId["water-network-faults"] == nil {
                byId["water-network-faults"] = SourceStatusEntry(
                    id: "water-network-faults",
                    fetchedAt: Date(),
                    status: "ok"
                )
            }
            return (.ok(envelope), Array(byId.values))
        } catch {
            logger.warning("Picture conditions failed: \(error)")
            return (
                .unavailable(String(describing: error)),
                [
                    SourceStatusEntry(id: "hilltop", fetchedAt: nil, status: "unavailable"),
                    SourceStatusEntry(id: "electricity-outages", fetchedAt: nil, status: "unavailable"),
                    SourceStatusEntry(id: "water-network-faults", fetchedAt: nil, status: "unavailable"),
                ]
            )
        }
    }

    private func hazardSources(from envelope: HazardsEnvelope) -> [SourceStatusEntry] {
        var byId: [String: SourceStatusEntry] = [:]
        for item in envelope.items {
            byId[item.source.id] = SourceStatusEntry(
                id: item.source.id,
                fetchedAt: item.source.fetchedAt,
                status: "ok"
            )
        }
        if envelope.status == "unavailable" && byId.isEmpty {
            byId["tsunami-evacuation-zones"] = SourceStatusEntry(
                id: "tsunami-evacuation-zones",
                fetchedAt: nil,
                status: "unavailable"
            )
        }
        return Array(byId.values)
    }

    private func dedupeSources(_ entries: [SourceStatusEntry]) -> [SourceStatusEntry] {
        var byId: [String: SourceStatusEntry] = [:]
        for e in entries {
            if let existing = byId[e.id] {
                // Prefer ok over unavailable; prefer later fetchedAt.
                if existing.status == "unavailable", e.status == "ok" {
                    byId[e.id] = e
                } else if existing.status == e.status,
                          let a = existing.fetchedAt,
                          let b = e.fetchedAt,
                          b > a {
                    byId[e.id] = e
                }
            } else {
                byId[e.id] = e
            }
        }
        return byId.values.sorted { $0.id < $1.id }
    }
}
