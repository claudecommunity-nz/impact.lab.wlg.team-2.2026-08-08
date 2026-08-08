// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

struct LiveModeBar: View {
    @Environment(PictureStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 10) {
            Text("Live feeds from the API (may be calm on a quiet day)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Preset", selection: $store.livePreset) {
                ForEach(PictureStore.LivePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: store.livePreset) { _, _ in
                Task { await store.refresh() }
            }

            if store.livePreset == .custom {
                HStack {
                    TextField("lat", text: $store.customLat)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.roundedBorder)
                    TextField("lng", text: $store.customLng)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.roundedBorder)
                    Button("Go") {
                        Task { await store.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
}
