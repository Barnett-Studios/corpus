#!/usr/bin/env bash
# corpus census — stage 1: RUN.
#
# For every node, run its accept against a pristine copy of the seed in TWO forms and
# save the full output. Classification happens offline (stage 2) so a re-classification
# never costs a re-run.
#
#   shipped : the accept exactly as meta.yaml ships it (grep-on-output for 222 nodes)
#   exit    : the same runner with the success-substring filter stripped — the #15 form
#
# cpp additionally gets the CMakeLists work-dir-name repair applied in the `exit` arm,
# because without it cmake never configures and the node is RED for an environmental
# reason (corpus#14 / Phase 0).
#
# Usage: sweep.sh <language> [<outdir>]
set -uo pipefail
# Paths: CENSUS_WORK holds the run artefacts (sweep logs, green-proof logs, upstream
# track clones). It defaults to .census-work/ beside the repo, so nothing lands in the
# repo tree. CORPUS_ROOT defaults to the repo's own red-baseline/.
CENSUS_WORK="${CENSUS_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.census-work}"
CORPUS_ROOT="${CORPUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/red-baseline}"
mkdir -p "$CENSUS_WORK"

# APPEND homebrew, never prepend: prepending shadows mise's python3/node/go with a
# homebrew build that has no pytest, and every node then goes RED because the runner
# never started — the exact defect this census exists to detect (Phase 0's lesson).
export PATH="$PATH:/opt/homebrew/bin"

CORPUS="$CORPUS_ROOT"
LANG_FILTER="${1:?usage: sweep.sh <language> [outdir]}"
OUT="${2:-$CENSUS_WORK/census-runs}"
TIMEOUT_S="${ACCEPT_TIMEOUT:-600}"

mkdir -p "$OUT/$LANG_FILTER"

# ── preflight ────────────────────────────────────────────────────────────────
# A sweep whose runner is missing reports every node RED and looks like a finding.
# Assert the runner works BEFORE measuring anything; die loudly if it does not.
preflight() {
  case "$1" in
    python)     python3 -m pytest --version  >/dev/null 2>&1 || return 1
                python3 -m unittest --help   >/dev/null 2>&1 || return 1 ;;
    go)         go version                   >/dev/null 2>&1 || return 1 ;;
    rust)       cargo --version              >/dev/null 2>&1 || return 1 ;;
    java)       gradle --version             >/dev/null 2>&1 || return 1 ;;
    javascript) npm --version                >/dev/null 2>&1 || return 1 ;;
    cpp)        cmake --version              >/dev/null 2>&1 || return 1 ;;
  esac
  return 0
}
if ! preflight "$LANG_FILTER"; then
  echo "PREFLIGHT FAIL ($LANG_FILTER): the runner is not usable on this host." >&2
  echo "Refusing to sweep — every node would report RED for an environmental reason." >&2
  exit 2
fi
echo "preflight ok: $LANG_FILTER"

accept_of() {
  sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p' \
    | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}
language_of() { sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$1/meta.yaml" | sed -n '1p'; }

# Strip the trailing success-substring filter: everything up to the last `2>&1 |`.
# cpp also loses the `&& ctest --test-dir build` leg (no node registers a ctest test,
# so that leg can never succeed — see Phase 0).
exit_form() {
  local acc="$1" lang="$2" base
  base="${acc%% 2>&1 |*}"
  if [ "$lang" = cpp ]; then
    base="${base%% && ctest*}"
    base="cmake -S . -B build && cmake --build build"
  fi
  # drop the >/dev/null redirections so stage 2 can see what happened
  base="${base//>\/dev\/null 2>&1/}"
  printf '%s' "$base"
}

run_one() {
  local node="$1" acc="$2" tag="$3" repair="$4" ex="$5"
  local work rc start end
  work="$(mktemp -d)"
  cp -R "$node/seed/." "$work/" 2>/dev/null || cp -R "$node/." "$work/"
  if [ "$repair" = yes ]; then
    perl -pi -e "s|^get_filename_component\(exercise .*\$|set(exercise \"$ex\")|" "$work/CMakeLists.txt" 2>/dev/null
  fi
  start="$(date +%s)"
  ( set +o pipefail; cd "$work" && timeout "$TIMEOUT_S" bash -c "$acc" ) >"$OUT/$LANG_FILTER/$(basename "$node").$tag.log" 2>&1
  rc=$?
  end="$(date +%s)"
  rm -rf "$work"
  printf '%s\t%s\n' "$rc" "$((end - start))"
}

for node in "$CORPUS"/*; do
  [ -d "$node" ] || continue
  [ -f "$node/meta.yaml" ] || continue
  lang="$(language_of "$node")"
  [ "$lang" = "$LANG_FILTER" ] || continue
  base="$(basename "$node")"
  # Resume: a node already recorded is not re-run. gradle/npm strata take ~1 min/node and
  # an interrupted sweep must not start over.
  if [ -f "$OUT/$LANG_FILTER.tsv" ] && cut -f1 "$OUT/$LANG_FILTER.tsv" | grep -qx "$base"; then
    continue
  fi
  acc="$(accept_of "$node")"
  exf="$(exit_form "$acc" "$lang")"
  rep=no; ex=""
  if [ "$lang" = cpp ]; then rep=yes; ex="${base#cpp-}"; fi

  s="$(run_one "$node" "$acc" shipped no "")"
  e="$(run_one "$node" "$exf" exit "$rep" "$ex")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$base" "$lang" "$s" "$e" "$exf" >> "$OUT/$LANG_FILTER.tsv"
  printf '%-40s shipped=%s exit=%s\n' "$base" "${s%%$'\t'*}" "${e%%$'\t'*}"
done

echo "DONE $LANG_FILTER"
