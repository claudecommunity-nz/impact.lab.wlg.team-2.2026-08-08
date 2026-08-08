// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Wire model (upstream field names only)

struct HubRawAttributes: Decodable, Sendable {
    let OBJECTID: Int
    let NAME: String?
    let TYPE: String?
    let ADDRESS: String?
    let SUBURB: String?
    let TOWN: String?
    let TA_NAME: String?
}

// MARK: - Service

/// Fetches and caches WREMO community emergency hubs.
actor HubsService {
    static let catalogueId = "community-emergency-hubs"
    static let layerURL =
        "https://mapping.gw.govt.nz/arcgis/rest/services/GW/Emergencies_P/MapServer/2"
    static let publisherName = "WREMO Community Emergency Hubs"
    /// Static layer — 1 hour TTL per architecture brief.
    static let ttl: TimeInterval = 3600

    private let arcgis: ArcGISClient
    private let cache: SourceCache

    init(arcgis: ArcGISClient, cache: SourceCache) {
        self.arcgis = arcgis
        self.cache = cache
    }

    func allHubs() async throws -> (hubs: [Hub], source: SourceMeta) {
        if let cached = await cache.getFresh([Hub].self, key: Self.catalogueId) {
            let source = SourceMeta(
                name: Self.publisherName,
                id: Self.catalogueId,
                trust: .official,
                fetchedAt: cached.fetchedAt,
                url: Self.layerURL
            )
            return (cached.value, source)
        }

        let (features, fetchedAt): ([ArcGISFeature<HubRawAttributes>], Date) =
            try await arcgis.query(layerURL: Self.layerURL)

        let source = SourceMeta(
            name: Self.publisherName,
            id: Self.catalogueId,
            trust: .official,
            fetchedAt: fetchedAt,
            url: Self.layerURL
        )

        let hubs: [Hub] = features.compactMap { feature in
            guard let geom = feature.geometry,
                  let lng = geom.x,
                  let lat = geom.y,
                  lat != 0, lng != 0
            else { return nil }

            let attrs = feature.attributes
            return Hub(
                id: attrs.OBJECTID,
                name: attrs.NAME ?? "Hub \(attrs.OBJECTID)",
                type: attrs.TYPE,
                address: attrs.ADDRESS,
                suburb: attrs.SUBURB,
                town: attrs.TOWN,
                taName: attrs.TA_NAME,
                lat: lat,
                lng: lng,
                source: source
            )
        }

        await cache.set(Self.catalogueId, value: hubs, ttl: Self.ttl, fetchedAt: fetchedAt)
        return (hubs, source)
    }

    func hubs(bbox: GeoMath.BBox?) async throws -> (hubs: [Hub], source: SourceMeta) {
        let (all, source) = try await allHubs()
        guard let bbox else { return (all, source) }
        let filtered = all.filter { bbox.contains(lat: $0.lat, lng: $0.lng) }
        return (filtered, source)
    }
}

// Convenience overloads so call sites don't need type-parameter order gymnastics.
private extension SourceCache {
    func getFresh<T: Sendable>(_ type: T.Type, key: String) async -> Entry<T>? {
        getFresh(key, as: type)
    }
}
