// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Trailing / sheet inspector for Location Picture (Pulse DetailSheet analogue).
struct PictureInspectorView: View {
    @Environment(PictureStore.self) private var store
    var showsClose: Bool = false
    var onClose: (() -> Void)?

    var body: some View {
        Group {
            if store.picture != nil || store.selectedPlace != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if case .error(let message) = store.loadState {
                            Text(message)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DesignTokens.alert)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DesignTokens.alert.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        if store.loadState == .loading {
                            ProgressView("Loading picture…")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        PictureDetailView()
                    }
                    .padding()
                }
            } else {
                EmptyInspectorView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.selectedPlace?.name ?? "Location")
                    .font(.title2.weight(.bold))
                if let place = store.selectedPlace {
                    Text(String(format: "%.4f, %.4f", place.lat, place.lng))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let hub = store.picture?.location.nearestHub {
                    Text("Nearest hub: \(hub.name) · \(String(format: "%.1f", hub.distanceKm)) km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                ModeBadge(mode: store.mode)
                if showsClose {
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
