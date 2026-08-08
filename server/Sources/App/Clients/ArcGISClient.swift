// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Wire models (mirror ArcGIS JSON field names)

struct ArcGISQueryResponse<Attributes: Decodable & Sendable>: Decodable, Sendable {
    let features: [ArcGISFeature<Attributes>]
    let exceededTransferLimit: Bool?
    let error: ArcGISErrorBody?
}

struct ArcGISFeature<Attributes: Decodable & Sendable>: Decodable, Sendable {
    let attributes: Attributes
    let geometry: ArcGISGeometry?
}

/// Supports point (`x`/`y`) and polygon (`rings`) geometries returned by FeatureServers.
struct ArcGISGeometry: Decodable, Sendable {
    let x: Double?
    let y: Double?
    let rings: [[[Double]]]?
}

struct ArcGISErrorBody: Decodable, Sendable {
    let code: Int?
    let message: String?
}

// MARK: - Client

/// Generic ArcGIS FeatureServer / MapServer query client.
/// Always requests `outSR=4326`. Pages when `exceededTransferLimit` is set.
/// Serialises requests per host to be polite to council servers.
actor ArcGISClient {
    private let client: Client
    private let logger: Logger
    private var hostLastRequest: [String: ContinuousClock.Instant] = [:]
    private let minHostInterval: Duration

    /// Default page size — well under typical server maxRecordCount.
    static let defaultPageSize = 1000

    init(client: Client, logger: Logger, minHostInterval: Duration = .milliseconds(100)) {
        self.client = client
        self.logger = logger
        self.minHostInterval = minHostInterval
    }

    /// Query a layer endpoint (…/FeatureServer/0 or …/MapServer/2), paging until complete.
    func query<Attributes: Decodable & Sendable>(
        layerURL: String,
        where clause: String = "1=1",
        outFields: String = "*",
        geometry: String? = nil,
        geometryType: String? = nil,
        inSR: String? = nil,
        spatialRel: String? = nil,
        pageSize: Int = ArcGISClient.defaultPageSize
    ) async throws -> (features: [ArcGISFeature<Attributes>], fetchedAt: Date) {
        var all: [ArcGISFeature<Attributes>] = []
        var offset = 0
        let fetchedAt = Date()

        while true {
            var items: [URLQueryItem] = [
                .init(name: "where", value: clause),
                .init(name: "outFields", value: outFields),
                .init(name: "outSR", value: "4326"),
                .init(name: "f", value: "json"),
                .init(name: "resultOffset", value: String(offset)),
                .init(name: "resultRecordCount", value: String(pageSize)),
                .init(name: "returnGeometry", value: "true"),
            ]
            if let geometry {
                items.append(.init(name: "geometry", value: geometry))
            }
            if let geometryType {
                items.append(.init(name: "geometryType", value: geometryType))
            }
            if let inSR {
                items.append(.init(name: "inSR", value: inSR))
            }
            if let spatialRel {
                items.append(.init(name: "spatialRel", value: spatialRel))
            }

            let page: ArcGISQueryResponse<Attributes> = try await getJSON(
                baseURL: layerURL.hasSuffix("/query") ? layerURL : layerURL + "/query",
                queryItems: items
            )

            if let err = page.error {
                throw Abort(
                    .badGateway,
                    reason: "ArcGIS error \(err.code.map(String.init) ?? "?"): \(err.message ?? "unknown")"
                )
            }

            all.append(contentsOf: page.features)

            let hitLimit = page.exceededTransferLimit == true
            if !hitLimit || page.features.isEmpty {
                break
            }
            offset += page.features.count
            logger.debug("ArcGIS paging offset=\(offset) from \(layerURL)")
        }

        return (all, fetchedAt)
    }

    private func getJSON<T: Decodable>(
        baseURL: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        guard var components = URLComponents(string: baseURL) else {
            throw Abort(.internalServerError, reason: "Invalid ArcGIS URL: \(baseURL)")
        }
        // Merge with any existing query items on the base URL.
        var existing = components.queryItems ?? []
        existing.append(contentsOf: queryItems)
        components.queryItems = existing

        guard let url = components.url else {
            throw Abort(.internalServerError, reason: "Could not build ArcGIS URL")
        }

        try await throttle(for: url)

        logger.debug("ArcGIS GET \(url.absoluteString)")
        let response = try await client.get(URI(string: url.absoluteString))

        guard response.status == .ok else {
            throw Abort(
                .badGateway,
                reason: "ArcGIS HTTP \(response.status.code) for \(url.host ?? baseURL)"
            )
        }

        let body = Data(buffer: response.body ?? .init())
        do {
            return try JSONDecoder().decode(T.self, from: body)
        } catch {
            logger.error("ArcGIS decode failed: \(error)")
            throw Abort(.badGateway, reason: "Failed to decode ArcGIS response: \(error)")
        }
    }

    private func throttle(for url: URL) async throws {
        guard let host = url.host else { return }
        let now = ContinuousClock.now
        if let last = hostLastRequest[host] {
            let elapsed = now - last
            if elapsed < minHostInterval {
                try await Task.sleep(for: minHostInterval - elapsed)
            }
        }
        hostLastRequest[host] = ContinuousClock.now
    }
}
