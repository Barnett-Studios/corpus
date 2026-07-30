#!/usr/bin/env bash
# CI invariant for issue #7 — the accept oracle must resist ADVERSARIAL in-process sabotage,
# not just the incidental exit-code gaming closed by #4.
#
# The threat: a model edits ONLY its allowed `files:` and, instead of solving the task, makes
# the acceptance run report success. Two vectors, both requiring nothing but the edit rights
# the node already grants:
#
#   exit-zero  model code terminates the test process with status 0 before assertions run
#   neuter     model code replaces the assertion machinery with no-ops
#
# Both work whenever the model's code and the assertions share one process. `go test` already
# resists, because it is a supervising PARENT that requires positive evidence of completion
# from its child test binary — that is the property this check holds every language to.
#
# For each clean-subset node and each sabotage fixture for its language: materialize the seed,
# overwrite the editable file, run the node's own `accept`, and require a NON-ZERO exit. A
# GREEN score here is an oracle that certifies unsolved work.
#
# Usage: verify-oracle-sabotage.sh [<corpus-root>]  (defaults to $CORPUS_ROOT, else the repo's
# own red-baseline/ resolved relative to this script). Portable to bash 3.2 (no mapfile).
# A language whose toolchain is absent is skipped (fail-open, mirroring verify-accept-oracle.sh).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS_ROOT="${CORPUS_ROOT:-}"
[[ $# -ge 1 ]] && CORPUS_ROOT="$1"
if [[ -z "$CORPUS_ROOT" ]]; then
  CORPUS_ROOT="$(cd "$HERE/.." && pwd)/red-baseline"
fi
if [[ ! -d "$CORPUS_ROOT" ]]; then
  echo "corpus root not found: $CORPUS_ROOT (set \$CORPUS_ROOT or pass it as an arg)" >&2
  exit 2
fi
SABOTAGE="$HERE/sabotage"
[[ -d "$SABOTAGE" ]] || { echo "sabotage fixtures not found: $SABOTAGE" >&2; exit 2; }

fail=0
note() { printf '  %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

CLEAN_GLOB=("$CORPUS_ROOT"/{go,java,python,rust}-0[1-6]-* "$CORPUS_ROOT"/py-add)

accept_of()   { sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p'; }
language_of() { sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$1/meta.yaml" | sed -n '1p'; }

toolchain_ok() {
  case "$1" in
    go)     have go && echo yes || echo no ;;
    rust)   have cargo && echo yes || echo no ;;
    java)   { have javac && have java; } && echo yes || echo no ;;
    *)      have python3 && echo yes || echo no ;;
  esac
}

# files: ["a", "b"]  ->  bash array FILES (bash-3.2 safe; mirrors verify-accept-oracle.sh).
# The sabotage targets are read from each node's OWN `files:` rather than hardcoded per
# language: py-add is python but edits calc.py, and a hardcoded util.py silently skipped it
# while reporting PASS.
FILES=()
read_files() {
  local line
  line="$(sed -n 's/^files: *\[\(.*\)\].*/\1/p' "$1/meta.yaml" | sed -n '1p')"
  line="${line//,/ }"
  line="${line//\"/}"
  FILES=()
  read -ra FILES <<< "$line" || true
}

# Same drift tripwire as verify-accept-oracle.sh: a node-less CORPUS_ROOT would otherwise let
# every check below pass vacuously — a sabotage suite that runs zero sabotages reports PASS.
EXPECTED_CLEAN=25
found_clean=0
for node in "${CLEAN_GLOB[@]}"; do [[ -d "$node" ]] && found_clean=$((found_clean + 1)); done
if [[ $found_clean -ne $EXPECTED_CLEAN ]]; then
  echo "clean-subset drift: found $found_clean nodes, expected $EXPECTED_CLEAN" >&2
  exit 2
fi

echo "== check E: no sabotage of an editable file scores GREEN =="
ran=0
for node in "${CLEAN_GLOB[@]}"; do
  [[ -d "$node" ]] || continue
  name="$(basename "$node")"
  lang="$(language_of "$node")"
  [[ -d "$SABOTAGE/$lang" ]] || continue
  if [[ "$(toolchain_ok "$lang")" == no ]]; then
    note "skip $name: $lang toolchain absent"; continue
  fi
  acc="$(accept_of "$node")"
  src="$node/seed"; [[ -d "$src" ]] || src="$node"
  read_files "$node"
  [[ ${#FILES[@]} -eq 0 ]] && { note "FAIL $name: node declares no files: to sabotage"; fail=1; continue; }

  for variant_dir in "$SABOTAGE/$lang"/*; do
    [[ -d "$variant_dir" ]] || continue
    variant="$(basename "$variant_dir")"
    work="$(mktemp -d)"
    cp -R "$src/." "$work/"
    applied=0
    for rel in "${FILES[@]}"; do
      [[ -z "$rel" ]] && continue
      fixture="$variant_dir/$(basename "$rel")"
      if [[ -f "$fixture" ]]; then
        mkdir -p "$(dirname "$work/$rel")"
        cp "$fixture" "$work/$rel"
        applied=$((applied + 1))
      fi
    done
    if [[ $applied -eq 0 ]]; then
      rm -rf "$work"
      note "skip $name [$variant]: no fixture for this node's editable files"
      continue
    fi
    ec=0
    ( set +o pipefail; cd "$work" && eval "$acc" >/dev/null 2>&1 ) || ec=$?
    rm -rf "$work"
    ran=$((ran + 1))
    if [[ $ec -eq 0 ]]; then
      note "FAIL $name [$variant]: sabotaged editable file(s) scored GREEN (exit 0) while unsolved"
      fail=1
    fi
  done
done

if [[ $ran -eq 0 ]]; then
  echo "no sabotage cases ran (every toolchain absent?) — refusing to report PASS" >&2
  exit 2
fi
[[ $fail -eq 0 ]] && note "ok: all $ran sabotage cases scored RED"

if [[ $fail -ne 0 ]]; then
  echo "oracle-sabotage invariant: FAIL" >&2
  exit 1
fi
echo "oracle-sabotage invariant: PASS ($ran cases)"
