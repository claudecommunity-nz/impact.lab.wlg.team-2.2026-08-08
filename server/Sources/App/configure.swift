// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

/// Application start time for `/healthz` uptime reporting.
enum AppStart {
    static let date = Date()
}

public func configure(_ app: Application) async throws {
    // Bind all interfaces by default (localhost + LAN/Wi‑Fi) so phones and
    // teammates on the same network can hit the API. Override with HOST=…
    // (e.g. HOST=127.0.0.1 for loopback-only). Port defaults to 8080;
    // PORT=… if busy (e.g. another App or Xcode instance already listening).
    let hostname = Environment.get("HOST") ?? "0.0.0.0"
    let port = Environment.get("PORT").flatMap(Int.init) ?? 8080
    app.http.server.configuration.hostname = hostname
    app.http.server.configuration.port = port
    app.logger.info(
        "Binding http://\(hostname):\(port) (all interfaces if 0.0.0.0; set HOST=/PORT= to override)"
    )
    if hostname == "0.0.0.0" {
        app.logger.info("Local:   http://127.0.0.1:\(port)")
        for ip in lanIPv4Addresses() {
            app.logger.info("Network: http://\(ip):\(port)")
        }
    }

    // Replace the default stack so unknown routes never return HTML.
    app.middleware = .init()

    // CORS wide-open for the MapLibre frontend workstream.
    let cors = CORSMiddleware(
        configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, .OPTIONS, .HEAD],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        )
    )
    app.middleware.use(cors)
    app.middleware.use(JSONErrorMiddleware())

    // ISO-8601 timestamps with fractional seconds optional — contract uses Zulu.
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    app.setupServices()

    try routes(app)
}

/// Non-loopback IPv4 addresses currently assigned (Wi‑Fi / Ethernet).
private func lanIPv4Addresses() -> [String] {
    var addresses: [String] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
    defer { freeifaddrs(ifaddr) }

    var ptr: UnsafeMutablePointer<ifaddrs>? = first
    while let iface = ptr {
        defer { ptr = iface.pointee.ifa_next }
        let flags = Int32(iface.pointee.ifa_flags)
        guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
        guard let addr = iface.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else {
            continue
        }
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            addr,
            socklen_t(addr.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        if result == 0 {
            let end = hostname.firstIndex(of: 0) ?? hostname.endIndex
            let ip = String(decoding: hostname[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if !ip.isEmpty, !addresses.contains(ip) {
                addresses.append(ip)
            }
        }
    }
    return addresses
}
