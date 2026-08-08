// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreLocation
import Observation
import MapKit
import SwiftUI

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
    var serverOK: Bool?
    var loadState: LoadState = .idle

    var places: [Place] = []
    var selectedPlaceId: String?
    var searchText: String = ""

    var catalog: DemoCatalog?
    var scenarioId: String?

    var picture: LocationPicture?
    var mapPins: [MapPin] = []
    var mapPolygons: [OverlayPolygon] = []
    var mapCenter: LatLng = .wellingtonCBD
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: LatLng.wellingtonCBD.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )

    var showWarnings = true
    var showHazards = true
    var showConditions = true
    var showHubs = true

    private let client = APIClient()
    private var refreshTask: Task<Void, Never>?

    var selectedPlace: Place? {
        places.first { $0.id == selectedPlaceId }
    }

    var filteredPlaces: [Place] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return places }
        return places.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || ($0.subtitle?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var selectedScenario: DemoScenarioInfo? {
        catalog?.scenarios.first { $0.id == scenarioId }
    }

    var connectionKind: StatusPill.Kind {
        if case .loading = loadState { return .loading }
        if serverOK == true { return .online }
        if serverOK == false { return .offline }
        return .unknown
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
        rebuildPlaces()
        if selectedPlaceId == nil {
            selectedPlaceId = places.first?.id
        }
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

    func setMode(_ newMode: AppMode) {
        guard mode != newMode else { return }
        mode = newMode
        rebuildPlaces()
        selectedPlaceId = places.first?.id
        Task { await refresh() }
    }

    func selectPlace(id: String?) {
        selectedPlaceId = id
        if let place = selectedPlace {
            mapCenter = place.latLng
            withCamera(for: place.latLng)
            if place.kind == .demoPoint, let sid = place.scenarioId {
                scenarioId = sid
            }
        }
        Task { await refresh() }
    }

    func setScenario(_ id: String) {
        scenarioId = id
        rebuildPlaces()
        if let current = selectedPlace, current.kind == .demoPoint,
           let match = places.first(where: { $0.demoPointId == current.demoPointId }) {
            selectedPlaceId = match.id
        } else {
            selectedPlaceId = places.first?.id
        }
        Task { await refresh() }
    }

    func rebuildPlaces() {
        switch mode {
        case .demo: places = demoPlaces()
        case .live: places = livePresetPlaces()
        }
    }

    private func demoPlaces() -> [Place] {
        guard let catalog else {
            return [
                Place(
                    id: "demo-lyall-bay",
                    name: "Lyall Bay",
                    subtitle: "Demo point",
                    lat: LatLng.lyallBay.lat,
                    lng: LatLng.lyallBay.lng,
                    kind: .demoPoint,
                    demoPointId: "lyall-bay",
                    scenarioId: scenarioId ?? "southerly-storm"
                ),
                Place(
                    id: "demo-karori",
                    name: "Karori",
                    subtitle: "Demo point",
                    lat: LatLng.karori.lat,
                    lng: LatLng.karori.lng,
                    kind: .demoPoint,
                    demoPointId: "karori",
                    scenarioId: scenarioId ?? "southerly-storm"
                ),
            ]
        }
        let scenario = catalog.scenarios.first { $0.id == scenarioId } ?? catalog.scenarios.first
        guard let scenario else { return [] }
        return scenario.points.map { point in
            Place(
                id: "demo-\(scenario.id)-\(point.id)",
                name: point.name,
                subtitle: scenario.title,
                lat: point.lat,
                lng: point.lng,
                kind: .demoPoint,
                demoPointId: point.id,
                scenarioId: scenario.id
            )
        }
    }

    private func livePresetPlaces() -> [Place] {
        [
            Place(id: "live-lyall", name: "Lyall Bay", subtitle: "Live preset", lat: LatLng.lyallBay.lat, lng: LatLng.lyallBay.lng, kind: .livePreset, demoPointId: nil, scenarioId: nil),
            Place(id: "live-karori", name: "Karori", subtitle: "Live preset", lat: LatLng.karori.lat, lng: LatLng.karori.lng, kind: .livePreset, demoPointId: nil, scenarioId: nil),
            Place(id: "live-cbd", name: "Wellington CBD", subtitle: "Live preset", lat: LatLng.wellingtonCBD.lat, lng: LatLng.wellingtonCBD.lng, kind: .livePreset, demoPointId: nil, scenarioId: nil),
        ]
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
            if mode == .demo {
                try await ensureCatalog()
                rebuildPlaces()
            }
            guard let place = selectedPlace else {
                loadState = .idle
                return
            }
            withCamera(for: place.latLng)
            mapCenter = place.latLng

            switch mode {
            case .demo: try await refreshDemo(place: place)
            case .live: try await refreshLive(place: place)
            }
            loadState = .ok
        } catch is CancellationError {
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    private func ensureCatalog() async throws {
        if catalog != nil { return }
        let cat = try await client.demoScenarios()
        catalog = cat
        if scenarioId == nil {
            scenarioId = cat.scenarios.first?.id
        }
        rebuildPlaces()
        if selectedPlaceId == nil || !places.contains(where: { $0.id == selectedPlaceId }) {
            selectedPlaceId = places.first?.id
        }
    }

    private func refreshDemo(place: Place) async throws {
        let scenario = place.scenarioId ?? scenarioId ?? "southerly-storm"
        let point = place.demoPointId ?? "lyall-bay"
        scenarioId = scenario

        async let pictureReq = client.demoPicture(scenario: scenario, point: point)
        async let warningsReq = client.demoWarningsGeoJSON(scenario: scenario, point: point)
        async let hazardsReq = client.demoHazardsGeoJSON(scenario: scenario, point: point)
        async let conditionsReq = client.demoConditionsGeoJSON(scenario: scenario, point: point)

        let pic = try await pictureReq
        picture = pic

        var polygons: [OverlayPolygon] = []
        var pins: [MapPin] = []
        if showWarnings, let w = try? await warningsReq {
            polygons += GeoJSONMap.polygons(from: w, defaultKind: .warning)
        }
        if showHazards, let h = try? await hazardsReq {
            polygons += GeoJSONMap.polygons(from: h, defaultKind: .hazard)
        }
        if showConditions, let c = try? await conditionsReq {
            pins += GeoJSONMap.pins(from: c, defaultKind: .other)
        }
        pins.append(contentsOf: selectionPins(for: place, picture: pic))
        mapPolygons = polygons
        mapPins = pins
    }

    private func refreshLive(place: Place) async throws {
        let point = place.latLng
        let pic = try await client.picture(lat: point.lat, lng: point.lng)
        picture = pic

        var polygons: [OverlayPolygon] = []
        var pins: [MapPin] = []
        if showWarnings, let w = try? await client.warningsGeoJSON(lat: point.lat, lng: point.lng) {
            polygons += GeoJSONMap.polygons(from: w, defaultKind: .warning)
        }
        if showHazards, let h = try? await client.hazardsGeoJSON(lat: point.lat, lng: point.lng) {
            polygons += GeoJSONMap.polygons(from: h, defaultKind: .hazard)
        }
        if showConditions, let c = try? await client.conditionsGeoJSON(lat: point.lat, lng: point.lng) {
            pins += GeoJSONMap.pins(from: c, defaultKind: .other)
        }
        pins.append(contentsOf: selectionPins(for: place, picture: pic))
        mapPolygons = polygons
        mapPins = pins
    }

    private func selectionPins(for place: Place, picture: LocationPicture) -> [MapPin] {
        var pins: [MapPin] = [
            MapPin(
                id: "query-\(place.id)",
                coordinate: place.coordinate,
                title: place.name,
                subtitle: "Query point",
                kind: .other
            ),
        ]
        if showHubs, let hub = picture.location.nearestHub {
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
        return pins
    }

    private func withCamera(for point: LatLng) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: point.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        )
    }
}
