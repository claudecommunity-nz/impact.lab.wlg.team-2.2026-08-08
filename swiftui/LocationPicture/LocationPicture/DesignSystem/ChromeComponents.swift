// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

struct StatusPill: View {
    enum Kind {
        case online, offline, unknown, loading
    }

    let kind: Kind
    var label: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label ?? defaultLabel)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var color: Color {
        switch kind {
        case .online: return .green
        case .offline: return DesignTokens.alert
        case .unknown: return .gray
        case .loading: return .orange
        }
    }

    private var defaultLabel: String {
        switch kind {
        case .online: return "API online"
        case .offline: return "API offline"
        case .unknown: return "API…"
        case .loading: return "Loading"
        }
    }
}

struct ModeBadge: View {
    let mode: AppMode

    var body: some View {
        Text(mode == .demo ? "DEMO" : "LIVE")
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(mode == .demo ? DesignTokens.demo : DesignTokens.live)
            .background((mode == .demo ? DesignTokens.demo : DesignTokens.live).opacity(0.18))
            .clipShape(Capsule())
    }
}

struct DemoBanner: View {
    var scenarioTitle: String?
    var pointName: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flask.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text("Curated demo data — not live feeds")
                    .font(.caption.weight(.semibold))
                if scenarioTitle != nil || pointName != nil {
                    Text([scenarioTitle, pointName].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.demoBanner)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DesignTokens.demo.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MapChromeButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyInspectorView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a place",
            systemImage: "mappin.and.ellipse",
            description: Text("Choose a place from the list to load its Location Picture on the map.")
        )
    }
}
