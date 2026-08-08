// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Vapor

// MARK: - Wire models

struct OutageRawAttributes: Decodable, Sendable {
    let locationname: String?
    let numaffected: Int?
    let status: String?
    let outagetype: String?
    let distributor: String?
    let startdate: Date?
    let enddate: Date?
    let details: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case locationname, numaffected, status, outagetype, distributor
        case startdate, enddate, details, link
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        locationname = try c.decodeIfPresent(String.self, forKey: .locationname)
        numaffected = try c.decodeIfPresent(Int.self, forKey: .numaffected)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        outagetype = try c.decodeIfPresent(String.self, forKey: .outagetype)
        distributor = try c.decodeIfPresent(String.self, forKey: .distributor)
        details = try c.decodeIfPresent(String.self, forKey: .details)
        link = try c.decodeIfPresent(String.self, forKey: .link)
        startdate = ArcGISDate.decode(from: c, forKey: .startdate)
        enddate = ArcGISDate.decode(from: c, forKey: .enddate)
    }
}

struct WaterFaultRawAttributes: Decodable, Sendable {
    let wonum: String?
    let description: String?
    let status: String?
    let StatusDescription: String?
    let priority: String?
    let reportdate: Date?
    let wsadd_formattedaddress: String?
    let wtypedesc: String?
    let watertype: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case wonum, description, status, StatusDescription, priority
        case reportdate, wsadd_formattedaddress, wtypedesc, watertype, location
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .wonum) {
            wonum = s
        } else if let i = try? c.decode(Int.self, forKey: .wonum) {
            wonum = String(i)
        } else {
            wonum = nil
        }
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        StatusDescription = try c.decodeIfPresent(String.self, forKey: .StatusDescription)
        // priority may be String or number
        if let s = try? c.decodeIfPresent(String.self, forKey: .priority) {
            priority = s
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .priority) {
            priority = String(i)
        } else {
            priority = nil
        }
        reportdate = ArcGISDate.decode(from: c, forKey: .reportdate)
        wsadd_formattedaddress = try c.decodeIfPresent(String.self, forKey: .wsadd_formattedaddress)
        wtypedesc = try c.decodeIfPresent(String.self, forKey: .wtypedesc)
        watertype = try c.decodeIfPresent(String.self, forKey: .watertype)
        location = try c.decodeIfPresent(String.self, forKey: .location)
    }
}

// MARK: - Service

/// Live local conditions: Hilltop gauges + electricity outages + water faults.
actor ConditionsService {
    static let hilltopId = "hilltop"
    static let outagesId = "electricity-outages"
    static let waterId = "water-network-faults"
    static let outagesURL =
        "https://services5.arcgis.com/cJn6oR1QqErYBL5d/arcgis/rest/services/electricity_outages_read_only/FeatureServer/0"
    static let waterURL =
        "https://services7.arcgis.com/2ECs938g489DMWjt/arcgis/rest/services/Job_Status_Public_View/FeatureServer/5"

    static let conditionsTTL: TimeInterval = 120
    static let sitesTTL: TimeInterval = 3600
    /// Prefer Stage; fall back for sites that only publish Flow/Rainfall.
    static let measurementOrder = ["Stage", "Flow", "Rainfall"]
    static let maxReadingAge: TimeInterval = 6 * 3600

    /// Wellington region envelope for national feeds.
    static let wellingtonEnvelope = "174.5,-41.6,175.6,-40.5"

    private let hilltop: HilltopClient
    private let arcgis: ArcGISClient
    private let cache: SourceCache
    private let logger: Logger

    init(hilltop: HilltopClient, arcgis: ArcGISClient, cache: SourceCache, logger: Logger) {
        self.hilltop = hilltop
        self.arcgis = arcgis
        self.cache = cache
        self.logger = logger
    }

    func conditions(
        at point: GeoMath.Coordinate,
        n: Int = 5,
        radiusKm: Double = 10
    ) async throws -> ConditionsEnvelope {
        // Fan out independent source groups carefully: Hilltop is sequential
        // internally; ArcGIS layers are separate hosts.
        async let gaugesTask = fetchGauges(at: point, n: n, radiusKm: radiusKm)
        async let outagesTask = fetchOutages(at: point, radiusKm: radiusKm)
        async let waterTask = fetchWaterFaults(at: point, radiusKm: radiusKm)

        let gauges = await gaugesTask
        let outages = await outagesTask
        let water = await waterTask
        return ConditionsEnvelope(
            gauges: gauges,
            electricityOutages: outages,
            waterFaults: water
        )
    }

    // MARK: - Gauges

    private func fetchGauges(
        at point: GeoMath.Coordinate,
        n: Int,
        radiusKm: Double
    ) async -> [GaugeReading] {
        do {
            let sites = try await loadSites()
            let origin = GeoMath.Coordinate(lat: point.lat, lng: point.lng)

            let ranked: [(HilltopClient.Site, Double)] = sites.compactMap { site in
                let d = GeoMath.haversineKm(
                    from: origin,
                    to: .init(lat: site.lat, lng: site.lng)
                )
                guard d <= radiusKm else { return nil }
                return (site, d)
            }
            .sorted { $0.1 < $1.1 }

            // Over-fetch candidates so sites without Stage still leave room for n hits.
            let candidates = Array(ranked.prefix(max(n * 3, 12)))
            var results: [GaugeReading] = []
            let sourceTemplate = SourceMeta(
                name: "Greater Wellington Hilltop telemetry",
                id: Self.hilltopId,
                trust: .official,
                fetchedAt: Date(),
                url: HilltopClient.baseURL
            )

            for (site, distanceKm) in candidates {
                if results.count >= n { break }
                if let reading = await reading(for: site, distanceKm: distanceKm, source: sourceTemplate) {
                    results.append(reading)
                }
            }
            return results
        } catch {
            logger.warning("Hilltop gauges failed: \(error)")
            return []
        }
    }

    private func loadSites() async throws -> [HilltopClient.Site] {
        if let cached = await cache.getFresh("hilltop-sites", as: [HilltopClient.Site].self) {
            return cached.value
        }
        let sites = try await hilltop.siteList()
        await cache.set("hilltop-sites", value: sites, ttl: Self.sitesTTL)
        return sites
    }

    private struct GaugeSample: Sendable {
        let measurement: String
        let value: Double
        let units: String
        let observedAt: Date
        let trend: String?
        let fetchedAt: Date
    }

    private func reading(
        for site: HilltopClient.Site,
        distanceKm: Double,
        source: SourceMeta
    ) async -> GaugeReading? {
        let cacheKey = "hilltop-data:\(site.name)"
        if let cached = await cache.getFresh(cacheKey, as: GaugeSample?.self) {
            guard let sample = cached.value else { return nil }
            return makeGauge(site: site, distanceKm: distanceKm, sample: sample, source: source)
        }

        for measurement in Self.measurementOrder {
            do {
                let series = try await hilltop.getData(
                    site: site.name,
                    measurement: measurement,
                    interval: "PT6H"
                )
                guard let last = series.last else { continue }
                let age = Date().timeIntervalSince(last.time)
                guard age <= Self.maxReadingAge else { continue }

                let fetchedAt = Date()
                let sample = GaugeSample(
                    measurement: last.measurement,
                    value: last.value,
                    units: last.units,
                    observedAt: last.time,
                    trend: Self.trend(from: series),
                    fetchedAt: fetchedAt
                )
                await cache.set(cacheKey, value: Optional(sample), ttl: Self.conditionsTTL, fetchedAt: fetchedAt)
                return makeGauge(site: site, distanceKm: distanceKm, sample: sample, source: source)
            } catch {
                logger.debug("Hilltop \(site.name) \(measurement): \(error)")
                continue
            }
        }
        await cache.set(cacheKey, value: GaugeSample?.none, ttl: 60)
        return nil
    }

    private func makeGauge(
        site: HilltopClient.Site,
        distanceKm: Double,
        sample: GaugeSample,
        source: SourceMeta
    ) -> GaugeReading {
        let meta = SourceMeta(
            name: source.name,
            id: source.id,
            trust: source.trust,
            fetchedAt: sample.fetchedAt,
            url: source.url
        )
        return GaugeReading(
            site: site.name,
            lat: site.lat,
            lng: site.lng,
            distanceKm: (distanceKm * 10).rounded() / 10,
            measurement: sample.measurement,
            value: sample.value,
            units: sample.units,
            observedAt: sample.observedAt,
            trend: sample.trend,
            source: meta
        )
    }

    private static func trend(from series: [HilltopClient.Reading]) -> String? {
        guard series.count >= 2 else { return nil }
        let a = series[series.count - 2].value
        let b = series[series.count - 1].value
        let delta = b - a
        // Stage is mm — ignore sub-mm noise.
        if abs(delta) < 0.5 { return "steady" }
        return delta > 0 ? "rising" : "falling"
    }

    // MARK: - Outages

    private func fetchOutages(at point: GeoMath.Coordinate, radiusKm: Double) async -> [ElectricityOutage] {
        do {
            if let cached = await cache.getFresh("outages-wellington", as: [ElectricityOutage].self) {
                return filterOutages(cached.value, at: point, radiusKm: radiusKm)
            }

            let (features, fetchedAt): ([ArcGISFeature<OutageRawAttributes>], Date) =
                try await arcgis.query(
                    layerURL: Self.outagesURL,
                    geometry: Self.wellingtonEnvelope,
                    geometryType: "esriGeometryEnvelope",
                    inSR: "4326",
                    spatialRel: "esriSpatialRelIntersects"
                )

            let source = SourceMeta(
                name: "NEMA national electricity outages",
                id: Self.outagesId,
                trust: .lifeline,
                fetchedAt: fetchedAt,
                url: Self.outagesURL
            )

            let origin = GeoMath.Coordinate(lat: point.lat, lng: point.lng)
            let all: [ElectricityOutage] = features.compactMap { feature in
                let lat = feature.geometry?.y
                let lng = feature.geometry?.x
                let distance: Double
                if let lat, let lng {
                    distance = GeoMath.haversineKm(from: origin, to: .init(lat: lat, lng: lng))
                } else {
                    distance = .infinity
                }
                let raw = feature.attributes
                return ElectricityOutage(
                    locationName: raw.locationname,
                    distanceKm: distance.isFinite ? (distance * 10).rounded() / 10 : -1,
                    numAffected: raw.numaffected,
                    status: raw.status,
                    outageType: raw.outagetype,
                    distributor: raw.distributor,
                    startedAt: raw.startdate,
                    link: raw.link,
                    lat: lat,
                    lng: lng,
                    source: source
                )
            }

            await cache.set("outages-wellington", value: all, ttl: Self.conditionsTTL, fetchedAt: fetchedAt)
            return filterOutages(all, at: point, radiusKm: radiusKm)
        } catch {
            logger.warning("Electricity outages failed: \(error)")
            return []
        }
    }

    private func filterOutages(
        _ all: [ElectricityOutage],
        at point: GeoMath.Coordinate,
        radiusKm: Double
    ) -> [ElectricityOutage] {
        let origin = GeoMath.Coordinate(lat: point.lat, lng: point.lng)
        return all.compactMap { o -> ElectricityOutage? in
            guard let lat = o.lat, let lng = o.lng else { return nil }
            let d = GeoMath.haversineKm(from: origin, to: .init(lat: lat, lng: lng))
            guard d <= radiusKm else { return nil }
            return ElectricityOutage(
                locationName: o.locationName,
                distanceKm: (d * 10).rounded() / 10,
                numAffected: o.numAffected,
                status: o.status,
                outageType: o.outageType,
                distributor: o.distributor,
                startedAt: o.startedAt,
                link: o.link,
                lat: o.lat,
                lng: o.lng,
                source: o.source
            )
        }
        .sorted { $0.distanceKm < $1.distanceKm }
    }

    // MARK: - Water faults

    private func fetchWaterFaults(at point: GeoMath.Coordinate, radiusKm: Double) async -> [WaterFault] {
        do {
            if let cached = await cache.getFresh("water-faults-wellington", as: [WaterFault].self) {
                return filterWater(cached.value, at: point, radiusKm: radiusKm)
            }

            let (features, fetchedAt): ([ArcGISFeature<WaterFaultRawAttributes>], Date) =
                try await arcgis.query(
                    layerURL: Self.waterURL,
                    geometry: Self.wellingtonEnvelope,
                    geometryType: "esriGeometryEnvelope",
                    inSR: "4326",
                    spatialRel: "esriSpatialRelIntersects"
                )

            let source = SourceMeta(
                name: "Wellington Water network faults",
                id: Self.waterId,
                trust: .lifeline,
                fetchedAt: fetchedAt,
                url: Self.waterURL
            )

            let origin = GeoMath.Coordinate(lat: point.lat, lng: point.lng)
            let all: [WaterFault] = features.compactMap { feature in
                let raw = feature.attributes
                // Drop completed/closed jobs client-side.
                let status = (raw.status ?? "").uppercased()
                if status.contains("COMP") || status.contains("CLOSED") || status.contains("CLOSE") {
                    return nil
                }
                let lat = feature.geometry?.y
                let lng = feature.geometry?.x
                let distance: Double
                if let lat, let lng {
                    distance = GeoMath.haversineKm(from: origin, to: .init(lat: lat, lng: lng))
                } else {
                    distance = .infinity
                }
                return WaterFault(
                    description: raw.description,
                    address: raw.wsadd_formattedaddress,
                    distanceKm: distance.isFinite ? (distance * 10).rounded() / 10 : -1,
                    status: raw.StatusDescription ?? raw.status,
                    priority: raw.priority,
                    reportedAt: raw.reportdate,
                    lat: lat,
                    lng: lng,
                    source: source
                )
            }

            await cache.set("water-faults-wellington", value: all, ttl: Self.conditionsTTL, fetchedAt: fetchedAt)
            return filterWater(all, at: point, radiusKm: radiusKm)
        } catch {
            logger.warning("Water faults failed: \(error)")
            return []
        }
    }

    private func filterWater(
        _ all: [WaterFault],
        at point: GeoMath.Coordinate,
        radiusKm: Double
    ) -> [WaterFault] {
        let origin = GeoMath.Coordinate(lat: point.lat, lng: point.lng)
        return all.compactMap { f -> WaterFault? in
            guard let lat = f.lat, let lng = f.lng else { return nil }
            let d = GeoMath.haversineKm(from: origin, to: .init(lat: lat, lng: lng))
            guard d <= radiusKm else { return nil }
            return WaterFault(
                description: f.description,
                address: f.address,
                distanceKm: (d * 10).rounded() / 10,
                status: f.status,
                priority: f.priority,
                reportedAt: f.reportedAt,
                lat: f.lat,
                lng: f.lng,
                source: f.source
            )
        }
        .sorted { $0.distanceKm < $1.distanceKm }
    }
}
