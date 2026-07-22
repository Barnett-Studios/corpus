---
title: Implementation plan — accept-oracle honors the runner exit code
issue: Barnett-Studios/corpus#4
spec: docs/specs/0001-accept-oracle-honors-exit-code.md
adr: docs/adrs/0001-green-is-runner-exit-zero.md
status: Draft
created: 2026-07-22T08:51:51Z
updated: 2026-07-22T08:51:51Z
---

# Plan 0001 — Accept-oracle honors the runner exit code

RED-first: the CI invariant that forbids the anti-pattern is authored and shown to FAIL against
the current grep-based katas before they are fixed.

## Node graph

### N1 — CI invariant script (RED-first)  ·  authored first
`ci/verify-accept-oracle.sh` (shellcheck-clean), three checks:
- **A — static:** every clean-subset node's `accept` (24 katas + `py-add`) must NOT contain
  `grep`. **Fails now** (they do), passes after N3.
- **B — behavioral partial-pass:** self-contained fixtures per language (skipped when the
  toolchain is absent, mirroring `requires` fail-open): a multi-test project with ≥1 pass and ≥1
  fail. Assert the **new** (exit-code) accept exits non-zero (RED) AND the **old** (grep) accept
  exits zero (documents the bug). Reproduce the exact fooling outputs: `1 failed, N passed`
  (pytest), `N passing`+`N failing` (node), a passing lib + failing integration cargo run, and
  `ctest` `10 tests failed ⊃ 0 tests failed` (cpp fixture; runs only where cmake/ctest exist).
- **C — RED-invariant:** each fixed kata's `accept` run against its unmodified seed exits
  non-zero (skipped per missing toolchain).
`accept`: `bash ci/verify-accept-oracle.sh` fails on check A before N3, passes after.

### N2 — reference-solution GREEN spot-check (validation only, not shipped)  ·  local
A local harness applies a correct implementation of each kata to a temp copy of its seed and
asserts the fixed `accept` exits 0. Reference solutions live under `ci/solutions/` used ONLY by
this check — the RED corpus never ships solved seeds. Confirms the fixed accept is not
vacuously-RED (it can still go GREEN).
`accept`: every kata's solution → exit 0.

### N3 — rewrite the 24 katas' accept fields (the fix)  ·  local: true (mechanical)
Strip the ` 2>&1 | grep -q…` tail from each clean-subset `accept` per the ADR table; java keeps
its `javac && java TestRunner <name>` chain. Applied by a scripted, auditable transform over the
24 `meta.yaml` files; `py-add` untouched (already bare exit code).
`accept`: check A green; `git diff` shows only the `accept:` line changed per node.

### N4 — CONTRACT + docs (docs-with-code)  ·  local: true
CONTRACT.md: state the accept mechanism is the runner's exit code (drop any implication that a
success-substring is acceptable). Flip spec/ADR status at merge.
`accept`: CONTRACT.md `accept` row reads exit-code; no doc claims grep-substring scoring.

### N5 — wire the invariant into CI  ·  local: true
Add a `accept-oracle` job to `.github/workflows/ci.yml` running `ci/verify-accept-oracle.sh`
(shellcheck it too), with the language toolchains installed (or the per-tool skip keeping it
green where a toolchain is absent).
`accept`: CI green on the PR.

### N6 — pilot: discordant-pair rate  ·  BLOCKED-aware
Run both abproof arms once over the fixed clean subset to measure the discordant-pair rate.
**Requires the abproof executor + a local model fleet, absent from this environment** — if
unavailable, report it as a documented BLOCKED sub-step in the PR (do not fabricate a number),
and substitute the RED/GREEN + partial-fixture evidence as the validity demonstration.

## Sequencing

N1 (RED) → N2 → N3 → N4 → N5 → N6. N1's check A is the RED-first anchor.

## Offload split (to report in the PR)

- Mechanical (offloadable): N3, N4.
- Orchestrator-authored (correctness-bearing): N1, N2, N5. N6 is environment-gated.
