---
title: Implementation plan — accept-oracle honors the runner exit code
issue: Barnett-Studios/corpus#4
spec: docs/specs/0001-accept-oracle-honors-exit-code.md
adr: docs/adrs/0001-green-is-runner-exit-zero.md
status: Draft
created: 2026-07-22T08:51:51Z
updated: 2026-07-22T09:07:11Z
---

# Plan 0001 — Accept-oracle honors the runner exit code

RED-first: the CI invariant that forbids both anti-patterns is authored and shown to FAIL against
the current katas before they are fixed. There are **two** RED-first anchors — the `grep` pipe
(check A) and the editable-file test (check D) — the second surfaced during adversarial validation
of the rust katas.

## Node graph

### N1 — CI invariant script (RED-first)  ·  authored first
`ci/verify-accept-oracle.sh` (shellcheck-clean), four checks; any failure → non-zero exit.
B/C skip a language whose toolchain is absent (fail-open, mirroring `requires`).
- **A — static (RED-first #1):** every clean-subset node's `accept` (24 katas + `py-add`) must
  NOT contain `grep`. **Fails now** (24 do), passes after N3.
- **D — structural (RED-first #2):** no file listed in a node's `files:` may contain a
  test-definition marker (rust `#[test]`/`#[cfg(test)]`, go `func Test`, python `def test`/
  `unittest`, java `@Test`/`TestRunner`). **Fails now** (6 rust katas keep the test in the editable
  `src/lib.rs`), passes after N3's relocation. This is the check that actually forbids the
  unsolved→GREEN hole; go/java/python already comply.
- **B — behavioral mechanism:** proves the defect the invariant defends against. (1) A
  toolchain-free fixture: a `runner()` that exits non-zero but whose success-substring fools
  `grep -q` → the piped form exits 0 (GREEN, wrong), the bare form exits non-zero (RED, correct).
  (2) When cargo is present, a real multi-binary reproduction: a passing lib test and a
  same-filtered-name failing integration test → the old grep matches the passing binary's `ok`
  line (GREEN) while the bare `cargo test` is RED. Documents *why* A and D exist.
- **C — RED-invariant:** each fixed kata's `accept` run against its unmodified seed exits
  non-zero; and a rust seed with its editable `src/lib.rs` emptied still exits non-zero (the test
  is un-deletable). Skipped per missing toolchain.
`accept`: `bash ci/verify-accept-oracle.sh` fails on checks A **and** D before N3, passes after.

### N2 — reference-solution GREEN spot-check (validation only, not shipped)  ·  local
`ci/prove-solvable.sh` applies one **fully-solved editable file per language** — `ci/solutions/{go,
java,python,rust}/…` — to a temp copy of each kata's seed and asserts the fixed `accept` exits 0.
Because all six katas of a language share one editable file, four solutions cover all 24 katas.
Solutions live under `ci/solutions/` used ONLY by this check — the RED corpus never ships solved
seeds. Confirms the fixed accepts are not vacuously-RED (they can still go GREEN).
`accept`: every kata's language solution → its accept exits 0.

### N3 — apply the fix (the two coupled changes)  ·  local: true (mechanical, scripted)
1. **Accepts:** strip the ` 2>&1 | grep -q…` tail from each of the 24 clean-subset `accept`s per
   the ADR table (java keeps its `javac && java TestRunner <name>` chain); `py-add` untouched.
2. **Rust relocation:** move `#[cfg(test)] mod tests` out of each rust kata's editable
   `src/lib.rs` into a non-editable `seed/tests/katas.rs` (`use eval_rust::*;`; all tested fns are
   `pub`). All six rust seeds are byte-identical, so one generated `tests/katas.rs` is reused.
Applied by a scripted, auditable transform; `git diff` shows only the `accept:` line changed per
node plus the rust test move.
`accept`: checks A and D green; the rust seed still RED; the emptied-file case still RED.

### N4 — CONTRACT + docs (docs-with-code)  ·  local: true
CONTRACT.md: state the accept mechanism is the runner's exit code AND that the acceptance test is
never in an editable (`files:`) file. Flip spec/ADR status at merge.
`accept`: CONTRACT.md `accept` row reads exit-code; a note forbids tests in editable files.

### N5 — wire the invariant into CI  ·  local: true
Add an `accept-oracle` job to `.github/workflows/ci.yml` running `ci/verify-accept-oracle.sh`
(shellcheck it too), with the language toolchains installed (or the per-tool skip keeping it green
where a toolchain is absent).
`accept`: CI green on the PR.

### N6 — pilot: discordant-pair rate  ·  BLOCKED-aware
Run both abproof arms once over the fixed clean subset to measure the discordant-pair rate.
**Requires the abproof executor + a local model fleet, absent from this environment** — if
unavailable, report it as a documented BLOCKED sub-step in the PR (do not fabricate a number), and
substitute the RED/GREEN + relocation + partial-fixture evidence as the validity demonstration.

## Sequencing

N1 (RED: A+D fail) → N2 → N3 (A+D pass) → N4 → N5 → N6.

## Offload split (to report in the PR)

- Mechanical (scripted transform, no model needed): N3, N4.
- Orchestrator-authored (correctness-bearing): N1, N2, N5. N6 is environment-gated.
