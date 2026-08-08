// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import MapKit

struct MapCanvasView: View {
    @Environment(PictureStore.self) private var store
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: LatLng.lyallBay.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var body: some View {
        Map(position: $position) {
            ForEach(store.mapPolygons) { polygon in
                let style = Theme.polygonStyle(polygon.kind)
                MapPolygon(coordinates: polygon.coordinates)
                    .foregroundStyle(style.fill)
                    .stroke(style.stroke, lineWidth: 2)
            }
            ForEach(store.mapPins) { pin in
                Annotation(pin.title, coordinate: pin.coordinate, anchor: .bottom) {
                    VStack(spacing: 2) {
                        Image(systemName: symbol(for: pin.kind))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Theme.pinColor(pin.kind))
                            .clipShape(Circle())
                            .shadow(radius: 2, y: 1)
                        if pin.kind == .other || pin.kind == .hub {
                            Text(pin.title)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onChange(of: store.mapCenter) { _, center in
            withAnimation {
                position = .region(
                    MKCoordinateRegion(
                        center: center.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    )
                )
            }
        }
        .onChange(of: store.mapPolygons.count) { _, _ in
            position = .region(
                MKCoordinateRegion(
                    center: store.mapCenter.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
        .overlay(alignment: .bottomLeading) {
            mapLegend.padding(8)
        }
    }

    private var mapLegend: some View {
        VStack(alignment: .leading, spacing: 3) {
            legendRow(color: Theme.warningAmber, label: "Warning")
            legendRow(color: Theme.planning, label: "Hazard")
            legendRow(color: Theme.gauge, label: "Gauge")
            legendRow(color: Theme.outage, label: "Outage")
            legendRow(color: Theme.water, label: "Water")
            legendRow(color: Theme.hub, label: "Hub")
        }
        .font(.caption2)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func legendRow(color: Color, label: String) -> some View {
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
