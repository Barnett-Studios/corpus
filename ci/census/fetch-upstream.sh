#!/usr/bin/env bash
# Fetch Exercism's canonical example solutions for the 225 Exercism-derived nodes, so
# `prove-solvable.sh` can be extended beyond the 24 katas without authoring anything.
#
# Blobless clones (--filter=blob:none) so we pay for the tree, not for every blob in
# history. These land in the SCRATCHPAD, never in the corpus repo.
set -uo pipefail
CENSUS_WORK="${CENSUS_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.census-work}"
U="$CENSUS_WORK/upstream"
mkdir -p "$U"

for track in cpp go java javascript python rust; do
  d="$U/$track"
  if [ -d "$d/.git" ]; then echo "have $track"; continue; fi
  echo "cloning $track ..."
  git clone -q --filter=blob:none --depth 1 "https://github.com/exercism/$track.git" "$d" \
    && echo "  ok $track" || echo "  FAILED $track"
done

echo
echo "=== where each track keeps its example solution ==="
for track in cpp go java javascript python rust; do
  d="$U/$track"
  [ -d "$d" ] || continue
  slug="$(find "$d/exercises/practice" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)"
  [ -z "$slug" ] && { echo "$track: no exercises/practice"; continue; }
  echo "--- $track  (sample: $(basename "$slug")) ---"
  find "$slug/.meta" -type f 2>/dev/null | sed "s|$slug/|   |" | head -8
done
