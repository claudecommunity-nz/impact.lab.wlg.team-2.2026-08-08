// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import MapKit

/// Primary map canvas — Pulse-style full-bleed map with floating chrome.
struct MapCanvasView: View {
    @Environment(PictureStore.self) private var store
    @Binding var cameraPosition: MapCameraPosition
    @State private var mapStyleIndex = 0

    var body: some View {
        @Bindable var store = store
        Map(position: $cameraPosition) {
            ForEach(store.mapPolygons) { polygon in
                let style = Theme.polygonStyle(polygon.kind)
                MapPolygon(coordinates: polygon.coordinates)
                    .foregroundStyle(style.fill)
                    .stroke(style.stroke, lineWidth: 2)
            }
            ForEach(store.mapPins) { pin in
                Annotation(pin.title, coordinate: pin.coordinate, anchor: .bottom) {
                    pinView(pin)
                }
            }
        }
        .mapStyle(currentMapStyle)
        .overlay(alignment: .topLeading) {
            Group {
                if store.mode == .demo {
                    DemoBanner(
                        scenarioTitle: store.selectedScenario?.title,
                        pointName: store.selectedPlace?.name
                    )
                    .frame(maxWidth: 360)
                }
            }
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                MapChromeButton(systemName: "map") {
                    mapStyleIndex = (mapStyleIndex + 1) % 3
                }
                MapChromeButton(systemName: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
            }
            .padding(12)
        }
        .overlay(alignment: .bottomLeading) {
            mapLegend.padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Warnings", isOn: $store.showWarnings)
                Toggle("Hazards", isOn: $store.showHazards)
                Toggle("Conditions", isOn: $store.showConditions)
                Toggle("Hubs", isOn: $store.showHubs)
            }
            .font(.caption)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(12)
            .onChange(of: store.showWarnings) { _, _ in Task { await store.refresh() } }
            .onChange(of: store.showHazards) { _, _ in Task { await store.refresh() } }
            .onChange(of: store.showConditions) { _, _ in Task { await store.refresh() } }
            .onChange(of: store.showHubs) { _, _ in Task { await store.refresh() } }
        }
        .onChange(of: store.mapCenter) { _, center in
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: center.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    )
                )
            }
        }
    }

    private var currentMapStyle: MapStyle {
        switch mapStyleIndex {
        case 1: return .imagery(elevation: .realistic)
        case 2: return .hybrid(elevation: .realistic)
        default: return .standard(elevation: .realistic)
        }
    }

    private func pinView(_ pin: MapPin) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol(for: pin.kind))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(7)
                .background(DesignTokens.layer(pin.kind))
                .clipShape(Circle())
                .shadow(radius: 2, y: 1)
            if pin.kind == .other || pin.kind == .hub {
                Text(pin.title)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
    }

    private var mapLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendRow(DesignTokens.warning, "Warning")
            legendRow(DesignTokens.hazard, "Hazard")
            legendRow(DesignTokens.gauge, "Gauge")
            legendRow(DesignTokens.outage, "Outage")
            legendRow(DesignTokens.water, "Water")
            legendRow(DesignTokens.hub, "Hub")
        }
        .font(.caption2)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func legendRow(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func symbol(for kind: MapOverlayKind) -> String {
        switch kind {
        case .warning: return "exclamationmark"
        case .hazard: return "water.waves"
        case .gauge: return "drop.fill"
        case .outage: return "bolt.fill"
        case .water: return "wrench.and.screwdriver.fill"
        case .hub: return "house.fill"
        case .other: return "mappin"
        }
    }
}
