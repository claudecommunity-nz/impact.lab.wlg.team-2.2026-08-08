#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# test-snapshot.sh — run the full demo-day test checklist against a running
# Location Picture server, save every response as a fixture-ready JSON
# snapshot, and print a pass/fail summary.
#
# Usage:
#   bash scripts/test-snapshot.sh                 # default localhost:8080
#   bash scripts/test-snapshot.sh http://localhost:8081
#
# Output: scripts/fixtures/snapshots/<timestamp>/*.json (+ symlink latest)
# Snapshots are gitignored — do not commit them.
# Requires: curl, jq

set -u
BASE="${1:-http://localhost:8080}"

# Fixed demo points
LAT_A=-41.3286; LNG_A=174.7947   # A — Lyall Bay
LAT_B=-41.2865; LNG_B=174.7405   # B — Karori

STAMP="$(date +%Y%m%d-%H%M%S)"
DIR="scripts/fixtures/snapshots/$STAMP"
mkdir -p "$DIR"
rm -f scripts/fixtures/snapshots/latest
ln -s "$STAMP" scripts/fixtures/snapshots/latest 2>/dev/null || true

PASS=0; FAIL=0; SKIP=0
declare -a RESULTS=()

note()  { printf '   %s\n' "$1"; }

# fetch <name> <url>  → saves $DIR/<name>.json, returns curl status
fetch() {
  local name="$1" url="$2"
  local http
  http=$(curl -s -o "$DIR/$name.json" -w '%{http_code}' --max-time 20 "$url")
  echo "$http"
}

# check <name> <url> <jq-assert> <label>
#   jq-assert must evaluate to true/false against the saved body.
#   404 → SKIP (endpoint not built yet), anything else non-200 → FAIL.
check() {
  local name="$1" url="$2" assert="$3" label="$4"
  local http ok
  http=$(fetch "$name" "$url")
  if [ "$http" = "404" ]; then
    RESULTS+=("SKIP  $label (404 — not built yet)")
    SKIP=$((SKIP+1)); return
  fi
  if [ "$http" != "200" ]; then
    RESULTS+=("FAIL  $label (HTTP $http)")
    FAIL=$((FAIL+1)); return
  fi
  ok=$(jq -e "$assert" "$DIR/$name.json" >/dev/null 2>&1 && echo yes || echo no)
  if [ "$ok" = "yes" ]; then
    RESULTS+=("PASS  $label")
    PASS=$((PASS+1))
  else
    RESULTS+=("FAIL  $label (assert: $assert)")
    FAIL=$((FAIL+1))
  fi
}

echo "── Location Picture test snapshot ─ $BASE ─ $STAMP"
echo

# 0. Server up?
if [ "$(fetch healthz "$BASE/healthz")" != "200" ]; then
  echo "FATAL: $BASE/healthz not answering. Is the server running (swift run App)?"
  exit 1
fi
echo "healthz ok"

# 1. Picture (highest priority — may 404 until G5)
check picture-lyall "$BASE/v1/picture?lat=$LAT_A&lng=$LNG_A" \
  '.generatedAt and .sources and (.summary|type=="array")' \
  "picture A (Lyall Bay): has generatedAt + sources + summary"
check picture-karori "$BASE/v1/picture?lat=$LAT_B&lng=$LNG_B" \
  '.generatedAt and .sources' \
  "picture B (Karori): has generatedAt + sources"

# No-advice-words guard on summaries (only if picture exists)
if [ -s "$DIR/picture-lyall.json" ] && jq -e '.summary' "$DIR/picture-lyall.json" >/dev/null 2>&1; then
  if jq -r '.summary[]?' "$DIR/picture-lyall.json" "$DIR/picture-karori.json" 2>/dev/null \
      | grep -Eiq '\b(should|must|evacuate|immediately|unsafe)\b'; then
    RESULTS+=("FAIL  summary contains advice words (banned list)"); FAIL=$((FAIL+1))
  else
    RESULTS+=("PASS  summary is advice-free"); PASS=$((PASS+1))
  fi
fi

# 2a. Warnings
check warnings-lyall "$BASE/v1/warnings?lat=$LAT_A&lng=$LNG_A" \
  '.count == (.items|length)' \
  "warnings A: envelope consistent (empty is OK)"
check warnings-karori "$BASE/v1/warnings?lat=$LAT_B&lng=$LNG_B" \
  '.count == (.items|length)' \
  "warnings B: envelope consistent"
check warnings-nz "$BASE/v1/warnings" \
  '(.items|length) as $n | .count == $n' \
  "warnings NZ-wide: envelope consistent"
# Schema spot-check on first NZ-wide item, if any
if jq -e '.items[0]' "$DIR/warnings-nz.json" >/dev/null 2>&1; then
  check warnings-nz-schema "$BASE/v1/warnings" \
    '.items[0] | has("id") and has("event") and (.source|has("fetchedAt") and has("trust"))' \
    "warnings item schema: id+event+source.fetchedAt+trust"
fi

# 2b. Hazards (may 404 until G4) — the A/B contrast
check hazards-lyall "$BASE/v1/hazards?lat=$LAT_A&lng=$LNG_A" \
  '(.items|length) >= 1' \
  "hazards A: Lyall Bay inside >=1 planning layer"
check hazards-karori "$BASE/v1/hazards?lat=$LAT_B&lng=$LNG_B" \
  '.items|type=="array"' \
  "hazards B: responds with items array (expect fewer/none vs A)"
# Explicit contrast check when both exist
if jq -e . "$DIR/hazards-lyall.json" >/dev/null 2>&1 && jq -e . "$DIR/hazards-karori.json" >/dev/null 2>&1; then
  A=$(jq '.items|length' "$DIR/hazards-lyall.json" 2>/dev/null || echo 0)
  B=$(jq '.items|length' "$DIR/hazards-karori.json" 2>/dev/null || echo 0)
  note "hazard layers — Lyall Bay: $A, Karori: $B (demo contrast wants A > B)"
fi

# 2c. Conditions
check conditions-lyall "$BASE/v1/conditions?lat=$LAT_A&lng=$LNG_A&n=5" \
  '(.gauges|length) >= 1 and (.gauges[0]|has("units") and has("distanceKm") and has("observedAt"))' \
  "conditions A: >=1 gauge with units+distance+observedAt"
check conditions-karori "$BASE/v1/conditions?lat=$LAT_B&lng=$LNG_B&n=5" \
  '(.gauges|type=="array")' \
  "conditions B: gauges array present"
# Noise gauge: how many water faults are we sending?
if jq -e . "$DIR/conditions-lyall.json" >/dev/null 2>&1; then
  WF=$(jq '.waterFaults|length' "$DIR/conditions-lyall.json" 2>/dev/null || echo '?')
  note "water faults near A: $WF (demo wants <= ~15; hundreds = filter not landed)"
fi

# 2d. Hubs
check hubs "$BASE/v1/hubs" \
  '.count == 126 and (.items|length) == 126' \
  "hubs: exactly 126 with envelope"

# 3. GeoJSON exports for the map / geojson.io
fetch hubs-geojson "$BASE/v1/hubs?format=geojson" >/dev/null
fetch warnings-geojson "$BASE/v1/warnings?format=geojson" >/dev/null
note "geojson exports saved (hubs-geojson.json, warnings-geojson.json — drag into geojson.io)"

# 4. Live-warning representative points + PIP round-trip
#    (self-verifying: a point computed from a polygon must hit that polygon;
#     a miss on a multi-ring feature = the multipart PIP bug.)
if jq -e '.features[0]' "$DIR/warnings-geojson.json" >/dev/null 2>&1; then
  echo
  echo "── live warning round-trips (PIP self-test)"
  jq -r '.features[] | [
      .properties.event,
      ([.geometry.coordinates[0][][1]] | add/length),
      ([.geometry.coordinates[0][][0]] | add/length)
    ] | @tsv' "$DIR/warnings-geojson.json" |
  while IFS=$'\t' read -r ev lat lng; do
    HIT=$(curl -s --max-time 20 "$BASE/v1/warnings?lat=$lat&lng=$lng" | jq '.count' 2>/dev/null || echo 0)
    if [ "${HIT:-0}" -ge 1 ]; then
      echo "PASS  round-trip: '$ev' @ $lat,$lng → found"
    else
      echo "FAIL  round-trip: '$ev' @ $lat,$lng → MISSED (multipart PIP bug or concave centroid)"
    fi
  done
fi

echo
echo "── results"
for r in "${RESULTS[@]}"; do echo "$r"; done
echo
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP  → snapshots in $DIR"
echo "Fixture-ready: every .json in that folder mirrors live field names exactly."
