// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

/// Shared service graph wired once at boot.
struct AppServices: Sendable {
    let cache: SourceCache
    let arcgis: ArcGISClient
    let hilltop: HilltopClient
    let hubs: HubsService
    let warnings: WarningsService
    let conditions: ConditionsService
    let hazards: HazardsService
    let picture: PictureService
    let demo: DemoService
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
        let hilltop = HilltopClient(client: client, logger: logger)
        let hubs = HubsService(arcgis: arcgis, cache: cache)
        let warnings = WarningsService(arcgis: arcgis, cache: cache, logger: logger)
        let conditions = ConditionsService(
            hilltop: hilltop,
            arcgis: arcgis,
            cache: cache,
            logger: logger
        )
        let hazards = HazardsService(arcgis: arcgis, cache: cache, logger: logger)
        let picture = PictureService(
            hubs: hubs,
            warnings: warnings,
            conditions: conditions,
            hazards: hazards,
            logger: logger
        )
        let demo = DemoService(hazards: hazards, warnings: warnings)
        services = AppServices(
            cache: cache,
            arcgis: arcgis,
            hilltop: hilltop,
            hubs: hubs,
            warnings: warnings,
            conditions: conditions,
            hazards: hazards,
            picture: picture,
            demo: demo
        )
    }
}

extension Request {
    var services: AppServices { application.services }
}
