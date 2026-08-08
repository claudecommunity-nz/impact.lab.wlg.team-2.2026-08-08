// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import MapKit

/// Root: Pulse-shaped multiplatform shell (map-first).
struct ContentView: View {
    @Environment(PictureStore.self) private var store
    @State private var showSettings = false
    #if os(iOS)
    @State private var placesSheetOpen = true
    @State private var detailOpen = false
    #endif

    var body: some View {
        @Bindable var store = store
        Group {
            #if os(macOS)
            macShell
            #else
            iosShell
            #endif
        }
        .onAppear { store.onAppear() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - macOS (Places | Map | Inspector)

    #if os(macOS)
    private var macShell: some View {
        @Bindable var store = store
        return NavigationSplitView {
            PlacesSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } content: {
            MapCanvasView(cameraPosition: $store.cameraPosition)
                .navigationSplitViewColumnWidth(min: 400, ideal: 560)
        } detail: {
            PictureInspectorView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
        }
        .toolbar { toolbarContent }
        .navigationTitle("Location Picture")
    }
    #endif

    // MARK: - iOS (Map + MainSheet + DetailSheet)

    #if os(iOS)
    private var iosShell: some View {
        @Bindable var store = store
        return NavigationStack {
            MapCanvasView(cameraPosition: $store.cameraPosition)
                .ignoresSafeArea(edges: .bottom)
                .toolbar { toolbarContent }
                .navigationTitle("Location Picture")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $placesSheetOpen) {
                    NavigationStack {
                        PlacesSidebar()
                            .navigationTitle("Places")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Map") { placesSheetOpen = false }
                                }
                            }
                            .onChange(of: store.selectedPlaceId) { _, newId in
                                if newId != nil {
                                    placesSheetOpen = false
                                    detailOpen = true
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                }
                .sheet(isPresented: $detailOpen) {
                    NavigationStack {
                        PictureInspectorView(showsClose: true) {
                            detailOpen = false
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Places") {
                                    detailOpen = false
                                    placesSheetOpen = true
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { detailOpen = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button {
                            placesSheetOpen = true
                        } label: {
                            Label(store.selectedPlace?.name ?? "Places", systemImage: "list.bullet")
                        }
                        Spacer()
                        if store.selectedPlace != nil {
                            Button {
                                detailOpen = true
                            } label: {
                                Label("Picture", systemImage: "doc.text.image")
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
        }
    }
    #endif

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            StatusPill(kind: store.connectionKind)
        }
        ToolbarItem(placement: .automatic) {
            ModeBadge(mode: store.mode)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environment(PictureStore())
}
