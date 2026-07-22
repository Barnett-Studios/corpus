---
title: Accept-oracle honors the runner exit code
issue: Barnett-Studios/corpus#4
status: Draft
created: 2026-07-22T08:51:51Z
updated: 2026-07-22T08:51:51Z
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
uncontaminated, framework-owned nodes. Each kata runs a **single** immutable test (the model may
edit only its impl file, never the test), so the partial-pass bug does not actively mis-score a
kata *today*; but every kata still violates the CONTRACT's letter by discarding the runner's exit
code. This ticket makes the clean subset CONTRACT-honoring and lands the CI invariant that guards
the pattern. De-contaminating the ~145 Exercism nodes is **out of scope** (corpus#5).

## Goals

1. Every clean-subset node's `accept` returns the **runner's own exit code** — no `grep`
   substring in the pipeline.
2. A **CI invariant** that fails if any clean-subset accept reintroduces the anti-pattern, and
   that behaviorally proves a partial-pass fixture scores **RED** (where the old grep scored
   GREEN).
3. The RED invariant is preserved: every clean-subset seed still scores non-zero (RED).

## Non-goals

- The ~145 Exercism nodes (corpus#5). Their accepts are untouched here.
- Changing the `{meta, seed, RED}` node shape, the manifest, or attribution.

## Acceptance

- **Static (RED-first):** a check asserting no clean-subset `accept` pipes into `grep` — **fails
  against the current grep-based katas**, passes after the fix.
- **Behavioral partial-pass fixtures** (per available toolchain): a multi-test project with some
  passing and some failing tests, producing the exact fooling outputs (`1 failed, N passed`;
  a multi-binary cargo `ok` line; `N passing`/`N failing`). The **new** exit-code accept scores
  it **RED**; the **old** grep accept is shown to score it GREEN (documents the bug it fixes).
- **RED-invariant:** each fixed kata's accept run against its unmodified seed exits **non-zero**.
- **GREEN spot-check:** a reference solution to each kata makes its accept exit **0** (validation
  evidence; reference solutions are not shipped into the RED corpus).
- CONTRACT.md updated: the accept mechanism is the runner exit code (docs-with-code).
