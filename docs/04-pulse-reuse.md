# Pulse Reuse Notes

Inspected: `github.com/Omega-Networks/Pulse` (8 Aug 2026). Pulse is a
macOS/iOS SwiftUI + MapKit + Metal app for PowerSense device networks — a
national-scale COP. We are building a community-scale COP **service**. Align
on the concepts (foundational data in → picture out), keep the stack thin.

## Licensing: we can copy code, not just ideas

Pulse is **AGPL-3.0** (Omega Networks Limited). This repo is AGPL-3.0.
Licence-compatible — so unlike a typical hackathon "inspiration only" rule,
**we may vendor Pulse source files directly**, keeping their copyright
headers and noting the origin. Everything we produce stays AGPLv3 either way.

## Copy directly (vendor the file)

| What | Where in Pulse | Why |
|---|---|---|
| `ConcaveHull.swift` | `Pulse/Spatial/Clustering/ConcaveHull.swift` (342 lines) | Pure CPU, zero MapKit/Metal deps, compiles server-side as-is (swap `import Darwin` → `Foundation`). Grid-indexed concaveman-style hull — exactly what G7 hotspot outlines need. Ships with two hard-won bug fixes (floor-vs-Int cell hashing for negative coords; zero-length-vector guard in angle cosine). |
| Geometry helpers | `Pulse/Models/SwiftData Models/SpatialClusteringActor.swift` lines ~397–660 (`nonisolated private` funcs) | `pointInPolygon` (**winding number** — more robust than ray casting), `isLeft`/`crossProduct`, `computeConvexHull` (monotone chain), `createBoundingBoxFromPoints` (handles 1–2 point degenerate cases), shoelace area. Lift into our `Spatial/GeoMath.swift`, de-privatise, swap `CLLocationCoordinate2D` for our own 2-double coord struct. |
| `BoundingBox` | `SpatialClusteringSystem.swift` | ~55 lines of clean value-type AABB: `contains`, `intersects`, `union`, `expanded(by:)`. |

Caveat on the hull: input must be in **metres** (its `concavity` param is
metric). At city scale, project lat/lng with a local equirectangular
approximation (`x = lng·cos(lat₀)·111320`, `y = lat·111320`) — do NOT copy
Pulse's `CoordinateTransformer` (see skip list).

## Reimplement the pattern (don't port the code)

1. **`SpatialDevice`-style protocol seam.** Pulse's clustering works on a
   4-member protocol (`deviceId, latitude, longitude, isOffline`), so
   persistence models, DTOs and test mocks are interchangeable. Ours:
   `SpatialSignal { id, lat, lng, severityBucket }` — gauges, outages and
   water faults all conform, so nearest-N and G7 clustering are written once.
2. **Wire-model / domain-model split.** Pulse: `@Model` ↔ `…Properties:
   Codable` ↔ `…DTO: Sendable`. Ours (no persistence): `…Raw: Codable`
   structs that mirror upstream field names exactly (`info_severity`,
   `numaffected`) → mapped to clean domain types at the client boundary.
   Nobody downstream ever sees an upstream field name.
3. **Grid-accelerated point-in-polygon join** (`SpatialConfidenceIndex`,
   ~50 lines): uniform lat/lng hash grid, walk only covered cells, exact test
   per candidate. Only needed if client-side PIP over many polygons gets slow
   — for G2's handful of CAP polygons, loop + winding number is plenty.
4. **Privacy floor.** Pulse suppresses clusters below a k-anonymity threshold
   (`aggregationThreshold ≥ minPoints`, coordinate truncation to ~100 m).
   Adopt for G7: never publish a hotspot of fewer than 3 signals. Live-feed
   items (outages, faults) are already published individually by their
   agencies, so pass-through is fine.
5. **Actor-per-concern concurrency.** Pulse isolates SwiftData behind actors
   and crosses boundaries with `Sendable` DTOs. Ours: `SourceCache` actor +
   `Sendable` domain structs everywhere; `PictureService` uses `async let`
   fan-out.
6. **Derived severity buckets.** `ClusterSeverity` bucketed by member count
   (3–9 minor / 10–49 moderate / 50–199 major / 200+ critical) with a
   `priority` int. Reasonable G7 default; for warnings, prefer CAP's own
   `severity` verbatim — we don't reinterpret official severity (principle 1).
7. **DBSCAN parameters as config, not constants.** `epsilon: 150 m,
   minPoints: 3` are Pulse's field-calibrated defaults; if G7 does DBSCAN
   rather than plain grid-binning, start there. CPU + uniform grid index —
   textbook, ~80 lines.

## Skip entirely

| What | Why |
|---|---|
| `CoordinateTransformer.swift` (4,412 lines) | ~4,500 lines incl. 22 embedded Metal kernels; **unconditionally GPU-gated** (init throws without a Metal device — dead on a headless server). Its CPU inverse NZTM transform is a spherical approximation anyway. We stay WGS84 end-to-end via `outSR=4326`. |
| `GPUSpatialIndexManager`, `MetalUtilities`, all `GPU*` types | Metal buffers. Server has no GPU path and doesn't need one at 126 hubs + dozens of signals. |
| GPU DBSCAN (4 Metal kernels) | Scale mismatch: Pulse targets 1M+ devices; we cluster dozens of points. |
| All SwiftUI `Views/`, MapKit code, `MKPolygon` in `DeviceCluster` | Frontend is a separate web workstream (MapLibre). Per Pulse's own review checklist: no `Color`/UI types on domain models. |
| SwiftData `@Model` layer, `ProviderModelActor` (71 KB), SSH/, Web/ | We have no persistence and no device management. Field *shapes* informed our domain models; the code doesn't transfer. |
| `DeviceCluster.init` centroid conversion | Known bug: divides projected metres by 111000 for both axes — wrong for NZTM (false easting 1.6 M). Do not copy. Our centroids stay in WGS84, no inverse projection needed. |

## One-line summary for the team

Steal the **seams** (protocol-typed signals, wire/domain split, actor cache,
privacy floor) and two **files** (ConcaveHull, GeoMath helpers); leave every
line that mentions Metal, MapKit or SwiftData where it is.
