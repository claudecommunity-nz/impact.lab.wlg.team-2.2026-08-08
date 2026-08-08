// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

/// Greater Wellington Hilltop telemetry (XML).
/// Spaces in query values **must** be `%20`, never `+`.
actor HilltopClient {
    static let baseURL = "https://hilltop.gw.govt.nz/Telemetry.hts"

    struct Site: Sendable, Equatable {
        let name: String
        let lat: Double
        let lng: Double
    }

    struct Reading: Sendable, Equatable {
        let time: Date
        let value: Double
        let units: String
        let measurement: String
    }

    private let client: Client
    private let logger: Logger
    private var lastRequest: ContinuousClock.Instant?
    private let minInterval: Duration

    init(client: Client, logger: Logger, minInterval: Duration = .milliseconds(150)) {
        self.client = client
        self.logger = logger
        self.minInterval = minInterval
    }

    /// All gauges with WGS84 coordinates (`location=LatLong`).
    func siteList() async throws -> [Site] {
        let data = try await get(params: [
            "service": "Hilltop",
            "request": "SiteList",
            "location": "LatLong",
        ])
        let root = try parseXML(data)
        try throwIfError(root)

        var sites: [Site] = []
        for node in root.nodes(named: "Site") {
            guard let name = node.attribute(forName: "Name")?.stringValue, !name.isEmpty else {
                continue
            }
            guard
                let latStr = node.firstChild(named: "Latitude")?.stringValue,
                let lngStr = node.firstChild(named: "Longitude")?.stringValue,
                let lat = Double(latStr),
                let lng = Double(lngStr)
            else { continue }
            sites.append(Site(name: name, lat: lat, lng: lng))
        }
        return sites
    }

    /// Observations oldest→newest. `interval` is ISO-8601 duration (e.g. `PT6H`) —
    /// Hilltop treats it as “last N records”, not strictly last N hours; check ages.
    func getData(
        site: String,
        measurement: String = "Stage",
        interval: String = "PT6H"
    ) async throws -> [Reading] {
        let data = try await get(params: [
            "service": "Hilltop",
            "request": "GetData",
            "Site": site,
            "Measurement": measurement,
            "TimeInterval": interval,
        ])
        let root = try parseXML(data)
        try throwIfError(root)

        let (itemNumber, units) = itemInfo(in: root, measurement: measurement)
        let tag = "I\(itemNumber)"
        var readings: [Reading] = []

        for entry in root.nodes(named: "E") {
            guard
                let t = entry.firstChild(named: "T")?.stringValue,
                let raw = entry.firstChild(named: tag)?.stringValue,
                let value = Double(raw),
                let time = Self.parseHilltopTime(t)
            else { continue }
            readings.append(
                Reading(
                    time: time,
                    value: value,
                    units: units ?? "",
                    measurement: measurement
                )
            )
        }
        return readings
    }

    // MARK: - HTTP (percent-encode with %20, never +)

    private func get(params: [String: String]) async throws -> Data {
        try await throttle()
        let query = params
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
        let urlString = "\(Self.baseURL)?\(query)"
        logger.debug("Hilltop GET \(urlString)")

        let response = try await client.get(URI(string: urlString))
        guard response.status == .ok else {
            throw Abort(
                .badGateway,
                reason: "Hilltop HTTP \(response.status.code)"
            )
        }
        return Data(buffer: response.body ?? .init())
    }

    /// Encode like Python `urllib.parse.quote(s, safe='')` — spaces become `%20`.
    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func throttle() async throws {
        let now = ContinuousClock.now
        if let last = lastRequest {
            let elapsed = now - last
            if elapsed < minInterval {
                try await Task.sleep(for: minInterval - elapsed)
            }
        }
        lastRequest = ContinuousClock.now
    }

    // MARK: - XML helpers

    private func parseXML(_ data: Data) throws -> XMLElement {
        // Portability: XMLDocument is the second Apple-leaning call site.
        // On Linux use FoundationXML (libxml2) or fall back to XMLParser (see README).
        let doc = try XMLDocument(data: data, options: [.documentTidyXML])
        guard let root = doc.rootElement() else {
            throw Abort(.badGateway, reason: "Hilltop returned empty XML")
        }
        if root.name?.lowercased() == "html" {
            throw Abort(.badGateway, reason: "Hilltop returned HTML, not data")
        }
        return root
    }

    private func throwIfError(_ root: XMLElement) throws {
        if root.name == "Error" {
            throw Abort(
                .badGateway,
                reason: "Hilltop: \((root.stringValue ?? "unknown").trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }
        if let err = root.firstChild(named: "Error")?.stringValue
            ?? root.nodes(named: "Error").first?.stringValue
        {
            let msg = err.trimmingCharacters(in: .whitespacesAndNewlines)
            if !msg.isEmpty {
                throw Abort(.badGateway, reason: "Hilltop: \(msg)")
            }
        }
    }

    /// Match ItemInfo by measurement name (not position).
    private func itemInfo(in root: XMLElement, measurement: String) -> (Int, String?) {
        let wanted = measurement.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = root.nodes(named: "ItemInfo")
        for item in items {
            let name = (item.firstChild(named: "ItemName")?.stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if name == wanted {
                let number = Int(item.attribute(forName: "ItemNumber")?.stringValue ?? "1") ?? 1
                let units = item.firstChild(named: "Units")?.stringValue
                return (number, units)
            }
        }
        // Fallback: first Units in document + I1
        let units = root.nodes(named: "Units").first?.stringValue
        return (1, units)
    }

    /// Hilltop timestamps are NZ local without offset (`2026-08-08T10:40:00`).
    static func parseHilltopTime(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let tz = TimeZone(identifier: "Pacific/Auckland") ?? .current

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = tz
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: trimmed) { return d }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let d = df.date(from: trimmed) { return d }

        // Already has offset
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: trimmed)
    }
}

// MARK: - XMLElement walk helpers

private extension XMLElement {
    func nodes(named name: String) -> [XMLElement] {
        var result: [XMLElement] = []
        collect(name: name, into: &result)
        return result
    }

    private func collect(name: String, into result: inout [XMLElement]) {
        if self.name == name {
            result.append(self)
        }
        for child in children ?? [] {
            if let el = child as? XMLElement {
                el.collect(name: name, into: &result)
            }
        }
    }

    func firstChild(named name: String) -> XMLElement? {
        children?.compactMap { $0 as? XMLElement }.first { $0.name == name }
    }
}
