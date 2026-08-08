// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

struct ContentView: View {
    @Environment(PictureStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    serverBar
                    modePicker
                    if store.mode == .demo {
                        DemoModeBar()
                    } else {
                        LiveModeBar()
                    }
                    statusLine
                    #if os(macOS)
                    HStack(alignment: .top, spacing: 16) {
                        MapCanvasView()
                            .frame(minHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        PictureDetailView()
                            .frame(maxWidth: 420)
                    }
                    #else
                    MapCanvasView()
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    PictureDetailView()
                    #endif
                }
                .padding()
            }
            .background(platformBackground)
            .navigationTitle("Location Picture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }
            }
            #if os(iOS)
            .refreshable { await store.refresh() }
            #endif
        }
        .onAppear { store.onAppear() }
    }

    private var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGroupedBackground)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What does this weather event mean here?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("SwiftUI client · Team 2 · Vapor Location Picture API")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var serverBar: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(store.serverOK == true ? Color.green : (store.serverOK == false ? Theme.alert : Color.gray))
                    .frame(width: 8, height: 8)
                Text(store.serverOK == true ? "API reachable" : (store.serverOK == false ? "API offline" : "API…"))
                    .font(.caption.weight(.medium))
                Spacer()
                Text(store.mode == .demo ? "DEMO" : "LIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(store.mode == .demo ? Theme.warningAmber.opacity(0.25) : Theme.planning.opacity(0.2))
                    .clipShape(Capsule())
            }
            HStack {
                TextField("API base URL", text: $store.baseURLString)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .font(.caption)
                    .padding(8)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("Apply") {
                    store.applyBaseURL()
                    Task { await store.refresh() }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { store.mode },
            set: { store.setMode($0) }
        )) {
            ForEach(AppMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch store.loadState {
        case .idle, .ok:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading picture…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.alert)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.alert.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    private var fieldBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }
}

#Preview {
    ContentView()
        .environment(PictureStore())
}
