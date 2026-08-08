// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

enum Theme {
    static let charcoal = Color(red: 0.18, green: 0.18, blue: 0.20)
    static let alert = Color(red: 0.86, green: 0.22, blue: 0.16)
    static let warningAmber = Color(red: 0.95, green: 0.55, blue: 0.12)
    static let planning = Color(red: 0.20, green: 0.45, blue: 0.75)
    static let gauge = Color(red: 0.12, green: 0.55, blue: 0.62)
    static let outage = Color(red: 0.75, green: 0.25, blue: 0.55)
    static let water = Color(red: 0.15, green: 0.45, blue: 0.85)
    static let hub = Color(red: 0.15, green: 0.55, blue: 0.30)
    static let demoBanner = Color(red: 1.0, green: 0.94, blue: 0.88)

    static func severityColor(_ severity: String?) -> Color {
        switch severity?.lowercased() {
        case "extreme", "severe": return alert
        case "moderate": return warningAmber
        case "minor": return .orange
        default: return charcoal.opacity(0.7)
        }
    }

    static func pinColor(_ kind: MapOverlayKind) -> Color {
        switch kind {
        case .warning: return warningAmber
        case .hazard: return planning
        case .gauge: return gauge
        case .outage: return outage
        case .water: return water
        case .hub: return hub
        case .other: return .secondary
        }
    }

    static func polygonStyle(_ kind: MapOverlayKind) -> (fill: Color, stroke: Color) {
        switch kind {
        case .warning:
            return (warningAmber.opacity(0.22), warningAmber.opacity(0.85))
        case .hazard:
            return (planning.opacity(0.18), planning.opacity(0.8))
        default:
            return (Color.gray.opacity(0.12), Color.gray.opacity(0.6))
        }
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
