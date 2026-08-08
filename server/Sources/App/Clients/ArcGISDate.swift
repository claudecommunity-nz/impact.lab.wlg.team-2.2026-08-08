// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// ArcGIS FeatureServer dates arrive as epoch-ms numbers *or* ISO-8601 strings
/// depending on the layer — decode either.
enum ArcGISDate {
    static func decode<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Date? {
        if let ms = try? container.decode(Double.self, forKey: key) {
            // Heuristic: values > 1e12 are ms; else seconds.
            let seconds = ms > 1_000_000_000_000 ? ms / 1000.0 : ms
            return Date(timeIntervalSince1970: seconds)
        }
        if let s = try? container.decode(String.self, forKey: key) {
            return parseISO(s)
        }
        return nil
    }

    private static func parseISO(_ s: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fractional.date(from: s) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
