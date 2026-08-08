// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreLocation
import Observation

enum AppMode: String, CaseIterable, Identifiable {
    case demo
    case live

    var id: String { rawValue }
    var label: String {
        switch self {
        case .demo: return "Demo"
        case .live: return "Live"
        }
    }
}

enum LoadState: Equatable {
    case idle
    case loading
    case ok
    case error(String)
}

@MainActor
@Observable
final class PictureStore {
    var mode: AppMode = .demo
    var baseURLString: String =
        UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8080"

    var catalog: DemoCatalog?
    var scenarioId: String?
    var pointId: String?

    var picture: LocationPicture?
    var loadState: LoadState = .idle
    var serverOK: Bool?

    var mapPins: [MapPin] = []
    var mapPolygons: [OverlayPolygon] = []
    var mapCenter: LatLng = .lyallBay

    var livePreset: LivePreset = .lyallBay
    var customLat: String = String(LatLng.lyallBay.lat)
    var customLng: String = String(LatLng.lyallBay.lng)

    private let client = APIClient()
    private var refreshTask: Task<Void, Never>?

    enum LivePreset: String, CaseIterable, Identifiable {
        case lyallBay, karori, wellingtonCBD, custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lyallBay: return "Lyall Bay"
            case .karori: return "Karori"
            case .wellingtonCBD: return "Wellington CBD"
            case .custom: return "Custom lat/lng"
            }
        }

        var latLng: LatLng? {
            switch self {
            case .lyallBay: return .lyallBay
            case .karori: return .karori
            case .wellingtonCBD: return .wellingtonCBD
            case .custom: return nil
            }
        }
    }

    var selectedScenario: DemoScenarioInfo? {
        catalog?.scenarios.first { $0.id == scenarioId }
    }

    var selectedPoint: DemoPointInfo? {
        selectedScenario?.points.first { $0.id == pointId }
    }

    func onAppear() {
        applyBaseURL()
        Task { await bootstrap() }
    }

    func applyBaseURL() {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: "apiBaseURL")
        Task { await client.setBaseURL(url) }
    }

    func bootstrap() async {
        applyBaseURL()
        await pingServer()
        await loadCatalogIfNeeded()
        await refresh()
    }

    func pingServer() async {
        do {
            _ = try await client.healthz()
            serverOK = true
        } catch {
            serverOK = false
        }
    }

    func loadCatalogIfNeeded() async {
        guard catalog == nil else { return }
        do {
            let cat = try await client.demoScenarios()
            catalog = cat
            if scenarioId == nil, let first = cat.scenarios.first {
                scenarioId = first.id
                pointId = first.points.first?.id
            }
        } catch {
            if mode == .demo {
                loadState = .error(error.localizedDescription)
            }
        }
    }

    func setMode(_ newMode: AppMode) {
        mode = newMode
        Task { await refresh() }
    }

    func setDemoSelection(scenario: String, point: String) {
        scenarioId = scenario
        pointId = point
        Task { await refresh() }
    }

    func refresh() async {
        refreshTask?.cancel()
        let task = Task { await performRefresh() }
        refreshTask = task
        await task.value
    }

    private func performRefresh() async {
        loadState = .loading
        picture = nil
        mapPins = []
        mapPolygons = []
        applyBaseURL()
        await pingServer()

        do {
            switch mode {
            case .demo: try await refreshDemo()
            case .live: try await refreshLive()
            }
            loadState = .ok
        } catch is CancellationError {
            // ignore
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    private func refreshDemo() async throws {
        await loadCatalogIfNeeded()
        guard let scenarioId, let pointId else {
            throw APIError.http(path: "/v1/demo/picture", status: 400)
        }
        if let p = selectedPoint {
            mapCenter = LatLng(lat: p.lat, lng: p.lng)
        }

        async let pictureReq = client.demoPicture(scenario: scenarioId, point: pointId)
        async let warningsReq = client.demoWarningsGeoJSON(scenario: scenarioId, point: pointId)
        async let hazardsReq = client.demoHazardsGeoJSON(scenario: scenarioId, point: pointId)
        async let conditionsReq = client.demoConditionsGeoJSON(scenario: scenarioId, point: pointId)

        let pic = try await pictureReq
        picture = pic

        let warnings = try? await warningsReq
        let hazards = try? await hazardsReq
        let conditions = try? await conditionsReq

        var polygons: [OverlayPolygon] = []
        var pins: [MapPin] = []
        if let warnings { polygons += GeoJSONMap.polygons(from: warnings, defaultKind: .warning) }
        if let hazards {
            polygons += GeoJSONMap.polygons(from: hazards, defaultKind: .hazard)
            pins += GeoJSONMap.pins(from: hazards, defaultKind: .hazard)
        }
        if let conditions { pins += GeoJSONMap.pins(from: conditions, defaultKind: .other) }

        pins.append(
            MapPin(
                id: "query-point",
                coordinate: mapCenter.coordinate,
                title: selectedPoint?.name ?? "Location",
                subtitle: "Query point",
                kind: .other
            )
        )
        if let hub = pic.location.nearestHub {
            pins.append(
                MapPin(
                    id: "hub-\(hub.id)",
                    coordinate: CLLocationCoordinate2D(latitude: hub.lat, longitude: hub.lng),
                    title: hub.name,
                    subtitle: String(format: "%.1f km", hub.distanceKm),
                    kind: .hub
                )
            )
        }
        mapPolygons = polygons
        mapPins = pins
    }

    private func refreshLive() async throws {
        let point = resolvedLivePoint()
        mapCenter = point
        let pic = try await client.picture(lat: point.lat, lng: point.lng)
        picture = pic

        var polygons: [OverlayPolygon] = []
        var pins: [MapPin] = []

        if let warnings = try? await client.warningsGeoJSON(lat: point.lat, lng: point.lng) {
            polygons += GeoJSONMap.polygons(from: warnings, defaultKind: .warning)
        }
        if let hazards = try? await client.hazardsGeoJSON(lat: point.lat, lng: point.lng) {
            polygons += GeoJSONMap.polygons(from: hazards, defaultKind: .hazard)
        }
        if let conditions = try? await client.conditionsGeoJSON(lat: point.lat, lng: point.lng) {
            pins += GeoJSONMap.pins(from: conditions, defaultKind: .other)
        }

        pins.append(
            MapPin(
                id: "query-point",
                coordinate: point.coordinate,
                title: livePreset.label,
                subtitle: "Query point",
                kind: .other
            )
        )
        if let hub = pic.location.nearestHub {
            pins.append(
                MapPin(
                    id: "hub-\(hub.id)",
                    coordinate: CLLocationCoordinate2D(latitude: hub.lat, longitude: hub.lng),
                    title: hub.name,
                    subtitle: String(format: "%.1f km", hub.distanceKm),
                    kind: .hub
                )
            )
        }
        mapPolygons = polygons
        mapPins = pins
    }

    private func resolvedLivePoint() -> LatLng {
        if let preset = livePreset.latLng { return preset }
        let lat = Double(customLat) ?? LatLng.wellingtonCBD.lat
        let lng = Double(customLng) ?? LatLng.wellingtonCBD.lng
        return LatLng(lat: lat, lng: lng)
    }
}
