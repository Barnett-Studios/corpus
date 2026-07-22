---
title: Accept-oracle honors the runner exit code
issue: Barnett-Studios/corpus#4
status: Draft
created: 2026-07-22T08:51:51Z
updated: 2026-07-22T09:07:11Z
---

# Spec 0001 — Accept-oracle honors the runner exit code

## Problem

`CONTRACT.md` promises `accept | exit 0 ⇔ the task is solved`. But **249 of 250** accept
commands pipe the test runner into `grep -q <success-substring>`, so the pipeline's exit status
is **grep's**, not the runner's. The oracle is therefore really "≥ 1 test matched a success
substring", which scores **partial** solutions GREEN:

- python: `pytest … | grep -qE '[1-9][0-9]* passed'` matches `19 passed` inside
  `1 failed, 19 passed`.
- javascript: `npm test … | grep -qiE '[1-9][0-9]* (passing|passed)'` matches `19 passing`
  beside `1 failing`.
- cpp: `ctest … | grep -qE '0 tests failed'` — `10 tests failed` *contains* `0 tests failed`.
- rust: `grep -qE 'test result: ok\. [1-9]'` — cargo runs multiple test binaries, so a passing
  one emits an `ok` line even when another fails.

Only `py-add` uses a bare exit code. Effect: the RED→GREEN metric compresses toward the ceiling
and differentially favors weaker models — the corpus cannot support the claims it exists to
adjudicate.

Verified: `grep -rh '^accept:' red-baseline/*/meta.yaml` → 249 pipe into `grep -q`, 1 does not.

## The clean subset (this ticket's scope)

The **24 hand-authored katas** (`{go,java,python,rust}-0[1-6]-*`) plus `py-add` — the only
uncontaminated, framework-owned nodes. Each kata runs a **single** immutable test, so the
partial-pass bug does not actively mis-score a kata *today*; but every kata still violates the
CONTRACT's letter by discarding the runner's exit code.

There is a second, sharper defect specific to **rust**: its katas set `files: ["src/lib.rs"]`, and
the acceptance test lives *inside* that editable file (`#[cfg(test)] mod tests`). `cargo test
<filter>` exits 0 when the filter matches zero tests, so a model that leaves the stub and deletes
the in-file test scores an *unsolved* node **GREEN**. The shipped `grep -qE 'test result: ok\.
[1-9]'` masked this by requiring a nonzero passed-count; simply dropping the pipe would regress
oracle integrity. go/java/python already keep the test in a non-editable file; only rust does not.

This ticket makes the clean subset CONTRACT-honoring (exit-code oracle), relocates the rust test
out of the editable file, and lands the CI invariant that guards both the pattern and the
editable-test hole. De-contaminating the ~145 Exercism nodes is **out of scope** (corpus#5).

## Goals

1. Every clean-subset node's `accept` returns the **runner's own exit code** — no `grep`
   substring in the pipeline.
2. **No editable (`files:`) file contains its acceptance test.** The rust test moves from
   `src/lib.rs` to a non-editable `tests/` integration file, so an unsolved node cannot be scored
   GREEN by deleting its test.
3. A **CI invariant** that fails if any clean-subset accept reintroduces the `grep` anti-pattern
   or if any editable file contains a test, and that behaviorally proves the pipe-discard
   mechanism scores **RED** under a bare runner (where the old grep scored GREEN).
4. The RED invariant is preserved: every clean-subset seed still scores non-zero (RED).

## Non-goals

- The ~145 Exercism nodes (corpus#5). Their accepts are untouched here.
- Changing the `{meta, seed, RED}` node shape, the manifest, or attribution.

## Acceptance

- **Static (RED-first #1):** a check asserting no clean-subset `accept` pipes into `grep` —
  **fails against the current grep-based katas**, passes after the fix.
- **Structural (RED-first #2):** a check asserting no editable (`files:`) file contains a
  test-definition marker — **fails against the 6 current rust katas** (test in `src/lib.rs`),
  passes after the test is relocated to `tests/`.
- **Behavioral mechanism:** a fixture proving the pipe discards the runner's exit code — a failing
  runner whose success-substring fools `grep -q` exits **0 (GREEN)** through the pipe but **non-zero
  (RED)** bare; plus a real cargo multi-binary reproduction where a passing binary's `ok` line
  fools the old grep while the bare runner is RED.
- **RED-invariant:** each fixed kata's accept run against its unmodified seed exits **non-zero**;
  and a rust node with its editable file emptied still exits **non-zero** (the relocation holds).
- **GREEN spot-check:** a reference solution per language (one fully-solved editable file covers
  all six of that language's katas) makes every kata's accept exit **0** (validation evidence;
  reference solutions live under `ci/solutions/` and are never shipped into the RED corpus).
- CONTRACT.md updated: the accept mechanism is the runner exit code and the test is never in an
  editable file (docs-with-code).
