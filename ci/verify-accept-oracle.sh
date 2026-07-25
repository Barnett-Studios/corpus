#!/usr/bin/env bash
# CI invariant for issue #4 — the clean-subset accept oracle honors the runner's exit code, and no
# acceptance test lives in an editable (`files:`) file. See docs/adrs/0001-green-is-runner-exit-zero.md.
#
# Four checks (any failure => non-zero exit):
#   A  static      no clean-subset accept pipes into grep       (RED-first #1: fails until #4's fix)
#   D  structural  no editable (`files:`) file contains a test  (RED-first #2: fails for rust until relocated)
#   B  behavioral  the pipe-discard mechanism the invariant defends against, reproduced
#   C  RED-invariant  each clean-subset seed scores non-zero, incl. rust with its editable file emptied
# B and C skip a language whose toolchain is absent (fail-open, mirroring `requires`).
#
# Usage: verify-accept-oracle.sh [<corpus-root>]   (<corpus-root> defaults to $CORPUS_ROOT, else the
# repo's own red-baseline/ resolved relative to this script). Portable to bash 3.2 (no mapfile).

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

fail=0
note() { printf '  %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# The clean subset: the 24 hand-authored katas + py-add. A brace pattern that matches nothing
# stays literal, so the `-d` guard skips it.
CLEAN_GLOB=("$CORPUS_ROOT"/{go,java,python,rust}-0[1-6]-* "$CORPUS_ROOT"/py-add)

# accept: "..."  ->  the command string (clean-subset accepts are single-line, double-quoted).
accept_of() { sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p'; }
language_of() { sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$1/meta.yaml" | sed -n '1p'; }
# files: ["a", "b"]  ->  bash array FILES (no nested process-substitution; bash-3.2 safe).
FILES=()
read_files() {
  local line
  line="$(sed -n 's/^files: *\[\(.*\)\].*/\1/p' "$1/meta.yaml" | sed -n '1p')"
  line="${line//,/ }"
  line="${line//\"/}"
  FILES=()
  read -ra FILES <<< "$line" || true
}
# Resolve an editable file to its on-disk path (seed/ layout, else legacy flat).
resolve_file() {
  local node="$1" rel="$2"
  if [[ -f "$node/seed/$rel" ]]; then printf '%s\n' "$node/seed/$rel"
  elif [[ -f "$node/$rel" ]]; then printf '%s\n' "$node/$rel"
  fi
}
# A test-definition marker for the given language, or empty if we don't gate that language here.
# Whitespace-tolerant (`#[ test ]` is a valid rust test); [[:space:]] not \s, for BSD+GNU grep -E.
test_marker() {
  case "$1" in
    rust)   printf '%s' '#\[[[:space:]]*test[[:space:]]*\]|#\[[[:space:]]*cfg[[:space:]]*\([[:space:]]*test' ;;
    go)     printf '%s' 'func (Test|Example|Benchmark)' ;;
    python) printf '%s' 'def test|import unittest|from unittest|import pytest' ;;
    java)   printf '%s' '@Test|class TestRunner' ;;
    *)      printf '%s' '' ;;
  esac
}
# Is a language's toolchain present? (echoes "yes"/"no")
toolchain_ok() {
  case "$1" in
    go)     have go && echo yes || echo no ;;
    rust)   have cargo && echo yes || echo no ;;
    java)   { have javac && have java; } && echo yes || echo no ;;
    *)      have python3 && echo yes || echo no ;;
  esac
}

# Drift tripwire: the clean subset is a fixed size (24 katas + py-add). A renamed/dropped node or a
# node-less CORPUS_ROOT would otherwise let every corpus check pass vacuously. Bump when the subset
# deliberately grows (a visible, deliberate change).
EXPECTED_CLEAN=25
found_clean=0
for node in "${CLEAN_GLOB[@]}"; do [[ -d "$node" ]] && found_clean=$((found_clean + 1)); done
if [[ $found_clean -ne $EXPECTED_CLEAN ]]; then
  echo "clean-subset drift: found $found_clean nodes, expected $EXPECTED_CLEAN (renamed/dropped/added node, or wrong CORPUS_ROOT)" >&2
  exit 2
fi

echo "== check A: no clean-subset accept pipes its runner (a pipe discards its exit code) =="
a_fail=0
for node in "${CLEAN_GLOB[@]}"; do
  [[ -d "$node" ]] || continue
  acc="$(accept_of "$node")"
  # A pipe makes the pipeline's status the LAST command's, not the runner's — the exact defect,
  # for grep OR rg/awk/perl/sed/etc. The clean-subset accepts are bare runners or `&&`-chains,
  # never piped, so any `|` is the anti-pattern.
  if [[ "$acc" == *"|"* ]]; then
    note "FAIL $(basename "$node"): accept pipes its runner (exit code discarded) -> $acc"; fail=1; a_fail=1
  fi
done
[[ $a_fail -eq 0 ]] && note "ok: no accept pipes its runner"

echo "== check D: no editable (files:) file contains its acceptance test =="
d_fail=0
for node in "${CLEAN_GLOB[@]}"; do
  [[ -d "$node" ]] || continue
  lang="$(language_of "$node")"
  marker="$(test_marker "$lang")"
  [[ -z "$marker" ]] && continue
  read_files "$node"
  [[ ${#FILES[@]} -eq 0 ]] && continue  # bash-3.2 set -u: never expand an empty array
  for rel in "${FILES[@]}"; do
    [[ -z "$rel" ]] && continue
    path="$(resolve_file "$node" "$rel")"
    [[ -z "$path" ]] && continue
    if grep -Eq "$marker" "$path"; then
      note "FAIL $(basename "$node"): editable $rel contains a test ($lang marker)"; fail=1; d_fail=1
    fi
  done
done
[[ $d_fail -eq 0 ]] && note "ok: no editable file contains its acceptance test"

echo "== check B: the pipe-discard mechanism the invariant forbids =="
# The katas' accepts run as a plain command (no `set -o pipefail`), so a pipe returns the RIGHTMOST
# command's status. These demos disable pipefail to emulate that context — which is itself the proof
# that pipefail would have masked the bug.
fooling_runner() { echo "FAIL: 1 failed, 3 passed"; return 1; }
piped=0; ( set +o pipefail; fooling_runner 2>/dev/null | grep -qE '[1-9]+ passed' ) || piped=$?
bare=0; fooling_runner >/dev/null 2>&1 || bare=$?
if [[ $piped -eq 0 && $bare -ne 0 ]]; then
  note "ok: piped 'grep -q passed' scores a failing runner GREEN (0); bare runner is RED ($bare)"
else
  note "FAIL: pipe-discard mechanism did not reproduce (piped=$piped bare=$bare)"; fail=1
fi
if have cargo; then
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/src" "$tmp/tests"
  printf 'pub fn ok() -> bool { true }\n#[cfg(test)]\nmod t { #[test] fn test_x_unit() { assert!(super::ok()); } }\n' > "$tmp/src/lib.rs"
  printf '#[test] fn test_x_integration() { assert_eq!(1, 2); }\n' > "$tmp/tests/it.rs"
  printf '[package]\nname = "fool"\nversion = "0.0.0"\nedition = "2021"\n' > "$tmp/Cargo.toml"
  old=0; ( set +o pipefail; cd "$tmp" && cargo test test_x --quiet 2>&1 | grep -qE 'test result: ok\. [1-9]' ) || old=$?
  new=0; ( cd "$tmp" && cargo test test_x --quiet >/dev/null 2>&1 ) || new=$?
  rm -rf "$tmp"
  if [[ $old -eq 0 && $new -ne 0 ]]; then
    note "ok: cargo multi-binary — old grep GREEN (matched passing binary's ok line), bare RED ($new)"
  else
    note "FAIL: cargo multi-binary reproduction unexpected (old=$old new=$new)"; fail=1
  fi
else
  note "skip: cargo absent"
fi

echo "== check C: every clean-subset seed scores non-zero (RED) under its accept =="
c_fail=0
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
  ec=0; ( set +o pipefail; cd "$work" && eval "$acc" >/dev/null 2>&1 ) || ec=$?
  if [[ $ec -eq 0 ]]; then
    note "FAIL $(basename "$node"): seed scored GREEN (exit 0) — not RED"; fail=1; c_fail=1
  fi
  if [[ "$lang" == rust ]]; then
    read_files "$node"
    [[ ${#FILES[@]} -eq 0 ]] || for rel in "${FILES[@]}"; do
      [[ -n "$rel" && -f "$work/$rel" ]] && : > "$work/$rel"
    done
    ec2=0; ( set +o pipefail; cd "$work" && eval "$acc" >/dev/null 2>&1 ) || ec2=$?
    if [[ $ec2 -eq 0 ]]; then
      note "FAIL $(basename "$node"): emptied editable file scored GREEN — test is deletable"; fail=1; c_fail=1
    fi
  fi
  rm -rf "$work"
done
[[ $c_fail -eq 0 ]] && note "ok: all seeds RED (and rust survives an emptied editable file)"

if [[ $fail -ne 0 ]]; then
  echo "accept-oracle invariant: FAIL" >&2
  exit 1
fi
echo "accept-oracle invariant: PASS"
