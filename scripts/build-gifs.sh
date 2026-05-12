#!/usr/bin/env bash
# Generate the 9 Petdex state GIFs from a pet spritesheet.
#
# Usage:
#   scripts/build-gifs.sh <pet-name> [out-dir]
#
# Inputs:
#   pets/<pet-name>/spritesheet.webp   8 cols x 9 rows grid (any pixel size)
#
# Outputs (default: gifs/<pet-name>/):
#   idle.gif running-right.gif running-left.gif waving.gif jumping.gif
#   failed.gif waiting.gif running.gif review.gif
#
# Row -> state mapping and total durations follow the Petdex contract
# (https://github.com/crafter-station/petdex src/lib/pet-states.ts).
# Per-frame timing uses a "last-frame hold" pattern: most frames are short,
# the final frame carries the slack so the loop matches durationMs.

set -euo pipefail

PET="${1:-}"
if [[ -z "$PET" ]]; then
  echo "Usage: $0 <pet-name> [out-dir]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHEET="$ROOT/pets/$PET/spritesheet.webp"
OUT="${2:-$ROOT/gifs/$PET}"

if [[ ! -f "$SHEET" ]]; then
  echo "spritesheet not found: $SHEET" >&2
  exit 1
fi
command -v magick >/dev/null 2>&1 || {
  echo "ImageMagick 'magick' command required (brew install imagemagick)" >&2
  exit 1
}

read -r W H <<<"$(magick identify -format "%w %h" "$SHEET")"
COLS=8
ROWS=9
FW=$(( W / COLS ))
FH=$(( H / ROWS ))
echo "spritesheet: ${W}x${H}  frame: ${FW}x${FH}  grid: ${COLS}x${ROWS}"

mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# name           row frames short_cs last_cs   total(ms) source: pet-states.ts
STATES=(
  "idle           0 6 11 55"
  "running-right  1 8 12 22"
  "running-left   2 8 12 22"
  "waving         3 4 15 25"
  "jumping        4 5 17 16"
  "failed         5 8 15 17"
  "waiting        6 6 15 26"
  "running        7 6 12 22"
  "review         8 6 15 28"
)

for entry in "${STATES[@]}"; do
  read -r name row n short last <<<"$entry"
  y=$(( row * FH ))
  args=(-loop 0 -dispose previous)
  last_idx=$(( n - 1 ))
  for (( c=0; c<n; c++ )); do
    x=$(( c * FW ))
    frame="$TMP/${name}_${c}.png"
    magick "$SHEET" -crop "${FW}x${FH}+${x}+${y}" +repage "$frame"
    if (( c == last_idx )); then
      args+=( -delay "$last" "$frame" )
    else
      args+=( -delay "$short" "$frame" )
    fi
  done
  magick "${args[@]}" "$OUT/${name}.gif"
  echo "  wrote $OUT/${name}.gif"
done

echo "done -> $OUT"
