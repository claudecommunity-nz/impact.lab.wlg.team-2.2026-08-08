// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

/// Shared service graph wired once at boot.
struct AppServices: Sendable {
    let cache: SourceCache
    let arcgis: ArcGISClient
    let hubs: HubsService
}

enum AppServicesKey: StorageKey {
    typealias Value = AppServices
}

extension Application {
    var services: AppServices {
        get {
            guard let services = storage[AppServicesKey.self] else {
                fatalError("AppServices not configured — call setupServices() in configure(_:)")
            }
            return services
        }
        set { storage[AppServicesKey.self] = newValue }
    }

    func setupServices() {
        let cache = SourceCache()
        let arcgis = ArcGISClient(client: client, logger: logger)
        let hubs = HubsService(arcgis: arcgis, cache: cache)
        services = AppServices(cache: cache, arcgis: arcgis, hubs: hubs)
    }
}

extension Request {
    var services: AppServices { application.services }
}
