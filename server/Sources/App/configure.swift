// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

/// Application start time for `/healthz` uptime reporting.
enum AppStart {
    static let date = Date()
}

public func configure(_ app: Application) async throws {
    // Bind explicitly so demo curls hit a known port.
    app.http.server.configuration.hostname = "127.0.0.1"
    app.http.server.configuration.port = 8080

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
