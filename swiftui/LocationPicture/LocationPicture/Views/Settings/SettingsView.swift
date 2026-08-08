// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Connectivity settings (Pulse-inspired API endpoint section, no secrets).
struct SettingsView: View {
    @Environment(PictureStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Location Picture API") {
                    TextField("Base URL", text: $store.baseURLString)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    HStack {
                        StatusPill(kind: store.connectionKind)
                        Spacer()
                        Button("Test") {
                            store.applyBaseURL()
                            Task {
                                await store.pingServer()
                            }
                        }
                    }
                    Button("Apply & refresh") {
                        store.applyBaseURL()
                        Task { await store.refresh() }
                    }
                }

                Section("About") {
                    Text("Location Picture")
                        .font(.headline)
                    Text("SwiftUI client for the Team 2 Vapor API. Map-first COP inspired by Omega Networks Pulse interaction patterns — not a Pulse fork.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("AGPL-3.0-or-later")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}
