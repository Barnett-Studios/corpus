#!/usr/bin/env bash
# Materialize a node's work tree the way CONTRACT.md tells LOADERS to, in one place.
#
# corpus#34. Four gates carried the same two lines:
#
#     src="$node/seed"; [[ -d "$src" ]] || src="$node"
#     cp -R "$src/." "$work/"
#
# For a `seed/` node that is right. For a LEGACY node — a flat `stub.<ext>` +
# `acceptance_test.<ext>` pair — it copies the WHOLE node directory, which is a
# materialization no consumer performs: the CONTRACT says a loader synthesizes the seed
# from the pair, so it writes exactly two files. `py-add` acquired a third required file
# (`probe.py`, 9e65228) and the gates kept passing, because they were copying it while
# every contract-conforming loader was not. A correct solution failed for every consumer
# and `prove-solvable.sh` reported `ok py-add: solution -> GREEN`.
#
# Six copies of a materialization rule is why the gates and the contract could drift
# apart without anything noticing. There is one now.
#
# Usage: materialize_node <node_dir> <work_dir>   -> 0 on success, 1 with a reason on stderr

# The primary editable file: `files: ["calc.py"]` -> calc.py. First entry only, which is
# what a loader uses as the stub's destination.
primary_file_of() {
  sed -n 's/^files: *\[ *"\([^"]*\)".*/\1/p' "$1/meta.yaml" | sed -n '1p'
}

materialize_node() {
  local node="$1" work="$2"

  if [[ -d "$node/seed" ]]; then
    cp -R "$node/seed/." "$work/"
    return 0
  fi

  # Legacy pair. Exactly what CONTRACT.md §Per-node shape describes a loader doing, and
  # deliberately NOT a directory copy: a file the accept needs that is neither the stub
  # nor the acceptance test is a node no loader can solve, and this is where that has to
  # become visible.
  local stub acceptance primary
  stub="$(find "$node" -maxdepth 1 -name 'stub.*' -print -quit 2>/dev/null)"
  acceptance="$(find "$node" -maxdepth 1 -name 'acceptance_test.*' -print -quit 2>/dev/null)"
  primary="$(primary_file_of "$node")"

  if [[ -z "$stub" || -z "$acceptance" ]]; then
    echo "no seed/ and no stub+acceptance_test pair in $node — the CONTRACT describes no" \
         "other shape, so this node cannot be materialized the way a loader would" >&2
    return 1
  fi
  if [[ -z "$primary" ]]; then
    echo "legacy node $node declares no files:[0] — the stub has no destination" >&2
    return 1
  fi

  mkdir -p "$work/$(dirname "$primary")"
  cp "$stub" "$work/$primary"
  cp "$acceptance" "$work/$(basename "$acceptance")"
  return 0
}

# ── self-test ────────────────────────────────────────────────────────────────────
# Runs only when this file is EXECUTED, never when it is sourced. The legacy branch has
# no node exercising it in the corpus — `py-add` was the last one and moved to `seed/` in
# corpus#34 — so without this the branch that caused the defect would ship untested, which
# is how it got there.
if [[ "${BASH_SOURCE[0]}" == "${0}" && "${1:-}" == "--self-test" ]]; then
  set -euo pipefail
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  fail=0

  # 1. seed node: the seed's contents, and nothing from the node level.
  mkdir -p "$tmp/seed-node/seed"
  printf 'id: seed-node\nfiles: ["a.py"]\n' > "$tmp/seed-node/meta.yaml"
  printf 'x\n' > "$tmp/seed-node/context.md"
  printf 'a\n' > "$tmp/seed-node/seed/a.py"
  printf 't\n' > "$tmp/seed-node/seed/test_a.py"
  w1="$tmp/w1"; mkdir -p "$w1"
  materialize_node "$tmp/seed-node" "$w1"
  for want in a.py test_a.py; do
    [[ -f "$w1/$want" ]] || { echo "SELF-TEST FAIL: seed node lost $want" >&2; fail=1; }
  done
  for unwanted in meta.yaml context.md; do
    [[ -e "$w1/$unwanted" ]] && { echo "SELF-TEST FAIL: seed node's $unwanted reached the work tree" >&2; fail=1; }
  done

  # 2. legacy pair: EXACTLY the pair. The third file is the corpus#34 case — `py-add`
  #    acquired a required `probe.py` and every gate kept copying it while no loader did,
  #    so a correct solution failed for every consumer and the gate said GREEN.
  mkdir -p "$tmp/legacy-node"
  printf 'id: legacy-node\nfiles: ["calc.py"]\n' > "$tmp/legacy-node/meta.yaml"
  printf 'stub\n' > "$tmp/legacy-node/stub.py"
  printf 'test\n' > "$tmp/legacy-node/acceptance_test.py"
  printf 'probe\n' > "$tmp/legacy-node/probe.py"
  printf 'ctx\n' > "$tmp/legacy-node/context.md"
  w2="$tmp/w2"; mkdir -p "$w2"
  materialize_node "$tmp/legacy-node" "$w2"
  [[ -f "$w2/calc.py" ]] || { echo "SELF-TEST FAIL: the stub did not land on files:[0]" >&2; fail=1; }
  [[ "$(cat "$w2/calc.py" 2>/dev/null)" == stub ]] || { echo "SELF-TEST FAIL: files:[0] does not carry the stub's content" >&2; fail=1; }
  [[ -f "$w2/acceptance_test.py" ]] || { echo "SELF-TEST FAIL: the acceptance test did not land" >&2; fail=1; }
  for unwanted in probe.py meta.yaml context.md stub.py; do
    if [[ -e "$w2/$unwanted" ]]; then
      echo "SELF-TEST FAIL: $unwanted reached the work tree — the gate is materializing a" >&2
      echo "shape no conforming loader produces, which is corpus#34 exactly" >&2
      fail=1
    fi
  done

  # 3. neither shape: refuse loudly rather than produce an empty or invented work tree.
  mkdir -p "$tmp/broken-node"
  printf 'id: broken-node\nfiles: ["a.py"]\n' > "$tmp/broken-node/meta.yaml"
  w3="$tmp/w3"; mkdir -p "$w3"
  if materialize_node "$tmp/broken-node" "$w3" 2>/dev/null; then
    echo "SELF-TEST FAIL: a node with neither seed/ nor a pair was materialized anyway" >&2
    fail=1
  fi

  [[ $fail -eq 0 ]] || { echo "materialize self-test: FAIL" >&2; exit 1; }
  echo "materialize self-test: PASS"
  echo "  - a seed node gets its seed and none of the node-level files"
  echo "  - a legacy node gets EXACTLY the stub-as-files[0] and the acceptance test"
  echo "  - a node with neither shape is refused, not materialized into something invented"
fi
