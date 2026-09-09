#!/usr/bin/env bash
# Byte Eater — atlas slicer.
# Splits assets/byte-eater-atlas.png (4 cols x 6 rows of 256px cells) into
# per-frame transparent PNGs: alpha-trimmed, aspect-fitted to 52x56 and
# centered on a 64x64 canvas (one maze tile).
#
# Usage: assets/slice.sh [atlas.png]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ATLAS="${1:-$ROOT/assets/byte-eater-atlas.png}"
OUT="$ROOT/assets/sprites"
mkdir -p "$OUT"

CELL=256
# name row col   -- (r,c) grid cell -> sprite file
mapfile -t MAP <<'EOF'
player_run_0 0 0
player_run_1 0 1
player_run_2 0 2
player_run_3 0 3
player_alt_0 1 0
player_alt_1 1 1
player_alt_2 1 2
player_alt_3 1 3
player_byte_0 2 0
player_byte_1 2 1
player_byte_2 2 2
player_byte_3 2 3
bug_blue_0 3 0
bug_blue_1 3 1
bug_blue_2 3 2
bug_blue_3 3 3
bug_pink_0 4 0
bug_pink_1 4 1
bug_orange_0 4 2
bug_orange_1 4 3
player_zzz_0 5 0
player_zzz_1 5 1
player_zzz_2 5 2
player_zzz_3 5 3
EOF

for entry in "${MAP[@]}"; do
    read -r name r c <<< "$entry"
    x=$((c * CELL)); y=$((r * CELL))
    # -trim on a transparent PNG trims to the opaque bbox
    magick "$ATLAS" -crop "${CELL}x${CELL}+${x}+${y}" +repage \
        -trim +repage \
        -resize '52x56>' \
        -gravity center -background none -extent 64x64 \
        -define png:color-type=6 "$OUT/$name.png"
done

echo "sliced $(ls "$OUT" | wc -l) sprites into $OUT"
