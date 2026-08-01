#!/usr/bin/env bash
# corpus#3 — the RED invariant. Every node ships FAILING: `accept` must exit non-zero
# against the untouched seed. A node that has drifted to GREEN is a corpus bug, and a
# silent one: it inflates every downstream solve-rate, because a harness change is scored
# by how often it turns RED into GREEN and a pre-GREEN node is a free point for both arms.
#
# This is the complement of `prove-solvable.sh`, which proves the accepts are not
# vacuously RED (a reference solution can still reach GREEN). Together they bracket the
# oracle: RED on the seed, GREEN on a solution. Neither alone is sufficient — an accept
# that always fails passes this check, and an accept that always succeeds passes that one.
#
# Fail-open per node on toolchain, per CONTRACT: a node whose `requires:` executables are
# absent is SKIPPED, never failed. Fail-LOUD on vacuity: if nothing was actually checked,
# or the node count has drifted, exit non-zero rather than report a green sweep over
# nothing.
#
# WHAT A PASS HERE DOES NOT MEAN. This checks only that `accept` exits non-zero on the
# seed. It cannot tell "RED because the stub is unimplemented" (the invariant) from "RED
# because the toolchain never reached the tests" — a cmake configure that fails, a missing
# compiler, an npm install with no network. A node that is broken-unsolvable passes this
# check. Solvability is `prove-solvable.sh`'s job, and that covers only the 25-node clean
# subset, so the 225 Exercism nodes have their RED verified and their GREEN-reachability
# NOT. Observed evidence that this is not hypothetical: in CI the 26 cpp nodes each report
# RED in ~0.17s, below the floor for a real cmake configure+build+ctest. Tracked in #14.
#
# Usage:
#   verify-red-invariant.sh [<corpus-root>]      check every node (or $CORPUS_LANG only)
#   verify-red-invariant.sh --self-test          prove the checker catches a GREEN node
#
# Env:
#   CORPUS_ROOT   corpus directory (default: <repo>/red-baseline)
#   CORPUS_LANG   restrict to one language — the CI matrix shards on this
#   ACCEPT_TIMEOUT  per-node seconds (default 600); a hung accept must not wedge CI

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCEPT_TIMEOUT="${ACCEPT_TIMEOUT:-600}"

note() { printf '  %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# accept: "..."  ->  the command string, with YAML double-quoted escapes resolved.
#
# The unescape is load-bearing, not tidiness. 30 rust nodes carry `ok\\. [1-9]` in the
# file, which YAML resolves to `ok\. [1-9]`. Passed through raw, bash sees `\\.` inside
# the ERE — a literal backslash followed by any char — which matches nothing, so those
# accepts would report RED on every input including a correct solution. They would pass
# this very check for entirely the wrong reason. `\\` is the only escape present today;
# `\"` is handled too, since an accept containing a quote is the obvious next one.
# Ordering matters: `\"` first, then `\\`, so `\\"` does not lose its backslash.
accept_of() {
  sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p' \
    | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}
language_of() { sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$1/meta.yaml" | sed -n '1p'; }
# requires: ["cmake", "npm"]  ->  space-separated list ("" when the field is absent).
requires_of() {
  local line
  line="$(sed -n 's/^requires: *\[\(.*\)\].*/\1/p' "$1/meta.yaml" | sed -n '1p')"
  line="${line//,/ }"; line="${line//\"/}"
  printf '%s' "$line"
}

# Toolchain gate. `requires:` is the CONTRACT's own declaration, but it is only advisory
# for the languages that declare nothing (go/java/python/rust katas), so the language's
# own baseline toolchain is checked too — otherwise a runner without `cargo` would report
# 36 rust nodes as passing the RED check without running one of them.
toolchain_ok() {
  local node="$1" lang="$2" tool
  for tool in $(requires_of "$node"); do
    have "$tool" || { printf '%s' "$tool"; return 1; }
  done
  case "$lang" in
    go)         have go     || { printf 'go';     return 1; } ;;
    rust)       have cargo  || { printf 'cargo';  return 1; } ;;
    java)       { have javac && have java; } || { printf 'javac/java'; return 1; } ;;
    javascript) have npm    || { printf 'npm';    return 1; } ;;
    cpp)        have cmake  || { printf 'cmake';  return 1; } ;;
    *)          have python3 || { printf 'python3'; return 1; } ;;
  esac
  return 0
}

# Run a node's accept against a pristine copy of its seed. Echoes the exit code.
# `set +o pipefail` inside the subshell: many accepts are pipelines ending in `grep -q`,
# and pipefail would report the upstream runner's status instead of the accept's own — a
# different oracle from the one abproof actually uses. This check must observe exactly
# what the harness observes, warts included.
run_accept() {
  local node="$1" acc="$2" src work ec=0
  src="$node/seed"; [[ -d "$src" ]] || src="$node"
  work="$(mktemp -d)"
  cp -R "$src/." "$work/"
  if have timeout; then
    ( set +o pipefail; cd "$work" && timeout "$ACCEPT_TIMEOUT" bash -c "$acc" >/dev/null 2>&1 ) || ec=$?
  else
    ( set +o pipefail; cd "$work" && bash -c "$acc" >/dev/null 2>&1 ) || ec=$?
  fi
  rm -rf "$work"
  printf '%s' "$ec"
}

# ── self-test: the checker must catch a GREEN node ───────────────────────────────
# A checker that cannot fail is worth nothing. This builds a throwaway corpus of two
# nodes — one honestly RED, one already GREEN — and asserts the sweep flags exactly the
# GREEN one. Mirrors `verify-oracle-sabotage.sh`'s stance: prove the guard bites.
if [[ "${1:-}" == "--self-test" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/red-node/seed" "$tmp/green-node/seed" "$tmp/esc-node/seed"
  # RED: the seed is missing the file the accept demands.
  printf 'id: red-node\nlanguage: "python"\nfiles: ["s.py"]\naccept: "test -f solved.txt"\nforbid: []\n' > "$tmp/red-node/meta.yaml"
  printf 'x = 1\n' > "$tmp/red-node/seed/s.py"
  # GREEN: the seed already satisfies its own accept — the corpus bug this check exists for.
  printf 'id: green-node\nlanguage: "python"\nfiles: ["s.py"]\naccept: "test -f s.py"\nforbid: []\n' > "$tmp/green-node/meta.yaml"
  printf 'x = 1\n' > "$tmp/green-node/seed/s.py"
  # ESCAPE: mirrors the 30 real rust accepts. The file holds `ok\\.`; YAML means `ok\.`.
  # Unescaped, the ERE is `\\.` and matches nothing, so a GREEN node would read RED and
  # this check would bless it. The fixture is GREEN, so it must be caught.
  printf 'id: esc-node\nlanguage: "python"\nfiles: ["s.py"]\naccept: "echo '"'"'result: ok. 3'"'"' | grep -qE '"'"'ok\\\\. [1-9]'"'"'"\nforbid: []\n' > "$tmp/esc-node/meta.yaml"
  printf 'x = 1\n' > "$tmp/esc-node/seed/s.py"

  out=""; rc=0
  out="$(EXPECTED_NODES=3 CORPUS_ROOT="$tmp" bash "$HERE/verify-red-invariant.sh" 2>&1)" || rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "SELF-TEST FAIL: a GREEN node did not fail the sweep" >&2
    printf '%s\n' "$out" >&2; exit 1
  fi
  for want in green-node esc-node; do
    if ! printf '%s' "$out" | grep -q "FAIL $want"; then
      echo "SELF-TEST FAIL: GREEN node '$want' was not caught" >&2
      printf '%s\n' "$out" >&2; exit 1
    fi
  done
  if printf '%s' "$out" | grep -q 'FAIL red-node'; then
    echo "SELF-TEST FAIL: an honestly-RED node was flagged" >&2
    printf '%s\n' "$out" >&2; exit 1
  fi
  # The quarantine must not rot: a node listed as known-GREEN that is actually RED has
  # been fixed, and leaving it listed would silently shrink the gate's coverage forever.
  out2=""; rc2=0
  out2="$(EXPECTED_NODES=3 CORPUS_ROOT="$tmp" KNOWN_GREEN_OVERRIDE="red-node green-node esc-node" \
          bash "$HERE/verify-red-invariant.sh" 2>&1)" || rc2=$?
  if [[ $rc2 -eq 0 ]]; then
    echo "SELF-TEST FAIL: quarantining an honestly-RED node was accepted; the list can rot" >&2
    printf '%s\n' "$out2" >&2; exit 1
  fi
  if ! printf '%s' "$out2" | grep -q 'quarantined as known-GREEN but is RED'; then
    echo "SELF-TEST FAIL: a stale quarantine entry was not named" >&2
    printf '%s\n' "$out2" >&2; exit 1
  fi

  echo "RED-invariant self-test: PASS"
  echo "  - a GREEN node fails the sweep; an honestly-RED node does not"
  echo "  - a node that only reads GREEN once YAML escapes are resolved is still caught"
  echo "  - a stale quarantine entry (listed known-GREEN but actually RED) fails the sweep"
  exit 0
fi

# ── the sweep ────────────────────────────────────────────────────────────────────
CORPUS_ROOT="${CORPUS_ROOT:-}"
[[ $# -ge 1 ]] && CORPUS_ROOT="$1"
if [[ -z "$CORPUS_ROOT" ]]; then
  CORPUS_ROOT="$(cd "$HERE/.." && pwd)/red-baseline"
fi
[[ -d "$CORPUS_ROOT" ]] || { echo "corpus root not found: $CORPUS_ROOT" >&2; exit 2; }

# Drift tripwire. Without it, a renamed or empty CORPUS_ROOT makes the whole sweep
# vacuously PASS — the same failure mode the sibling scripts guard against. Bump when the
# corpus deliberately grows; that edit is the intended review moment.
EXPECTED_NODES="${EXPECTED_NODES:-250}"
found=0
for node in "$CORPUS_ROOT"/*; do [[ -d "$node" ]] && found=$((found + 1)); done
if [[ $found -ne $EXPECTED_NODES ]]; then
  echo "corpus drift: found $found nodes, expected $EXPECTED_NODES (renamed/dropped/added, or wrong CORPUS_ROOT)" >&2
  exit 2
fi

# Known-GREEN quarantine. Defects that need a node authored, removed, or excluded — not
# an oracle fix, so out of scope for the check that found them. Two tickets, two kinds:
#
#   corpus#11  go-counter, go-ledger, go-markdown — CONTENT. go-counter ships no test at
#              all; the other two ship complete implementations never reduced to a stub.
#              Repairable: author the missing test, re-stub the two.
#   corpus#16  javascript-ledger — COMPOSITION, and not repairable. It is an upstream
#              *refactoring* exercise whose prompt states the code "consistently passes
#              the test suite". There is no RED state to start from and no accept oracle
#              recovers one, because the exercise guarantees the seed passes. Awaiting a
#              drop-or-exclude decision, not a fix.
#
# Two properties keep this from becoming a rug to sweep under:
#   1. every entry is PRINTED on every run, so the gate's true coverage is never hidden;
#   2. a quarantined node that turns out to be RED FAILS the build, so the list cannot
#      rot silently once these are repaired — removing the entry is forced.
#
# Note that property 2 assumes entries are TEMPORARY. corpus#16 is the first that may not
# be; if it is kept rather than dropped, this list needs a second category with different
# semantics rather than a permanent resident in this one.
# Adding an entry is a deliberate, reviewable edit. Do not add one to make CI green.
# KNOWN_GREEN_OVERRIDE exists so --self-test can exercise the anti-rot branch; it is not
# a production knob and CI never sets it.
KNOWN_GREEN="${KNOWN_GREEN_OVERRIDE:-go-counter go-ledger go-markdown javascript-ledger}"

is_quarantined() {
  case " $KNOWN_GREEN " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

LANG_FILTER="${CORPUS_LANG:-}"
fail=0; checked=0; skipped=0; considered=0; quarantined=0
green_nodes=""; stale_quarantine=""

for node in "$CORPUS_ROOT"/*; do
  [[ -d "$node" ]] || continue
  [[ -f "$node/meta.yaml" ]] || { note "FAIL $(basename "$node"): no meta.yaml"; fail=1; continue; }
  lang="$(language_of "$node")"
  [[ -n "$LANG_FILTER" && "$lang" != "$LANG_FILTER" ]] && continue
  considered=$((considered + 1))

  if ! missing_tool="$(toolchain_ok "$node" "$lang")"; then
    note "skip $(basename "$node"): $missing_tool absent"
    skipped=$((skipped + 1)); continue
  fi
  acc="$(accept_of "$node")"
  if [[ -z "$acc" ]]; then
    note "FAIL $(basename "$node"): no accept command in meta.yaml"; fail=1; continue
  fi

  ec="$(run_accept "$node" "$acc")"
  checked=$((checked + 1))
  base="$(basename "$node")"
  if is_quarantined "$base"; then
    quarantined=$((quarantined + 1))
    if [[ "$ec" -eq 0 ]]; then
      note "QUARANTINED $base: GREEN, known broken (corpus#11) — NOT counted as verified"
    else
      note "FAIL $base: quarantined as known-GREEN but is RED — remove it from KNOWN_GREEN"
      stale_quarantine="$stale_quarantine $base"
      fail=1
    fi
    continue
  fi
  if [[ "$ec" -eq 0 ]]; then
    note "FAIL $base: accept exited 0 on the untouched seed — node is GREEN, not RED"
    green_nodes="$green_nodes $base"
    fail=1
  else
    note "ok $base: RED (exit $ec)"
  fi
done

echo
echo "RED invariant: considered=$considered checked=$checked skipped=$skipped quarantined=$quarantined${LANG_FILTER:+ (language=$LANG_FILTER)}"
if [[ $quarantined -gt 0 ]]; then
  echo "  quarantined (known-GREEN, corpus#11 — the gate does NOT cover these):$(
    for q in $KNOWN_GREEN; do [[ -d "$CORPUS_ROOT/$q" ]] && printf ' %s' "$q"; done)"
fi

# Vacuity guard. Everything skipped is not a pass — it is a sweep that proved nothing, and
# reporting it green is how an unverified invariant looks verified.
if [[ $considered -gt 0 && $checked -eq 0 ]]; then
  echo "RED invariant: VACUOUS — every node was skipped for an absent toolchain; nothing was verified" >&2
  exit 2
fi

if [[ $fail -ne 0 ]]; then
  [[ -n "$green_nodes" ]] && echo "GREEN nodes (corpus bugs — every measurement over them is inflated):$green_nodes" >&2
  [[ -n "$stale_quarantine" ]] && echo "Stale quarantine (now RED — delete from KNOWN_GREEN):$stale_quarantine" >&2
  echo "RED invariant: FAIL" >&2
  exit 1
fi
echo "RED invariant: PASS"
