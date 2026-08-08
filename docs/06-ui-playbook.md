# UI Playbook — what can be built, with which data, right now

Written 13:55. Everything in section 1 is powered by endpoints that are
**live and tested this hour**. Build top to bottom; stop when time runs out.
Agreed page order: status first, favourites, then map, then regional.

## 1. Buildable right now (endpoints are live)

### "Right now at your location" — the oxygen-mask block
**Endpoint:** `GET /v1/picture?lat&lng` (preferred — full picture in one call).
Fallback: `GET /v1/warnings?lat&lng` for a warnings-only card.
Demo / calm day: `GET /v1/demo/picture?scenario=southerly-storm&point=lyall-bay`
(see `07-demo-data.md`).

The bold text-first statement the team agreed on. Render logic:

- 0 warnings → "No official warnings cover this location right now."
  (honest empty state — say it, don't hide it)
- ≥1 → biggest type: `event` ("Heavy Rain Warning"), then `severity` +
  `urgency` chips (verbatim CAP values — we never reinterpret), `expires`
  as "until 6pm today", `headline` as one supporting line.
- Every card: source chip (`source.name`) + age ("checked 40s ago" from
  `source.fetchedAt`). This is the product's signature — never omit it.
- `description` behind a "more" disclosure; `web` as "MetService ↗" link.

### Favourites (Home / Work / School / +)
Already built with localStorage — keep. Each saved place = one
`/v1/warnings?lat&lng` (later `/v1/picture`) call. Render one compact status
row per place: place name → worst event covering it, or "no warnings".
This is the "why I need to pick up the kids" feature: alerts for places you
care about with zero map reading.

### Live conditions near a location
**Endpoint:** `GET /v1/conditions?lat&lng&n&radiusKm` — live now.

- Gauges: "Karori Stream · Rainfall 2.4 mm · 12 min ago · 1.5 km away ·
  trend steady". Units come from the payload (`units`) — never hardcode
  (Stage is mm, Flow is m³/s).
- Electricity outages: locationName, numAffected, distributor, distance.
- Water faults: description, address, status, distance. Backend is capping
  to nearest N — render what arrives.
- Each item: source chip + observedAt age. Empty sections say "none within
  10 km" rather than disappearing.

### Map (below the fold, as agreed)
- Hub pins: `GET /v1/hubs?format=geojson` → one MapLibre GeoJSON source.
  126 pins, popup = name/type/address. "Your nearest hub" is a one-liner
  the UI can compute: haversine to favourite, or wait for G5's
  `nearestHub`.
- **Warning polygons:** `GET /v1/warnings?format=geojson` → semi-transparent
  fill layer + outline, colour by `severity`. This is cheap (one source,
  two layers) and is the single most demo-striking map element. Wellington
  currently has none — the NZ-wide polygons (Northland/BOP/Crown Range)
  still show when zoomed out, proving it's real data.
- Favourite markers already exist — keep.

## 2. Buildable within the hour (backend landing now)

### Hazard context — "what this place sits in"
**Endpoint:** `GET /v1/hazards?lat&lng` (G4, in progress: tsunami evacuation
zones + coastal inundation medium/high).

- Card per layer: "Tsunami evacuation zone: **Red** (planning data)" using
  `Evac_Zone`/`Col_Code`; "Coastal inundation area (medium scenario)".
- MUST carry the planning-data caveat and publisher attribution — the
  payload includes both; just render them.
- This powers the killer demo beat: Lyall Bay shows zones, Karori shows
  none. **The "am I in a flood/wind zone during this warning" value-add the
  team discussed IS this card — no AI required.**

### The full picture in one call
**Endpoint:** `GET /v1/picture?lat&lng` (G5, after G4). Combines all the
above + `summary[]` (ready-made factual sentences — render as the bold
text block verbatim) + `sources[]` (render as a footer: every feed, its
age, and `status` — show a grey "feed unavailable" chip when not ok) +
`disclaimer` (render verbatim, small, always visible).
Until it lands, compose the same page from the three calls above; the
docs/02 example JSON is the exact fixture to build cards against.

## 3. Do NOT build today (say in pitch instead)

- Login / incident-manager view — same components, re-prioritised; roadmap.
- AI relevance ranking, antecedent conditions (ground saturation) — roadmap.
- Community reports — `trust: "community-unverified"` slot exists; roadmap.
- Anything that interprets severity or gives advice. Words like
  "evacuate/should/safe" never appear in the UI. Facts + source + age.

## Cheat sheet: dataset → UI element

| Data (live feed) | UI element | Endpoint |
|---|---|---|
| MetService CAP warnings | Bold status block + severity chips + map polygons | `/v1/warnings` |
| NEMA Emergency Mobile Alerts | Same card type, source chip says NEMA | `/v1/warnings` |
| Hilltop river/rain gauges | "Near you" live readings with trend + age | `/v1/conditions` |
| Electricity outages (NEMA) | Outage rows with customers affected + distance | `/v1/conditions` |
| Water faults (Wellington Water) | Fault rows with status + distance | `/v1/conditions` |
| WREMO community hubs | Map pins + "your nearest hub" line | `/v1/hubs` |
| Tsunami evacuation zones (WCC) | "This place sits in…" planning card | `/v1/hazards` (G4) |
| Coastal inundation med/high (WCC/NIWA) | Same card type | `/v1/hazards` (G4) |
| Everything joined + summary + provenance | The whole page in one call | `/v1/picture` (G5) |

Rule that makes it cohere: **every rendered fact = value + source + age.**
If a card can't show all three, the card isn't done.
