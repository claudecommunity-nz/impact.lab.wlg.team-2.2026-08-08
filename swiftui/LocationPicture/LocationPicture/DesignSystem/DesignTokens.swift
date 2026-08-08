// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

enum DesignTokens {
    static let warning = Color(red: 0.95, green: 0.55, blue: 0.12)
    static let hazard = Color(red: 0.20, green: 0.45, blue: 0.75)
    static let gauge = Color(red: 0.12, green: 0.55, blue: 0.62)
    static let outage = Color(red: 0.75, green: 0.25, blue: 0.55)
    static let water = Color(red: 0.15, green: 0.45, blue: 0.85)
    static let hub = Color(red: 0.15, green: 0.55, blue: 0.30)
    static let alert = Color(red: 0.86, green: 0.22, blue: 0.16)
    static let demo = Color(red: 0.95, green: 0.55, blue: 0.12)
    static let live = Color(red: 0.20, green: 0.50, blue: 0.85)

    static func severity(_ raw: String?) -> Color {
        switch raw?.lowercased() {
        case "extreme", "severe": return alert
        case "moderate": return warning
        case "minor": return .orange
        default: return .secondary
        }
    }

    static func layer(_ kind: MapOverlayKind) -> Color {
        switch kind {
        case .warning: return warning
        case .hazard: return hazard
        case .gauge: return gauge
        case .outage: return outage
        case .water: return water
        case .hub: return hub
        case .other: return .secondary
        }
    }
}

/// Compatibility layer for existing views during shell rewrite.
enum Theme {
    static let charcoal = Color.primary
    static let alert = DesignTokens.alert
    static let warningAmber = DesignTokens.warning
    static let planning = DesignTokens.hazard
    static let gauge = DesignTokens.gauge
    static let outage = DesignTokens.outage
    static let water = DesignTokens.water
    static let hub = DesignTokens.hub
    static let demoBanner = Color(red: 1.0, green: 0.94, blue: 0.88)

    static func severityColor(_ severity: String?) -> Color { DesignTokens.severity(severity) }
    static func pinColor(_ kind: MapOverlayKind) -> Color { DesignTokens.layer(kind) }
    static func polygonStyle(_ kind: MapOverlayKind) -> (fill: Color, stroke: Color) {
        let c = DesignTokens.layer(kind)
        return (c.opacity(0.22), c.opacity(0.85))
    }
}

enum TimeFormat {
    static func age(from date: Date?, relativeTo now: Date = .now) -> String {
        guard let date else { return "unknown age" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86_400)d ago"
    }
}
