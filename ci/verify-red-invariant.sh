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
# NOT. Tracked in #14.
#
# That gap was not hypothetical, and it has now been paid out once. All 26 cpp nodes were
# reporting RED in ~0.17s in CI — below the floor for a real cmake configure. The cause was
# a CMakeLists that derived its source filenames from the work directory, so cmake never
# configured in any scratch dir and no submission could ever have turned the node GREEN.
# The check reported `ok ... RED (exit 1)` for all 26, every run, for as long as they have
# existed. #15 repairs the seeds; this comment stays because the LIMIT is unchanged — the
# next unsolvable node will pass this check just as quietly.
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

# Run a node's accept against a pristine copy of its seed. Echoes the exit code; the
# accept's combined output lands in $3, for env_failure_of to read.
#
# The log path is an ARGUMENT rather than a variable this function sets. Callers invoke it
# as `ec="$(run_accept ...)"`, so every assignment inside it happens in a subshell and is
# lost — an inert env-failure guard reading an empty path, which is what the self-test
# caught the first time this was written.
#
# `set +o pipefail` inside the subshell: many accepts are pipelines ending in `grep -q`,
# and pipefail would report the upstream runner's status instead of the accept's own — a
# different oracle from the one abproof actually uses. This check must observe exactly
# what the harness observes, warts included.
run_accept() {
  local node="$1" acc="$2" log="$3" src work ec=0
  src="$node/seed"; [[ -d "$src" ]] || src="$node"
  work="$(mktemp -d)"
  cp -R "$src/." "$work/"
  if have timeout; then
    ( set +o pipefail; cd "$work" && timeout "$ACCEPT_TIMEOUT" bash -c "$acc" >"$log" 2>&1 ) || ec=$?
  else
    ( set +o pipefail; cd "$work" && bash -c "$acc" >"$log" 2>&1 ) || ec=$?
  fi
  rm -rf "$work"
  printf '%s' "$ec"
}

# A non-zero exit that came from the ENVIRONMENT, not from the unimplemented stub. Echoes
# a reason, or nothing.
#
# corpus#27. Dropping `requires: ["gradle"]` from the 47 wrapper nodes is only an
# improvement if this exists. Before, a machine without gradle SKIPPED them — visible in
# the `skipped` count. After, it RUNS them, `./gradlew` fails to fetch its distribution,
# the accept exits non-zero, and the sweep prints `ok <node>: RED (exit 1)`. That trades a
# loud skip for a silent false pass, which is strictly the worse half of the same defect
# the ticket is about.
#
# It is also load-bearing for the distribution digest pinned in check F: a wrong pin makes
# every java node die with "Verification of Gradle distribution failed!", and all 47 would
# have read as honestly RED with nothing saying the tests never ran.
#
# The header above documents the general limit — this check cannot tell "RED because
# unimplemented" from "RED because the toolchain never reached the tests" — and this does
# NOT lift it. It closes the specific signatures reachable from this change. A cmake
# configure that fails for a novel reason still passes quietly; that remains #14.
env_failure_of() {
  local log="$1"
  [[ -f "$log" ]] || return 0
  # Ordered most specific first, so the printed reason names the actual cause.
  local pat reason
  while IFS='|' read -r pat reason; do
    [[ -z "$pat" ]] && continue
    if grep -qF -- "$pat" "$log" 2>/dev/null; then printf '%s' "$reason"; return 0; fi
  done <<'PATTERNS'
Verification of Gradle distribution failed|the pinned distributionSha256Sum does not match what was downloaded (check F's digest is wrong, or the payload is)
Could not install Gradle distribution|the gradle wrapper could not unpack its distribution
Exception in thread "main" java.net.UnknownHostException|DNS failed — no network to fetch the gradle distribution
Exception in thread "main" java.net.ConnectException|connection refused — no network to fetch the gradle distribution
Network is unreachable|no network to fetch the toolchain distribution
Could not find or load main class org.gradle.wrapper.GradleWrapperMain|gradle-wrapper.jar is missing or unreadable
PATTERNS
  return 0
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
  # ENV: non-zero for an environmental reason (corpus#27). Without env_failure_of this
  # node reads `ok env-node: RED (exit 1)` — a toolchain that never reached the tests,
  # blessed as a verified invariant.
  mkdir -p "$tmp/env-node/seed"
  printf 'id: env-node\nlanguage: "python"\nfiles: ["s.py"]\naccept: "echo Could not install Gradle distribution from '"'"'https://services.gradle.org/x.zip'"'"'; exit 1"\nforbid: []\n' > "$tmp/env-node/meta.yaml"
  printf 'x = 1\n' > "$tmp/env-node/seed/s.py"

  out=""; rc=0
  out="$(EXPECTED_NODES=4 CORPUS_ROOT="$tmp" bash "$HERE/verify-red-invariant.sh" 2>&1)" || rc=$?
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
  # corpus#27. The distinguishing assertion is not "env-node failed" — it is that it failed
  # as ENVIRONMENTAL and was never counted as checked. A guard that failed it for any other
  # reason would still leave the sweep claiming it verified the node.
  if ! printf '%s' "$out" | grep -q 'FAIL env-node: accept exited 1 for an ENVIRONMENTAL reason'; then
    echo "SELF-TEST FAIL: an environmentally-RED node was not distinguished from an honest RED" >&2
    printf '%s\n' "$out" >&2; exit 1
  fi
  # 4 fixtures considered, 3 checked: env-node must be excluded from the denominator, not
  # merely failed. A guard that failed it while still counting it would leave the summary
  # line claiming a node was verified that never ran its tests.
  if ! printf '%s' "$out" | grep -q 'considered=4 checked=3'; then
    echo "SELF-TEST FAIL: an environmentally-RED node was counted as checked" >&2
    printf '%s\n' "$out" >&2; exit 1
  fi
  # The quarantine must not rot: a node listed as known-GREEN that is actually RED has
  # been fixed, and leaving it listed would silently shrink the gate's coverage forever.
  out2=""; rc2=0
  out2="$(EXPECTED_NODES=4 CORPUS_ROOT="$tmp" KNOWN_GREEN_OVERRIDE="red-node green-node esc-node" \
          bash "$HERE/verify-red-invariant.sh" 2>&1)" || rc2=$?
  if [[ $rc2 -eq 0 ]]; then
    echo "SELF-TEST FAIL: quarantining an honestly-RED node was accepted; the list can rot" >&2
    printf '%s\n' "$out2" >&2; exit 1
  fi
  if ! printf '%s' "$out2" | grep -q 'quarantined as known-GREEN but is RED'; then
    echo "SELF-TEST FAIL: a stale quarantine entry was not named" >&2
    printf '%s\n' "$out2" >&2; exit 1
  fi

  # The summary's quarantine COUNT and the names printed under it must describe the same
  # set. They did not: the list walked all of KNOWN_GREEN while the count only ever
  # incremented for nodes this run reached, so `CORPUS_LANG=go` reported `quarantined=3`
  # and then named six. Two fixtures are quarantined here and one entry names a node that
  # does not exist in the fixture root, which is the shape that produced the divergence.
  out3=""
  out3="$(EXPECTED_NODES=4 CORPUS_ROOT="$tmp" KNOWN_GREEN_OVERRIDE="green-node esc-node absent-node" \
          bash "$HERE/verify-red-invariant.sh" 2>&1)" || true
  # `wc -w`, not `grep -c`: with an empty list `grep -c` exits 1, and under `set -euo
  # pipefail` that kills the whole self-test with no output at all — a guard that dies
  # silently on the very state it exists to detect. Caught by mutating the accumulator.
  q_count="$(printf '%s' "$out3" | sed -n 's/.*quarantined=\([0-9]*\).*/\1/p' | head -1)"
  q_named="$(printf '%s' "$out3" | sed -n 's/.*the gate does NOT cover these)://p' | wc -w | tr -d ' ')"
  # Both halves, and the first is not redundant: with the count stuck at 0 the summary skips
  # the section entirely, so `q_count` and `q_named` agree at 0 while the gate's coverage gap
  # goes unreported — property 1 defeated by a guard that only ever compared the number to
  # itself. 2 comes from the fixture (green-node, esc-node are quarantined and both exist),
  # not from what the run printed.
  if [[ "$q_count" != 2 ]]; then
    echo "SELF-TEST FAIL: 2 fixtures are quarantined but the summary says quarantined=$q_count" >&2
    printf '%s\n' "$out3" >&2; exit 1
  fi
  if [[ "$q_count" != "$q_named" ]]; then
    echo "SELF-TEST FAIL: quarantined=$q_count but $q_named node(s) named beside it" >&2
    printf '%s\n' "$out3" >&2; exit 1
  fi

  echo "RED-invariant self-test: PASS"
  echo "  - a GREEN node fails the sweep; an honestly-RED node does not"
  echo "  - a node that only reads GREEN once YAML escapes are resolved is still caught"
  echo "  - a stale quarantine entry (listed known-GREEN but actually RED) fails the sweep"
  echo "  - a node that is RED for an ENVIRONMENTAL reason fails, and is not counted as checked"
  echo "  - the quarantine count and the names printed beside it describe the same set"
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

# Known-GREEN quarantine. Nodes whose seed passes its own tests, so this gate cannot cover
# them. Three tickets found them in three sweeps and classified them three ways; re-derived
# from each node's OWN prompt, **five of the six are one phenomenon** and #16 is the only
# ticket that named it. The split was by which sweep found the node, not by what the node is.
#
#   The phenomenon — an upstream exercise whose seed passes BY DESIGN:
#     go-ledger, go-markdown  (corpus#11)   "The ledger/markdown exercise is a refactoring
#     java-ledger             (corpus#23)    exercise … somehow it works and all the tests
#     java-tree-building      (corpus#23)    are passing" / "refactor a WORKING but slow and
#     javascript-ledger       (corpus#16)    ugly piece of code"
#
#   There is no RED state to start from and no accept oracle recovers one, because the
#   exercise guarantees the seed passes. **Not repairable by re-stubbing**, which is what
#   corpus#11 ("re-stub the two") and corpus#23 ("the SAME content defect") prescribe: gutting
#   the implementation does not repair the node, it replaces the exercise with a different one
#   whose `change` prompt — still saying "refactor this working code" — would then be a lie.
#   That is corpus#16's parked drop-or-exclude decision, and it now governs five nodes.
#
#   The substitution IS available, and the corpus already contains the precedent: `go-tree-
#   building` carries the identical "refactor a working…" prompt and the Go track ships it as
#   a `panic("Please implement…")` stub, so it is honestly RED and is not quarantined. Taking
#   it is a composition decision (the prompt has to change with the seed), not a repair.
#
#   corpus#11  go-counter — its OWN class, and the one entry #11 characterises correctly.
#              Upstream-DEPRECATED and a write-your-own-tests exercise ("Design a test suite
#              for a line/letter/character counter tool"), so nothing was ported:
#              `counter_test.go` is the literal stub `// Define your tests here` and there is
#              no acceptance test at all. It scores GREEN for any output, including empty.
#              Not mechanically repairable either, but for a different reason, and the node's
#              `change` ("Implement the solution in counter.go") contradicts the task text it
#              carries.
#   corpus#23  the gradle half of that ticket stands: java-ledger and java-tree-building were
#              invisible while the accept invoked ambient `gradle` — on Gradle 9.x the test
#              executor never starts, so they exited non-zero and this check printed
#              `ok … RED` for them. Pinning the wrapper (#23) is what made them visible, and
#              they are safe to quarantine only BECAUSE of that pin: before it, whether they
#              read GREEN or RED depended on the host's gradle, and an entry here would have
#              tripped the anti-rot branch on any runner resolving 9.x.
#
# Verified in the same pass, so the list is not short: all 250 prompts were swept for the
# task-verb, which named eight nodes. The two extra — `go-tree-building` and
# `python-tree-building` — are honestly RED and belong nowhere near this list. The Go one
# ships a stub; the Python one ships the upstream slow implementation and scores 6 failed /
# 7 passed against its own suite. **The prompt does not decide RED-ability, the seed does** —
# which is why the sweep above is the authority here and this comment is only its reading.
#
# Two properties keep this from becoming a rug to sweep under:
#   1. every entry is PRINTED on every run, so the gate's true coverage is never hidden;
#   2. a quarantined node that turns out to be RED FAILS the build, so the list cannot
#      rot silently once these are repaired — removing the entry is forced.
#
# Note that property 2 assumes entries are TEMPORARY. Five of the six are not, unless the
# drop-or-exclude decision goes that way; if they are kept, this list needs a second category
# with different semantics rather than five permanent residents in this one.
# Adding an entry is a deliberate, reviewable edit. Do not add one to make CI green.
# KNOWN_GREEN_OVERRIDE exists so --self-test can exercise the anti-rot branch; it is not
# a production knob and CI never sets it.
KNOWN_GREEN="${KNOWN_GREEN_OVERRIDE:-go-counter go-ledger go-markdown javascript-ledger java-ledger java-tree-building}"

is_quarantined() {
  case " $KNOWN_GREEN " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

LANG_FILTER="${CORPUS_LANG:-}"
fail=0; checked=0; skipped=0; considered=0; quarantined=0
green_nodes=""; stale_quarantine=""; env_nodes=""; quarantined_nodes=""

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

  ACCEPT_LOG="$(mktemp)"
  ec="$(run_accept "$node" "$acc" "$ACCEPT_LOG")"
  base="$(basename "$node")"

  # Before anything else: was this RED for an environmental reason? Checked ahead of the
  # quarantine branch because an env failure there would otherwise be reported as "listed
  # known-GREEN but is RED", sending the reader to delete a quarantine entry over a
  # network outage.
  env_reason=""
  if [[ "$ec" -ne 0 ]]; then env_reason="$(env_failure_of "$ACCEPT_LOG")"; fi
  rm -f "$ACCEPT_LOG"
  if [[ -n "$env_reason" ]]; then
    note "FAIL $base: accept exited $ec for an ENVIRONMENTAL reason, not an unimplemented stub — $env_reason"
    env_nodes="$env_nodes $base"
    fail=1
    continue
  fi

  checked=$((checked + 1))
  if is_quarantined "$base"; then
    quarantined=$((quarantined + 1))
    quarantined_nodes="$quarantined_nodes $base"
    if [[ "$ec" -eq 0 ]]; then
      note "QUARANTINED $base: GREEN, known broken (corpus#11/#16/#23) — NOT counted as verified"
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
  # The nodes THIS run reached, not every entry in KNOWN_GREEN. Printing the whole list
  # beside the count contradicted it under CORPUS_LANG: the go sweep reported
  # `quarantined=3` and then named six, and a count that disagrees with the list next to it
  # teaches the reader to trust neither.
  echo "  quarantined (known-GREEN, corpus#11/#16/#23 — the gate does NOT cover these):$quarantined_nodes"
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
  [[ -n "$env_nodes" ]] && echo "Environmentally RED (the runner, not the corpus — these nodes were NOT verified):$env_nodes" >&2
  echo "RED invariant: FAIL" >&2
  exit 1
fi
echo "RED invariant: PASS"
