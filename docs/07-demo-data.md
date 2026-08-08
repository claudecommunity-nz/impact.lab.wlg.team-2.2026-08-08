# Demo data & endpoints

**Live** feeds stay under `/v1/*`. **Curated mock** data lives under `/v1/demo/*`
so judges and teammates never confuse staged scenarios with production GIS.

Mock scenarios are defined in code (`server/Sources/App/Demo/`), not checked-in
JSON dumps. Live capture dumps from `scripts/test-snapshot.sh` are **gitignored**.

---

## Quick start

```bash
cd server && swift run App
# Base: http://localhost:8080  (or LAN IP logged at boot)

curl -s localhost:8080/v1/demo/scenarios | jq .
curl -s 'localhost:8080/v1/demo/picture?scenario=southerly-storm&point=lyall-bay' | jq .
curl -s 'localhost:8080/v1/demo/picture?scenario=southerly-storm&point=karori' | jq .
```

---

## Demo endpoints

| Method | Path | Params | Returns |
|---|---|---|---|
| GET | `/v1/demo/scenarios` | — | Catalogue: scenario ids, titles, descriptions, fixed points |
| GET | `/v1/demo/picture` | `scenario`, `point` | Full `LocationPicture` (same shape as live `/v1/picture`) |
| GET | `/v1/demo/warnings` | `scenario`, `point` | `officialWarnings` section only |
| GET | `/v1/demo/conditions` | `scenario`, `point` | `localConditions` section only |
| GET | `/v1/demo/hazards` | `scenario`, `point` | `hazardContext` section only |

Unknown `scenario` / `point` → **404**. Missing params → **400**.

### Points (both scenarios)

| `point` | Place | Coordinates |
|---|---|---|
| `lyall-bay` | Lyall Bay (coast) | `-41.3286, 174.7947` |
| `karori` | Karori (hill) | `-41.2865, 174.7405` |

### Scenarios

| `scenario` | Intent |
|---|---|
| **`southerly-storm`** | **Main demo.** Same Heavy Rain Warning at both points; Lyall Bay has tsunami + coastal planning layers, rising rain, Kilbirnie outage, water faults; Karori has elevated stream stage and different faults, **no** tsunami zone. “Same storm, different street.” |
| **`calm-day`** | Honest empty warnings + light gauges; planning contrast still holds. Mirrors a quiet live day. |
| **`degraded`** | Conditions section `status: "unavailable"` with a simulated reason (e.g. Hilltop timeout **(demo)**). Warnings/hazards still present — partial picture, HTTP 200. **Not a real upstream outage.** |

Field names, `source` / `trust` / `fetchedAt`, `summary[]`, and `disclaimer` match the live contract in `02-api-contract.md`.

---

## Live API (unchanged)

| Path | Role |
|---|---|
| `/healthz` | Liveness |
| `/v1/hubs` | Real WREMO hubs |
| `/v1/warnings` | Real CAP warnings |
| `/v1/conditions` | Real gauges / outages / water |
| `/v1/hazards` | Real planning layers |
| `/v1/picture` | Live fan-out join |

Use live for integrity checks; use **`/v1/demo/*`** for the 4‑minute pitch when the weather is calm.

---

## Local snapshots (not in git)

```bash
bash scripts/test-snapshot.sh                 # → scripts/fixtures/snapshots/<timestamp>/
bash scripts/test-snapshot.sh http://localhost:8081
```

These files mirror live JSON for offline schema checks. They are listed in
`.gitignore` (`**/fixtures/snapshots/`) and must **not** be committed.

---

## Where the mock data lives in the tree

```
server/Sources/App/Demo/
  DemoModels.swift        # catalogue DTOs
  DemoScenarioData.swift  # scenario payloads (Swift, curated)
  DemoService.swift       # resolve scenario + point → picture / sections
```

Edit `DemoScenarioData.swift` to tweak demo stories; keep summary language
factual (no advice words — same rules as G5).
