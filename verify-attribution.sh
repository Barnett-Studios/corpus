#!/usr/bin/env bash
# Regenerate MANIFEST.tsv from the corpus node data, or (--check) verify the
# committed manifest still matches the data — so attribution can never silently
# drift from what is actually shipped.
#
# Usage:
#   verify-attribution.sh [--check] [<corpus-root>]
# <corpus-root> defaults to $CORPUS_ROOT, else ../../measurement/corpus/red-baseline
# relative to this script (the in-monorepo location before the data is git-mv'd).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0
CORPUS_ROOT="${CORPUS_ROOT:-}"

for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    *) CORPUS_ROOT="$arg" ;;
  esac
done
if [[ -z "$CORPUS_ROOT" ]]; then
  CORPUS_ROOT="$HERE/red-baseline"
fi
if [[ ! -d "$CORPUS_ROOT" ]]; then
  echo "corpus root not found: $CORPUS_ROOT (set \$CORPUS_ROOT or pass it as an arg)" >&2
  exit 2
fi

generate() {
  printf 'node_id\tlanguage\taccept_tool\tseed_license\tthird_party\n'
  for d in "$CORPUS_ROOT"/*/; do
    local id lang req lic tp
    id=$(basename "$d")
    # A node without a readable meta.yaml is malformed — warn and skip it rather than
    # let a failing sed under `set -o pipefail` abort mid-generation (which, if we wrote
    # straight to the tracked file, would truncate it). Skipping keeps generation total.
    if [[ ! -r "$d/meta.yaml" ]]; then
      echo "warning: $id has no readable meta.yaml — skipped" >&2
      continue
    fi
    # requires: assumes at most one tool per node (true for the current corpus); a
    # multi-tool node would collapse "a", "b" to a,b — revisit the extraction if that changes.
    lang=$(sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}/\1/p' "$d/meta.yaml" 2>/dev/null | head -1)
    req=$(sed -n 's/.*requires: *\[\(.*\)\].*/\1/p' "$d/meta.yaml" 2>/dev/null | head -1 | tr -d '"[:space:]')
    [[ -z "$req" ]] && req="-"
    lic="none"; [[ -f "$d/seed/LICENSE" ]] && lic="MIT(Exercism)"
    tp=""
    [[ -n "$(find "$d" -name catch.hpp 2>/dev/null)" ]] && tp="Catch2/BSL-1.0"
    [[ -n "$(find "$d" -name gradlew 2>/dev/null)" ]] && tp="${tp:+$tp,}Gradle-wrapper/Apache-2.0"
    [[ -z "$tp" ]] && tp="-"
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$lang" "$req" "$lic" "$tp"
  done
}

if [[ "$CHECK" == "1" ]]; then
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  generate > "$tmp"
  if ! diff -u "$HERE/MANIFEST.tsv" "$tmp"; then
    echo "MANIFEST.tsv is stale — attribution drifted from the corpus data. Regenerate." >&2
    exit 1
  fi
  echo "MANIFEST.tsv matches the corpus data ($(($(wc -l < "$HERE/MANIFEST.tsv") - 1)) nodes)."
else
  # Write to a temp then atomically rename, so a mid-generation failure never leaves the
  # tracked MANIFEST.tsv truncated.
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  generate > "$tmp"
  mv "$tmp" "$HERE/MANIFEST.tsv"
  echo "wrote MANIFEST.tsv ($(($(wc -l < "$HERE/MANIFEST.tsv") - 1)) nodes)"
fi
