#!/usr/bin/env bash
# N2 — GREEN spot-check (validation only). A reference solution per language (ci/solutions/<lang>/)
# is overlaid onto each of that language's kata seeds; the fixed accept must exit 0. This proves the
# accepts are not vacuously-RED (they can still go GREEN). Reference solutions are NEVER shipped into
# red-baseline/ — abproof reads only red-baseline/, so it never sees them. Skips a language whose
# toolchain is absent. Portable to bash 3.2. Run AFTER the fix (the rust seed must be relocated).
#
# Usage: prove-solvable.sh [<corpus-root>]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOL_ROOT="$HERE/solutions"
CORPUS_ROOT="${CORPUS_ROOT:-}"
[[ $# -ge 1 ]] && CORPUS_ROOT="$1"
if [[ -z "$CORPUS_ROOT" ]]; then
  CORPUS_ROOT="$(cd "$HERE/.." && pwd)/red-baseline"
fi
[[ -d "$CORPUS_ROOT" ]] || { echo "corpus root not found: $CORPUS_ROOT" >&2; exit 2; }

fail=0
note() { printf '  %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
# The 24 katas (py-add is not part of the grep fix and ships no reference solution).
CLEAN_GLOB=("$CORPUS_ROOT"/{go,java,python,rust}-0[1-6]-*)

accept_of() { sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p'; }
language_of() { sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$1/meta.yaml" | sed -n '1p'; }
FILES=()
read_files() {
  local line
  line="$(sed -n 's/^files: *\[\(.*\)\].*/\1/p' "$1/meta.yaml" | sed -n '1p')"
  line="${line//,/ }"; line="${line//\"/}"
  FILES=(); read -ra FILES <<< "$line" || true
}
toolchain_ok() {
  case "$1" in
    go)   have go && echo yes || echo no ;;
    rust) have cargo && echo yes || echo no ;;
    java) { have javac && have java; } && echo yes || echo no ;;
    *)    have python3 && echo yes || echo no ;;
  esac
}

# Drift tripwire: exactly 24 katas expected. A node-less/renamed CORPUS_ROOT would otherwise make
# this whole spot-check vacuously PASS. Bump when the kata set deliberately grows.
EXPECTED_KATAS=24
found_katas=0
for node in "${CLEAN_GLOB[@]}"; do [[ -d "$node" ]] && found_katas=$((found_katas + 1)); done
if [[ $found_katas -ne $EXPECTED_KATAS ]]; then
  echo "kata drift: found $found_katas katas, expected $EXPECTED_KATAS (renamed/dropped/added, or wrong CORPUS_ROOT)" >&2
  exit 2
fi

for node in "${CLEAN_GLOB[@]}"; do
  [[ -d "$node" ]] || continue
  lang="$(language_of "$node")"
  if [[ "$(toolchain_ok "$lang")" == no ]]; then
    note "skip $(basename "$node"): $lang toolchain absent"; continue
  fi
  acc="$(accept_of "$node")"
  src="$node/seed"; [[ -d "$src" ]] || src="$node"
  work="$(mktemp -d)"
  cp -R "$src/." "$work/"
  # Overlay the language's reference solution over each editable file.
  read_files "$node"
  missing=0
  [[ ${#FILES[@]} -eq 0 ]] && { note "FAIL $(basename "$node"): node has no files: to solve"; fail=1; rm -rf "$work"; continue; }
  for rel in "${FILES[@]}"; do
    [[ -z "$rel" ]] && continue
    if [[ -f "$SOL_ROOT/$lang/$rel" ]]; then
      cp "$SOL_ROOT/$lang/$rel" "$work/$rel"
    else
      note "FAIL $(basename "$node"): no reference solution at solutions/$lang/$rel"; fail=1; missing=1
    fi
  done
  if [[ $missing -eq 0 ]]; then
    ec=0; ( set +o pipefail; cd "$work" && eval "$acc" >/dev/null 2>&1 ) || ec=$?
    if [[ $ec -ne 0 ]]; then
      note "FAIL $(basename "$node"): solution scored RED (exit $ec) — wrong reference solution or a vacuously-RED accept"; fail=1
    else
      note "ok $(basename "$node"): solution -> GREEN"
    fi
  fi
  rm -rf "$work"
done

if [[ $fail -ne 0 ]]; then
  echo "GREEN spot-check: FAIL" >&2
  exit 1
fi
echo "GREEN spot-check: PASS"
