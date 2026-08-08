// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Pulse-inspired places column: mode, scenario, search, selectable rows.
struct PlacesSidebar: View {
    @Environment(PictureStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: Binding(
                    get: { store.mode },
                    set: { store.setMode($0) }
                )) {
                    ForEach(AppMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if store.mode == .demo, let catalog = store.catalog {
                    Picker("Scenario", selection: Binding(
                        get: { store.scenarioId ?? catalog.scenarios.first?.id ?? "" },
                        set: { store.setScenario($0) }
                    )) {
                        ForEach(catalog.scenarios) { s in
                            Text(s.title).tag(s.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            TextField("Search places", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            List(selection: Binding(
                get: { store.selectedPlaceId },
                set: { store.selectPlace(id: $0) }
            )) {
                Section {
                    ForEach(store.filteredPlaces) { place in
                        PlaceRow(place: place)
                            .tag(place.id)
                    }
                } header: {
                    Text(store.mode == .demo ? "Demo points" : "Live presets")
                }
            }
            #if os(macOS)
            .listStyle(.sidebar)
            #endif
        }
    }
}

struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.body.weight(.medium))
                if let subtitle = place.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(place.kind.label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tint.opacity(0.15))
                .foregroundStyle(tint)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch place.kind {
        case .demoPoint: return "flask.fill"
        case .livePreset: return "location.fill"
        case .hub: return "house.fill"
        case .custom: return "mappin"
        }
    }

    private var tint: Color {
        switch place.kind {
        case .demoPoint: return DesignTokens.demo
        case .livePreset: return DesignTokens.live
        case .hub: return DesignTokens.hub
        case .custom: return .secondary
        }
    }
}
