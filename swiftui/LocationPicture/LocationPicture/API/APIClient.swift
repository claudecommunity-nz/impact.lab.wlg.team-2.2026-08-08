// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

enum APIError: LocalizedError {
    case unreachable(baseURL: String)
    case http(path: String, status: Int)
    case decode(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unreachable(let base):
            return "Can't reach \(base) — is the backend running?"
        case .http(let path, let status):
            return "\(path) → HTTP \(status)"
        case .decode(let path, let err):
            return "Decode failed for \(path): \(err.localizedDescription)"
        }
    }
}

actor APIClient {
    private(set) var baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "http://127.0.0.1:8080")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder.locationPicture
    }

    func setBaseURL(_ url: URL) {
        baseURL = url
    }

    func healthz() async throws -> HealthzResponse {
        try await getJSON(path: "/healthz")
    }

    func picture(lat: Double, lng: Double) async throws -> LocationPicture {
        try await getJSON(path: "/v1/picture", query: [
            "lat": String(lat),
            "lng": String(lng),
        ])
    }

    func warningsGeoJSON(lat: Double?, lng: Double?) async throws -> GeoJSONFeatureCollection {
        var query = ["format": "geojson"]
        if let lat, let lng {
            query["lat"] = String(lat)
            query["lng"] = String(lng)
        }
        return try await getJSON(path: "/v1/warnings", query: query)
    }

    func conditionsGeoJSON(lat: Double, lng: Double) async throws -> GeoJSONFeatureCollection {
        try await getJSON(path: "/v1/conditions", query: [
            "lat": String(lat),
            "lng": String(lng),
            "format": "geojson",
        ])
    }

    func hazardsGeoJSON(lat: Double, lng: Double) async throws -> GeoJSONFeatureCollection {
        try await getJSON(path: "/v1/hazards", query: [
            "lat": String(lat),
            "lng": String(lng),
            "format": "geojson",
        ])
    }

    func demoScenarios() async throws -> DemoCatalog {
        try await getJSON(path: "/v1/demo/scenarios")
    }

    func demoPicture(scenario: String, point: String) async throws -> LocationPicture {
        try await getJSON(path: "/v1/demo/picture", query: [
            "scenario": scenario,
            "point": point,
        ])
    }

    func demoWarningsGeoJSON(scenario: String, point: String) async throws -> GeoJSONFeatureCollection {
        try await demoGeoJSON(kind: "warnings", scenario: scenario, point: point)
    }

    func demoHazardsGeoJSON(scenario: String, point: String) async throws -> GeoJSONFeatureCollection {
        try await demoGeoJSON(kind: "hazards", scenario: scenario, point: point)
    }

    func demoConditionsGeoJSON(scenario: String, point: String) async throws -> GeoJSONFeatureCollection {
        try await demoGeoJSON(kind: "conditions", scenario: scenario, point: point)
    }

    private func demoGeoJSON(kind: String, scenario: String, point: String) async throws -> GeoJSONFeatureCollection {
        try await getJSON(path: "/v1/demo/\(kind)", query: [
            "scenario": scenario,
            "point": point,
            "format": "geojson",
        ])
    }

    private func getJSON<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> T {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.unreachable(baseURL: baseURL.absoluteString)
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath.isEmpty ? cleanPath : "/\(basePath)\(cleanPath)"
        if !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw APIError.unreachable(baseURL: baseURL.absoluteString)
        }
        return try await getJSON(url: url)
    }

    private func getJSON<T: Decodable>(url: URL) async throws -> T {
        let path = url.path
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.unreachable(baseURL: baseURL.absoluteString)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unreachable(baseURL: baseURL.absoluteString)
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.http(path: path, status: http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decode(path: path, underlying: error)
        }
    }
}

extension JSONDecoder {
    static var locationPicture: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractional.date(from: raw)
                ?? ISO8601DateFormatter.withoutFractional.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(raw)")
        }
        return decoder
    }
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
