// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

struct DemoModeBar: View {
    @Environment(PictureStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flask.fill")
                Text("Showing curated demo data — not live feeds")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Theme.charcoal)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.demoBanner)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.warningAmber.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let catalog = store.catalog {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scenario")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Scenario", selection: Binding(
                        get: { store.scenarioId ?? "" },
                        set: { newScenario in
                            let point = catalog.scenarios.first { $0.id == newScenario }?.points.first?.id ?? ""
                            store.setDemoSelection(scenario: newScenario, point: point)
                        }
                    )) {
                        ForEach(catalog.scenarios) { scenario in
                            Text(scenario.title).tag(scenario.id)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.menu)
                    #endif

                    if let scenario = store.selectedScenario {
                        Text(scenario.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("Point")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Point", selection: Binding(
                            get: { store.pointId ?? "" },
                            set: { newPoint in
                                if let sid = store.scenarioId {
                                    store.setDemoSelection(scenario: sid, point: newPoint)
                                }
                            }
                        )) {
                            ForEach(scenario.points) { point in
                                Text(point.name).tag(point.id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } else {
                Text("Demo catalogue not loaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
