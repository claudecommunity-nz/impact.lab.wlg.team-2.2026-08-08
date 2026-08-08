// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Pure factual summary lines for a Location Picture. No advice language.
enum SummaryBuilder {
    /// Words banned by the API contract / gate G5.
    static let bannedWords: [String] = [
        "should", "must", "evacuate", "immediately", "do not", "safe", "unsafe",
    ]

    static func build(
        warnings: OfficialWarningsSection,
        conditions: LocalConditionsSection,
        hazards: HazardsEnvelope,
        nearestHub: NearestHub?
    ) -> [String] {
        var lines: [String] = []

        // 1. Warnings
        if warnings.status == "unavailable" {
            lines.append("Official warnings are currently unavailable for this location.")
        } else if warnings.items.isEmpty {
            lines.append("No official warnings currently cover this location.")
        } else {
            let n = warnings.items.count
            let first = warnings.items[0]
            let event = first.headline ?? first.event
            var line = "\(n) official warning\(n == 1 ? "" : "s") cover\(n == 1 ? "s" : "") this location: \(event)"
            if let sev = first.severity, !sev.isEmpty {
                line += " (\(sev))"
            }
            if let expires = first.expires {
                line += ", in force until \(formatUTC(expires))"
            }
            line += "."
            lines.append(line)
        }

        // 2. Nearest gauge
        if conditions.status == "unavailable" {
            lines.append("Local gauge and lifeline conditions are currently unavailable.")
        } else if let g = conditions.gauges.first {
            var line =
                "Nearest gauge (\(g.site), \(formatKm(g.distanceKm)) km) last read \(formatNumber(g.value)) \(g.units) \(g.measurement.lowercased())"
            if let trend = g.trend, !trend.isEmpty {
                line += ", \(trend)"
            }
            line += " at \(formatUTC(g.observedAt))."
            lines.append(line)
        }

        // 3. Outages
        if conditions.status == "ok" {
            let outages = conditions.electricityOutages
            if outages.isEmpty {
                // omit — empty is not always worth a line when calm
            } else if outages.count == 1, let o = outages.first {
                var line = "1 electricity outage within range"
                if let name = o.locationName, !name.isEmpty {
                    line += ": \(name)"
                }
                if let n = o.numAffected {
                    line += ", ~\(n) customers"
                }
                if let started = o.startedAt {
                    line += ", since \(formatUTC(started))"
                }
                line += "."
                lines.append(line)
            } else {
                lines.append("\(outages.count) electricity outages within range.")
            }

            // 4. Water faults
            let faults = conditions.waterFaults
            if faults.isEmpty {
                // omit
            } else if faults.count == 1, let f = faults.first {
                var line = "1 water fault within range"
                if let desc = f.description, !desc.isEmpty {
                    line += ": \(desc)"
                } else if let addr = f.address, !addr.isEmpty {
                    line += " at \(addr)"
                }
                if let st = f.status, !st.isEmpty {
                    line += ", \(st.lowercased())"
                }
                line += "."
                lines.append(line)
            } else {
                lines.append("\(faults.count) water faults within range.")
            }
        }

        // 5. Hazards (planning)
        if hazards.status == "unavailable" {
            lines.append("Hazard planning layers are currently unavailable.")
        } else if !hazards.items.isEmpty {
            let tsunami = hazards.items.first { $0.id == "tsunami-evacuation-zones" }
            let coastal = hazards.items.filter {
                $0.id == "coastal-inundation-medium" || $0.id == "coastal-inundation-high"
            }
            let stream = hazards.items.first { $0.id == "stream-corridor" }

            var parts: [String] = []
            if let t = tsunami {
                parts.append("the WCC tsunami evacuation zone (\(t.value))")
            }
            for c in coastal {
                let label = c.id == "coastal-inundation-high" ? "high" : "medium"
                parts.append("\(label) coastal inundation planning area")
            }
            if stream != nil {
                parts.append("a stream corridor planning area")
            }
            // Any other layers
            for h in hazards.items where ![
                "tsunami-evacuation-zones",
                "coastal-inundation-medium",
                "coastal-inundation-high",
                "stream-corridor",
            ].contains(h.id) {
                parts.append("\(h.layer) (\(h.value))")
            }

            if !parts.isEmpty {
                let joined: String
                if parts.count == 1 {
                    joined = parts[0]
                } else if parts.count == 2 {
                    joined = "\(parts[0]) and \(parts[1])"
                } else {
                    joined = parts.dropLast().joined(separator: ", ") + ", and \(parts.last!)"
                }
                lines.append("This location is inside \(joined).")
            }
        }

        // 6. Nearest hub
        if let hub = nearestHub {
            let dist: String
            if hub.distanceKm < 1 {
                dist = "\(Int((hub.distanceKm * 1000).rounded())) m"
            } else {
                dist = "\(formatKm(hub.distanceKm)) km"
            }
            lines.append("Nearest community emergency hub: \(hub.name), \(dist).")
        }

        return lines
    }

    /// Returns true if any line contains a banned advice word (case-insensitive).
    static func containsBannedWords(_ lines: [String]) -> Bool {
        for line in lines {
            let lower = line.lowercased()
            for word in bannedWords {
                if lower.contains(word) { return true }
            }
        }
        return false
    }

    // MARK: - Formatting helpers

    private static func formatKm(_ km: Double) -> String {
        if km < 10 {
            return String(format: "%.1f", km)
        }
        return String(format: "%.0f", km)
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e9 {
            return String(format: "%.0f", value)
        }
        if abs(value) >= 100 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private static let utcFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mm 'UTC' d MMM"
        return f
    }()

    private static func formatUTC(_ date: Date) -> String {
        utcFormatter.string(from: date)
    }
}
