// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

struct PictureDetailView: View {
    @Environment(PictureStore.self) private var store

    var body: some View {
        if let picture = store.picture {
            VStack(alignment: .leading, spacing: 16) {
                if let hub = picture.location.nearestHub {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "house.lodge.fill")
                            .foregroundStyle(Theme.hub)
                        Text("Nearest hub: \(hub.name)\(hub.address.map { ", \($0)" } ?? "") · \(String(format: "%.1f", hub.distanceKm)) km")
                            .font(.subheadline)
                    }
                }

                summarySection(picture.summary)
                warningsSection(picture.officialWarnings)
                conditionsSection(picture.localConditions)
                hazardsSection(picture.hazardContext)
                sourcesSection(picture.sources)
                Text(picture.disclaimer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        } else if store.loadState == .loading {
            EmptyView()
        } else if case .error = store.loadState {
            EmptyView()
        } else {
            ContentUnavailableView(
                "No picture yet",
                systemImage: "map",
                description: Text("Start the Vapor server and tap refresh.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func summarySection(_ lines: [String]) -> some View {
        sectionCard(title: "Summary", systemImage: "text.alignleft") {
            if lines.isEmpty {
                Text("No summary lines.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(line).font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private func warningsSection(_ section: OfficialWarningsSection) -> some View {
        sectionCard(title: "Official warnings", systemImage: "exclamationmark.triangle.fill") {
            if section.status == "unavailable" {
                Text("Warnings unavailable\(section.reason.map { " — \($0)" } ?? "").")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.alert)
            } else if section.items.isEmpty {
                Text("No official warnings cover this location.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(section.items) { WarningCardView(warning: $0) }
                }
            }
        }
    }

    private func conditionsSection(_ section: LocalConditionsSection) -> some View {
        sectionCard(title: "Local conditions", systemImage: "waveform.path.ecg") {
            if section.status == "unavailable" {
                Text("Conditions unavailable\(section.reason.map { " — \($0)" } ?? "").")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.alert)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    conditionGroup(title: "Gauges", empty: section.gauges.isEmpty) {
                        ForEach(section.gauges) { g in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.site).font(.subheadline.weight(.semibold))
                                Text("\(g.measurement): \(formatNumber(g.value)) \(g.units)\(g.trend.map { " · \($0)" } ?? "") · \(String(format: "%.1f", g.distanceKm)) km")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    conditionGroup(title: "Electricity outages", empty: section.electricityOutages.isEmpty) {
                        ForEach(section.electricityOutages) { o in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.locationName ?? "Outage").font(.subheadline.weight(.semibold))
                                Text([
                                    o.status,
                                    o.numAffected.map { "~\($0) customers" },
                                    String(format: "%.1f km", o.distanceKm),
                                ].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    conditionGroup(title: "Water faults", empty: section.waterFaults.isEmpty) {
                        ForEach(section.waterFaults) { w in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.description ?? "Water fault").font(.subheadline.weight(.semibold))
                                Text([
                                    w.address,
                                    w.status,
                                    w.priority,
                                    String(format: "%.1f km", w.distanceKm),
                                ].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func hazardsSection(_ envelope: HazardsEnvelope) -> some View {
        sectionCard(title: "Hazard context", systemImage: "water.waves") {
            Text(envelope.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            if envelope.items.isEmpty {
                Text("No planning hazard layers cover this location.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(envelope.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.layer): \(item.value)")
                                .font(.subheadline.weight(.semibold))
                            if let detail = item.detail {
                                Text(detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(item.publisher) · \(TimeFormat.age(from: item.source.fetchedAt))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func sourcesSection(_ sources: [SourceStatusEntry]) -> some View {
        sectionCard(title: "Sources", systemImage: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sources) { s in
                    HStack {
                        Circle()
                            .fill(s.status == "ok" ? Color.green : Theme.alert)
                            .frame(width: 6, height: 6)
                        Text(s.sourceId).font(.caption.monospaced())
                        Spacer()
                        Text(s.status).font(.caption2).foregroundStyle(.secondary)
                        Text(TimeFormat.age(from: s.fetchedAt)).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func conditionGroup<Content: View>(
        title: String,
        empty: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if empty {
                Text("None nearby.").font(.caption).foregroundStyle(.tertiary)
            } else {
                content()
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage).font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func formatNumber(_ value: Double) -> String {
        if value >= 1000 || value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

struct WarningCardView: View {
    let warning: Warning

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(warning.event).font(.subheadline.weight(.bold))
                Spacer()
                if let severity = warning.severity {
                    Text(severity)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.severityColor(severity).opacity(0.2))
                        .foregroundStyle(Theme.severityColor(severity))
                        .clipShape(Capsule())
                }
            }
            if let headline = warning.headline {
                Text(headline).font(.caption).foregroundStyle(.secondary)
            }
            if let area = warning.areaDesc {
                Text(area).font(.caption2).foregroundStyle(.tertiary)
            }
            if let description = warning.description {
                Text(description).font(.caption).lineLimit(4)
            }
            Text(warning.source.name + " · " + TimeFormat.age(from: warning.source.fetchedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Theme.severityColor(warning.severity).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
