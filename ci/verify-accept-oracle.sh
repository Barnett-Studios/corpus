#!/usr/bin/env bash
# CI invariant for issues #4 and #15 — the accept oracle honors the runner's exit code, and no
# acceptance test lives in an editable (`files:`) file. See docs/adrs/0001-green-is-runner-exit-zero.md.
#
# Six checks (any failure => non-zero exit):
#   A  static      no accept ANYWHERE IN THE CORPUS pipes into grep   (#15: all 250 nodes)
#   F  static      a node shipping a toolchain pin actually uses it    (#23: wrapper complete + used)
#   D  structural  no editable (`files:`) file contains a test        (#15: all 250 nodes)
#   E  behavioral  a 2-passed/12-failed run scores RED under every python accept  (#15 reproduction)
#   B  behavioral  the pipe-discard mechanism the invariant defends against, reproduced
#   C  RED-invariant  each clean-subset seed scores non-zero, incl. rust with its editable file emptied
# B, C and E skip a language whose toolchain is absent (fail-open, mirroring `requires`).
#
# SCOPE, AND WHY IT MOVED (#15). Checks A and D were originally scoped to the 25-node clean subset.
# That is precisely how 222 Exercism nodes kept a `grep`-on-output accept while the contract that
# forbids it was "enforced in CI": the guard never looked at the population it certifies. A and D now
# sweep all 250. C stays on the clean subset deliberately — running every seed is
# `verify-red-invariant.sh`'s job and it already shards that across the full corpus in CI.
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
# Every node. Checks A and D sweep this; #15 is the ticket that moved them off CLEAN_GLOB.
ALL_GLOB=("$CORPUS_ROOT"/*)

# accept: "..."  ->  the command string, with YAML double-quoted escapes resolved (accepts are
# single-line, double-quoted). The unescape matches verify-red-invariant.sh's: an accept carrying
# `\\` in the file means `\` once YAML has read it, and check E evals the string.
accept_of() {
  sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p' \
    | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}
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
# javascript and cpp markers added with #15, when D grew to all 250 nodes. Both were checked
# against every editable file in the corpus before being added: 0 hits, so neither can fire as a
# false positive on implementation code today.
test_marker() {
  case "$1" in
    rust)       printf '%s' '#\[[[:space:]]*test[[:space:]]*\]|#\[[[:space:]]*cfg[[:space:]]*\([[:space:]]*test' ;;
    go)         printf '%s' 'func (Test|Example|Benchmark)' ;;
    python)     printf '%s' 'def test|import unittest|from unittest|import pytest' ;;
    java)       printf '%s' '@Test|class TestRunner' ;;
    javascript) printf '%s' 'describe\(|\bit\(|test\(|expect\(' ;;
    cpp)        printf '%s' 'TEST_CASE|REQUIRE\(|CHECK\(' ;;
    *)          printf '%s' '' ;;
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

# Same tripwire for the full corpus, now that A and D sweep it: a wrong CORPUS_ROOT would
# otherwise make the widened checks pass over nothing, which is the exact failure mode #15 is
# about — a guard reporting green over a population it never looked at.
EXPECTED_NODES="${EXPECTED_NODES:-250}"
found_all=0
for node in "${ALL_GLOB[@]}"; do [[ -d "$node" ]] && found_all=$((found_all + 1)); done
if [[ $found_all -ne $EXPECTED_NODES ]]; then
  echo "corpus drift: found $found_all nodes, expected $EXPECTED_NODES (renamed/dropped/added node, or wrong CORPUS_ROOT)" >&2
  exit 2
fi

echo "== check A: no accept in the corpus pipes its runner (a pipe discards its exit code) =="
a_fail=0
for node in "${ALL_GLOB[@]}"; do
  [[ -d "$node" ]] || continue
  acc="$(accept_of "$node")"
  # A pipe makes the pipeline's status the LAST command's, not the runner's — the exact defect,
  # for grep OR rg/awk/perl/sed/etc. An accept must be a bare runner or an `&&`-chain, never
  # piped, so any `|` is the anti-pattern.
  if [[ "$acc" == *"|"* ]]; then
    note "FAIL $(basename "$node"): accept pipes its runner (exit code discarded) -> $acc"; fail=1; a_fail=1
  fi
done
[[ $a_fail -eq 0 ]] && note "ok: no accept pipes its runner ($found_all nodes)"

echo "== check D: no editable (files:) file contains its acceptance test =="
d_fail=0
for node in "${ALL_GLOB[@]}"; do
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
[[ $d_fail -eq 0 ]] && note "ok: no editable file contains its acceptance test ($found_all nodes)"

echo "== check E: a 2-passed/12-failed run scores RED under every python accept (#15) =="
# The reproduction that found #15, run against the real accepts rather than a mock of them.
#
# ci/fixtures/partial-pass/ is a project whose suite emits exactly `2 passed, 12 failed` — the
# output `python-react` shipped while scoring GREEN. Every python node's accept is taken verbatim,
# its `<name>_test.py` argument repointed at the fixture, and run. A `grep -qE '[1-9][0-9]* passed'`
# accept matches the substring `2 passed` and returns 0 (GREEN, wrong). An exit-status accept
# returns pytest's 1 (RED, correct).
#
# Check A already forbids the pipe statically across all 250. This check is the behavioural half:
# it proves what the static rule is FOR, on the concrete case, so a future accept that reintroduces
# a success-substring filter by some other spelling is still caught.
e_fail=0
FIXTURE="$HERE/fixtures/partial-pass"
if [[ ! -d "$FIXTURE" ]]; then
  note "FAIL: fixture missing at $FIXTURE"; fail=1; e_fail=1
elif ! have python3 || ! python3 -m pytest --version >/dev/null 2>&1; then
  # Fail-open on toolchain, per CONTRACT — but say so, so a skip is never read as a pass.
  note "skip: python3/pytest absent — check E did not run"
else
  e_ran=0
  for node in "${ALL_GLOB[@]}"; do
    [[ -d "$node" ]] || continue
    [[ "$(language_of "$node")" == python ]] || continue
    acc="$(accept_of "$node")"
    # Only the pytest-shaped accepts can be repointed; the unittest katas name a test METHOD, not
    # a file, and are out of this check's reach. They are covered by A and D.
    [[ "$acc" == *_test.py* ]] || continue
    probe="$(printf '%s' "$acc" | sed -E 's/[A-Za-z0-9_]+_test\.py/partial_test.py/g')"
    work="$(mktemp -d)"
    cp -R "$FIXTURE/." "$work/"
    ec=0; ( set +o pipefail; cd "$work" && eval "$probe" >/dev/null 2>&1 ) || ec=$?
    rm -rf "$work"
    e_ran=$((e_ran + 1))
    if [[ $ec -eq 0 ]]; then
      note "FAIL $(basename "$node"): scores a 2-passed/12-failed run GREEN -> $acc"; fail=1; e_fail=1
    fi
  done
  # Vacuity guard: a check that repointed nothing proved nothing.
  if [[ $e_ran -eq 0 ]]; then
    note "FAIL: check E matched no python accept — the probe's rewrite rule has gone stale"; fail=1; e_fail=1
  elif [[ $e_fail -eq 0 ]]; then
    note "ok: all $e_ran pytest accepts score the partial-pass fixture RED"
  fi
fi

echo "== check F: a node that ships a toolchain pin must actually use it (#23) =="
# corpus#23. `accept: gradle test` invokes whatever `gradle` is on PATH. On Gradle 9.x every
# gradle node dies with "Failed to load JUnit Platform" BEFORE a single test runs — RED for an
# environmental reason and unsolvable, which is exactly the cpp class #14 confirmed. The seeds
# already declare the version they want in gradle-wrapper.properties; they just could not use it,
# because gradle-wrapper.jar was missing and gradlew was not executable.
#
# Three properties, all mechanical:
#   the wrapper is COMPLETE   (jar present, gradlew executable)
#   the accept USES it        (./gradlew, not ambient gradle)
#   the jar is the REAL one   (sha256 vs Gradle's published wrapper checksum)
#
# The checksum is not ceremony. The jar is a binary that every java node executes, so an
# unnoticed swap is arbitrary code execution across 47 nodes. Gradle publishes the digest at
# services.gradle.org/distributions/gradle-<v>-wrapper.jar.sha256; this is 8.7's, verified
# against that endpoint when the jar was added.
WRAPPER_SHA256_8_7="cb0da6751c2b753a16ac168bb354870ebb1e162e9083f116729cec9c781156b8"
f_fail=0; f_checked=0
sha_of() {
  if have shasum; then shasum -a 256 "$1" | cut -d' ' -f1
  elif have sha256sum; then sha256sum "$1" | cut -d' ' -f1
  else printf ''; fi
}
for node in "${ALL_GLOB[@]}"; do
  [[ -d "$node" ]] || continue
  src="$node/seed"; [[ -d "$src" ]] || src="$node"
  # Only nodes that ship a wrapper are in scope; a node with no pin is a different question.
  [[ -f "$src/gradle/wrapper/gradle-wrapper.properties" ]] || continue
  f_checked=$((f_checked + 1))
  base="$(basename "$node")"
  acc="$(accept_of "$node")"

  jar="$src/gradle/wrapper/gradle-wrapper.jar"
  if [[ ! -f "$jar" ]]; then
    note "FAIL $base: pins gradle in gradle-wrapper.properties but ships no gradle-wrapper.jar — ./gradlew cannot run"
    fail=1; f_fail=1
  else
    got="$(sha_of "$jar")"
    if [[ -z "$got" ]]; then
      note "skip $base: no sha256 tool — wrapper jar integrity unverified"
    elif [[ "$got" != "$WRAPPER_SHA256_8_7" ]]; then
      note "FAIL $base: gradle-wrapper.jar sha256 $got != published $WRAPPER_SHA256_8_7"
      fail=1; f_fail=1
    fi
  fi

  if [[ -f "$src/gradlew" && ! -x "$src/gradlew" ]]; then
    note "FAIL $base: gradlew is not executable — the pin cannot be invoked"
    fail=1; f_fail=1
  fi

  # `gradle ...` unqualified resolves off PATH; `./gradlew ...` is the pin.
  if [[ "$acc" == *"gradle "* && "$acc" != *"./gradlew"* ]]; then
    note "FAIL $base: accept invokes ambient gradle, not the pinned ./gradlew -> $acc"
    fail=1; f_fail=1
  fi
done
if [[ $f_checked -eq 0 ]]; then
  note "FAIL: check F matched no wrapper-shipping node — the corpus lost its java stratum, or the probe is stale"
  fail=1; f_fail=1
elif [[ $f_fail -eq 0 ]]; then
  note "ok: all $f_checked wrapper-shipping nodes ship a complete, verified wrapper and invoke it"
fi

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
