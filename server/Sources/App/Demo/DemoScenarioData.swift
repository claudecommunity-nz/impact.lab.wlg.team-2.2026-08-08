// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Curated mock Location Picture scenarios for demo / offline judging.
/// Field names match live `/v1/*` contracts exactly. Not live data.
enum DemoScenarioData {
    // MARK: - Points

    enum PointID: String, CaseIterable, Sendable {
        case lyallBay = "lyall-bay"
        case karori = "karori"

        var name: String {
            switch self {
            case .lyallBay: return "Lyall Bay"
            case .karori: return "Karori"
            }
        }

        var lat: Double {
            switch self {
            case .lyallBay: return -41.3286
            case .karori: return -41.2865
            }
        }

        var lng: Double {
            switch self {
            case .lyallBay: return 174.7947
            case .karori: return 174.7405
            }
        }
    }

    enum ScenarioID: String, CaseIterable, Sendable {
        /// Classic pitch: same storm, different street.
        case southerlyStorm = "southerly-storm"
        /// Honest calm day (mirrors live empty-warnings shape).
        case calmDay = "calm-day"
        /// One section hard-failed — partial picture still 200.
        case degraded = "degraded"

        var title: String {
            switch self {
            case .southerlyStorm: return "Southerly storm"
            case .calmDay: return "Calm day"
            case .degraded: return "Degraded conditions source"
            }
        }

        var description: String {
            switch self {
            case .southerlyStorm:
                return "Same Heavy Rain Warning at both points; Lyall Bay has tsunami + coastal planning layers and a Kilbirnie outage; Karori has elevated stream gauge and different faults."
            case .calmDay:
                return "No official warnings; light gauges; real planning contrast (coastal vs hill) — honesty about empty state."
            case .degraded:
                return "Conditions section unavailable (simulated upstream timeout); warnings and hazards still present."
            }
        }
    }

    // MARK: - Shared source helpers

    private static let now = Date(timeIntervalSince1970: 1_786_147_200) // 2026-08-08T12:00:00Z fixed for stable demos

    private static func source(
        name: String,
        id: String,
        trust: Trust,
        url: String?,
        age: TimeInterval = 45
    ) -> SourceMeta {
        SourceMeta(
            name: name,
            id: id,
            trust: trust,
            fetchedAt: now.addingTimeInterval(-age),
            url: url
        )
    }

    private static let metSource = source(
        name: "MetService (via Eagle CAP feed)",
        id: "metservice-warnings",
        trust: .official,
        url: "https://services.arcgis.com/XTtANUDT8Va4DLwI/arcgis/rest/services/Metservice_Weather_Alerts/FeatureServer/0",
        age: 40
    )

    private static let hilltopSource = source(
        name: "Greater Wellington Hilltop telemetry",
        id: "hilltop",
        trust: .official,
        url: "https://hilltop.gw.govt.nz/Telemetry.hts",
        age: 30
    )

    private static let outageSource = source(
        name: "NEMA national electricity outages",
        id: "electricity-outages",
        trust: .lifeline,
        url: "https://services5.arcgis.com/cJn6oR1QqErYBL5d/arcgis/rest/services/electricity_outages_read_only/FeatureServer/0",
        age: 50
    )

    private static let waterSource = source(
        name: "Wellington Water network faults",
        id: "water-network-faults",
        trust: .lifeline,
        url: "https://services7.arcgis.com/2ECs938g489DMWjt/arcgis/rest/services/Job_Status_Public_View/FeatureServer/5",
        age: 55
    )

    private static let hubsSource = source(
        name: "WREMO Community Emergency Hubs",
        id: "community-emergency-hubs",
        trust: .official,
        url: "https://mapping.gw.govt.nz/arcgis/rest/services/GW/Emergencies_P/MapServer/2",
        age: 120
    )

    private static let tsunamiSource = source(
        name: "WCC Tsunami Evacuation Zones",
        id: "tsunami-evacuation-zones",
        trust: .planning,
        url: "https://gis.wcc.govt.nz/arcgis/rest/services/Environment/TsunamiEvacuationZones/MapServer/1",
        age: 200
    )

    private static let coastalSource = source(
        name: "WCC Proposed District Plan",
        id: "coastal-inundation-medium",
        trust: .planning,
        url: "https://gis.wcc.govt.nz/arcgis/rest/services/DistrictPlanProposed/DistrictPlanProposed/MapServer/39",
        age: 210
    )

    // MARK: - Shared warning (covers both demo points)

    private static func wellingtonHeavyRain() -> Warning {
        Warning(
            id: "demo.2.49.0.0.554.0.severeweather.wellington.southerly",
            event: "rain",
            headline: "Heavy Rain Warning for Wellington",
            severity: "Moderate",
            urgency: "Expected",
            certainty: "Likely",
            areaDesc: "Wellington City and the Tararua Ranges",
            onset: now.addingTimeInterval(-3 * 3600),
            expires: now.addingTimeInterval(12 * 3600),
            description:
                "Periods of heavy rain. Expect 80 to 100 mm in 12 hours about the ranges and south coast, with lesser amounts elsewhere. Surface flooding of roads and low-lying areas is possible.",
            web: "https://metservice.com/warnings/home",
            source: metSource
        )
    }

    // MARK: - Hubs

    private static func lyallHub() -> NearestHub {
        NearestHub(
            hub: Hub(
                id: 87,
                name: "Lyall Bay Community Centre",
                type: "Community Emergency Hub",
                address: "36 Freyberg Street",
                suburb: "Lyall Bay",
                town: "Wellington",
                taName: "Wellington City",
                lat: -41.3271,
                lng: 174.7960,
                source: hubsSource
            ),
            distanceKm: 0.2
        )
    }

    private static func karoriHub() -> NearestHub {
        NearestHub(
            hub: Hub(
                id: 88,
                name: "Karori - Karori Community Centre",
                type: "Community Emergency Hub",
                address: "7 Beauchamp Street",
                suburb: "Karori",
                town: "Wellington",
                taName: "Wellington City",
                lat: -41.2852,
                lng: 174.7383,
                source: hubsSource
            ),
            distanceKm: 0.2
        )
    }

    // MARK: - Hazards

    private static func lyallHazards() -> HazardsEnvelope {
        HazardsEnvelope(
            status: "ok",
            note: HazardsService.planningNote,
            items: [
                HazardItem(
                    layer: "Tsunami Evacuation Zones",
                    id: "tsunami-evacuation-zones",
                    value: "Orange Zone",
                    detail: "Zone_Class 2 — Wellington City and south coast — upto 5.0 m wave height",
                    publisher: "Wellington City Council",
                    source: tsunamiSource
                ),
                HazardItem(
                    layer: "Coastal Inundation (Medium)",
                    id: "coastal-inundation-medium",
                    value: "inside",
                    detail: nil,
                    publisher: "Wellington City Council / NIWA (2021)",
                    source: coastalSource
                ),
            ]
        )
    }

    private static func karoriHazards() -> HazardsEnvelope {
        HazardsEnvelope(
            status: "ok",
            note: HazardsService.planningNote,
            items: []
        )
    }

    // MARK: - Conditions builders

    private static func lyallStormConditions() -> LocalConditionsSection {
        .ok(
            ConditionsEnvelope(
                gauges: [
                    GaugeReading(
                        site: "Newtown at Carmichael Reservoir",
                        lat: -41.3159,
                        lng: 174.7879,
                        distanceKm: 1.5,
                        measurement: "Rainfall",
                        value: 12.4,
                        units: "mm",
                        observedAt: now.addingTimeInterval(-600),
                        trend: "rising",
                        source: hilltopSource
                    ),
                    GaugeReading(
                        site: "Berhampore at Nursery",
                        lat: -41.3232,
                        lng: 174.7716,
                        distanceKm: 2.0,
                        measurement: "Rainfall",
                        value: 9.8,
                        units: "mm",
                        observedAt: now.addingTimeInterval(-720),
                        trend: "rising",
                        source: hilltopSource
                    ),
                ],
                electricityOutages: [
                    ElectricityOutage(
                        locationName: "Kilbirnie",
                        distanceKm: 1.4,
                        numAffected: 120,
                        status: "Current",
                        outageType: "Unplanned",
                        distributor: "Wellington Electricity",
                        startedAt: now.addingTimeInterval(-5400),
                        link: "/outages/unplannedoutage/demo-kilbirnie",
                        lat: -41.3190,
                        lng: 174.7965,
                        source: outageSource
                    ),
                ],
                waterFaults: [
                    WaterFault(
                        description: "No water — burst main",
                        address: "Onepu Road, Lyall Bay",
                        distanceKm: 0.6,
                        status: "In Progress",
                        priority: "High",
                        reportedAt: now.addingTimeInterval(-7200),
                        lat: -41.3275,
                        lng: 174.7910,
                        source: waterSource
                    ),
                    WaterFault(
                        description: "Fault 79 APU CRESCENT, Lyall Bay",
                        address: "79 Apu Crescent, Lyall Bay, Wellington, 6022",
                        distanceKm: 0.4,
                        status: "New",
                        priority: "Medium",
                        reportedAt: now.addingTimeInterval(-3600),
                        lat: -41.3271,
                        lng: 174.7986,
                        source: waterSource
                    ),
                ]
            )
        )
    }

    private static func karoriStormConditions() -> LocalConditionsSection {
        .ok(
            ConditionsEnvelope(
                gauges: [
                    GaugeReading(
                        site: "Karori Stream at Samuel Marsden School",
                        lat: -41.2844,
                        lng: 174.7452,
                        distanceKm: 0.5,
                        measurement: "Stage",
                        value: 24613,
                        units: "mm",
                        observedAt: now.addingTimeInterval(-480),
                        trend: "rising",
                        source: hilltopSource
                    ),
                    GaugeReading(
                        site: "Kaiwharawhara Stream at Karori Reservoir",
                        lat: -41.2909,
                        lng: 174.7532,
                        distanceKm: 1.2,
                        measurement: "Rainfall",
                        value: 6.2,
                        units: "mm",
                        observedAt: now.addingTimeInterval(-900),
                        trend: "steady",
                        source: hilltopSource
                    ),
                ],
                electricityOutages: [],
                waterFaults: [
                    WaterFault(
                        description: "Fault 32 BEAUCHAMP STREET, Karori",
                        address: "32 Beauchamp Street, Karori, Wellington, 6012",
                        distanceKm: 0.2,
                        status: "In Progress",
                        priority: "Medium",
                        reportedAt: now.addingTimeInterval(-86400),
                        lat: -41.2873,
                        lng: 174.7380,
                        source: waterSource
                    ),
                ]
            )
        )
    }

    private static func lyallCalmConditions() -> LocalConditionsSection {
        .ok(
            ConditionsEnvelope(
                gauges: [
                    GaugeReading(
                        site: "Newtown at Carmichael Reservoir",
                        lat: -41.3159,
                        lng: 174.7879,
                        distanceKm: 1.5,
                        measurement: "Rainfall",
                        value: 0.2,
                        units: "mm",
                        observedAt: now.addingTimeInterval(-900),
                        trend: "steady",
                        source: hilltopSource
                    ),
                ],
                electricityOutages: [
                    ElectricityOutage(
                        locationName: "Wellington Central",
                        distanceKm: 4.8,
                        numAffected: 15,
                        status: "Current",
                        outageType: "Unplanned",
                        distributor: "Wellington Electricity",
                        startedAt: now.addingTimeInterval(-16 * 3600),
                        link: "/outages/unplannedoutage/2758290",
                        lat: -41.2877,
                        lng: 174.7772,
                        source: outageSource
                    ),
                ],
                waterFaults: [
                    WaterFault(
                        description: "Fault 18 PURU CRESCENT, Lyall Bay",
                        address: "18 Puru Crescent, Lyall Bay, Wellington, 6022",
                        distanceKm: 0.4,
                        status: "Under Investigation",
                        priority: "Medium",
                        reportedAt: now.addingTimeInterval(-30 * 86400),
                        lat: -41.3255,
                        lng: 174.7961,
                        source: waterSource
                    ),
                ]
            )
        )
    }

    private static func karoriCalmConditions() -> LocalConditionsSection {
        .ok(
            ConditionsEnvelope(
                gauges: [
                    GaugeReading(
                        site: "Karori Stream at Samuel Marsden School",
                        lat: -41.2844,
                        lng: 174.7452,
                        distanceKm: 0.5,
                        measurement: "Rainfall",
                        value: 0,
                        units: "mm",
                        observedAt: now.addingTimeInterval(-600),
                        trend: "steady",
                        source: hilltopSource
                    ),
                ],
                electricityOutages: [
                    ElectricityOutage(
                        locationName: "Wellington Central",
                        distanceKm: 3.1,
                        numAffected: 15,
                        status: "Current",
                        outageType: "Unplanned",
                        distributor: "Wellington Electricity",
                        startedAt: now.addingTimeInterval(-16 * 3600),
                        link: "/outages/unplannedoutage/2758290",
                        lat: -41.2877,
                        lng: 174.7772,
                        source: outageSource
                    ),
                ],
                waterFaults: [
                    WaterFault(
                        description: "Fault 21A CAMPBELL STREET, Karori",
                        address: "21A Campbell Street, Karori, Wellington, 6012",
                        distanceKm: 0.1,
                        status: "Under Investigation",
                        priority: "Medium",
                        reportedAt: now.addingTimeInterval(-90 * 86400),
                        lat: -41.2856,
                        lng: 174.7402,
                        source: waterSource
                    ),
                ]
            )
        )
    }

    // MARK: - Assemble picture

    static func picture(scenario: ScenarioID, point: PointID) -> LocationPicture {
        let nearest: NearestHub
        let hazards: HazardsEnvelope
        let conditions: LocalConditionsSection
        let warnings: OfficialWarningsSection

        switch point {
        case .lyallBay:
            nearest = lyallHub()
            hazards = lyallHazards()
        case .karori:
            nearest = karoriHub()
            hazards = karoriHazards()
        }

        switch scenario {
        case .southerlyStorm:
            warnings = .ok([wellingtonHeavyRain()])
            conditions = point == .lyallBay ? lyallStormConditions() : karoriStormConditions()
        case .calmDay:
            warnings = .ok([])
            conditions = point == .lyallBay ? lyallCalmConditions() : karoriCalmConditions()
        case .degraded:
            warnings = .ok([wellingtonHeavyRain()])
            conditions = .unavailable("hilltop.gw.govt.nz timed out (demo)")
        }

        let summary = SummaryBuilder.build(
            warnings: warnings,
            conditions: conditions,
            hazards: hazards,
            nearestHub: nearest
        )

        return LocationPicture(
            location: PictureLocation(
                lat: point.lat,
                lng: point.lng,
                nearestHub: nearest
            ),
            officialWarnings: warnings,
            localConditions: conditions,
            hazardContext: hazards,
            summary: summary,
            generatedAt: now,
            sources: sources(for: warnings, conditions: conditions, hazards: hazards, hub: nearest),
            disclaimer: LocationPicture.disclaimerText
        )
    }

    private static func sources(
        for warnings: OfficialWarningsSection,
        conditions: LocalConditionsSection,
        hazards: HazardsEnvelope,
        hub: NearestHub
    ) -> [SourceStatusEntry] {
        var rows: [SourceStatusEntry] = []

        if warnings.status == "ok" {
            if let first = warnings.items.first {
                rows.append(.init(id: first.source.id, fetchedAt: first.source.fetchedAt, status: "ok"))
            } else {
                rows.append(.init(id: "metservice-warnings", fetchedAt: metSource.fetchedAt, status: "ok"))
                rows.append(.init(id: "nema-cap-alerts", fetchedAt: metSource.fetchedAt, status: "ok"))
            }
        } else {
            rows.append(.init(id: "metservice-warnings", fetchedAt: nil, status: "unavailable"))
        }

        if conditions.status == "ok" {
            rows.append(.init(id: "hilltop", fetchedAt: hilltopSource.fetchedAt, status: "ok"))
            rows.append(.init(id: "electricity-outages", fetchedAt: outageSource.fetchedAt, status: "ok"))
            rows.append(.init(id: "water-network-faults", fetchedAt: waterSource.fetchedAt, status: "ok"))
        } else {
            rows.append(.init(id: "hilltop", fetchedAt: nil, status: "unavailable"))
            rows.append(.init(id: "electricity-outages", fetchedAt: nil, status: "unavailable"))
            rows.append(.init(id: "water-network-faults", fetchedAt: nil, status: "unavailable"))
        }

        for h in hazards.items {
            rows.append(.init(id: h.source.id, fetchedAt: h.source.fetchedAt, status: "ok"))
        }
        rows.append(.init(id: hub.source.id, fetchedAt: hub.source.fetchedAt, status: "ok"))

        var seen = Set<String>()
        return rows.filter { seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }

    static func catalog() -> DemoCatalog {
        let points = PointID.allCases.map {
            DemoPointInfo(id: $0.rawValue, name: $0.name, lat: $0.lat, lng: $0.lng)
        }
        let scenarios = ScenarioID.allCases.map {
            DemoScenarioInfo(
                id: $0.rawValue,
                title: $0.title,
                description: $0.description,
                points: points
            )
        }
        return DemoCatalog(
            note: "Curated mock data for demos — not live feeds. Live API remains under /v1/* without /demo.",
            scenarios: scenarios
        )
    }
}
