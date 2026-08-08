// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// In-memory per-source cache with TTL and `fetchedAt` stamps.
actor SourceCache {
    struct Entry<T: Sendable>: Sendable {
        let value: T
        let fetchedAt: Date
        let ttl: TimeInterval

        var isFresh: Bool {
            Date().timeIntervalSince(fetchedAt) < ttl
        }
    }

    private var storage: [String: Any] = [:]

    func get<T: Sendable>(_ key: String, as type: T.Type = T.self) -> Entry<T>? {
        storage[key] as? Entry<T>
    }

    func set<T: Sendable>(_ key: String, value: T, ttl: TimeInterval, fetchedAt: Date = Date()) {
        storage[key] = Entry(value: value, fetchedAt: fetchedAt, ttl: ttl)
    }

    func getFresh<T: Sendable>(_ key: String, as type: T.Type = T.self) -> Entry<T>? {
        guard let entry = get(key, as: type), entry.isFresh else { return nil }
        return entry
    }
}
