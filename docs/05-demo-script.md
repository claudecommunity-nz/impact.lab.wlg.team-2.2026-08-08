# Demo Script — 4 minutes, 16:30

**One sentence pitch:** *"Same storm, different street — this is the first
thing a Wellingtonian opens to see what the weather event means at their
address, with a source and an age on every fact."*

## Fixed demo locations (bookmark both in the browser)

| | A — Coastal | B — Hill suburb |
|---|---|---|
| Place | **Lyall Bay** (south coast) | **Karori** |
| Point | `-41.3286, 174.7947` | `-41.2865, 174.7405` |
| Nearest hub | Lyall Bay Community Centre | Karori Community Centre |
| Expected hazard context | tsunami evacuation zone (colour-coded), coastal inundation (medium/high) | none of the coastal layers — likely stream corridor / none |
| Expected conditions | south-coast gauges, any Kilbirnie/Rongotai-side outages & water faults | Karori Stream gauge, different faults |

Same official warning (if one is active) appears at **both** — that's the
point: the national warning is identical, the *picture* is not.

Rehearse once at 15:30 with live data. If MetService has no active warning for
Wellington today (likely on a calm day), say so out loud — "no warnings
currently cover this point, and the system says exactly that" — honesty about
an empty state is on-message for this problem statement. Screenshot a
warning-rich moment earlier in the day as backup if one appears.

## Minute-by-minute

**0:00–0:30 — Problem.** "When a southerly hits, a Lyall Bay resident
monitors MetService, WCC, WREMO and two Facebook groups. None of them answer
the actual question: *what does this mean on my street?*"

**0:30–1:45 — Location A (Lyall Bay).** Open map (frontend shows all 126
WREMO hubs). Click Lyall Bay.

- Warnings card: the active CAP warning(s) covering this point — severity,
  window, **source chip: MetService, fetched 40 s ago**.
- Local conditions: nearest river/rain gauges with readings and age;
  electricity outages; water faults — each with distance and source.
- Hazard context: "this point is inside the tsunami evacuation zone (Red) and
  medium coastal inundation planning area" — labelled *planning data, not a
  live prediction*.
- Nearest hub + the factual summary block. "Every line is a fact with a
  source. Nothing here tells you what to do — it tells you what *is*."

**1:45–2:45 — Location B (Karori).** Click Karori. Same warning, but: no
coastal layers, different gauges, different faults. "Same storm, different
street. That's location-first."

**2:45–3:30 — It composes.** Show `curl …/v1/picture?lat=…` JSON in a
terminal, then `/v1/hubs?format=geojson` dropped into the shared COP map.
"This isn't a closed demo — it's an API. Any of the other nine prototypes,
or a WREMO screen, can consume the same picture. AGPLv3, so it stays open."

**3:30–4:00 — Honesty features.** Point at: age chips, the
planning-vs-live labelling, the degraded-source state (`status:
"unavailable"` with last-good age — pre-capture a screenshot by pointing one
source at a bad URL), the 111 disclaimer. Close: "Information, not advice.
People decide."

## Judge Q&A — likely questions

- *Community reports?* Deliberately out of v1 (no scraping; verification is
  the hard problem). The `trust` field (`community-unverified`) reserves the
  slot — the pipe is built, the tap is off.
- *Why trust this over Facebook?* Every item carries publisher + timestamp;
  we add nothing and interpret nothing.
- *What if a source dies mid-event?* Show the degraded-state JSON: the rest
  of the picture survives, the gap is labelled with its age.
- *Scale?* Stateless service, per-source cache; the expensive joins
  (point-in-polygon on static layers) are done by the councils' own ArcGIS
  servers.
