---
title: GREEN is the runner's exit code, not a success substring
issue: Barnett-Studios/corpus#4
status: Proposed
created: 2026-07-22T08:51:51Z
updated: 2026-07-22T08:51:51Z
---

# ADR 0001 — GREEN is the runner's exit code

## Context

The corpus's core invariant is `accept | exit 0 ⇔ solved` (CONTRACT.md). The shipped accepts
break it by testing a **success substring** of the runner's output via `grep -q`, which discards
the runner's exit code and scores partial passes GREEN (Spec 0001). This redefines what GREEN
means, so it is a CONTRACT-level decision.

## Decision

**GREEN ⇔ the test runner exits 0. The accept is the runner invocation itself, with no
`grep`-substring filter.** For the clean subset:

| lang | before | after |
|---|---|---|
| python | `python3 -m unittest -q <method> 2>&1 \| grep -qE '^OK'` | `python3 -m unittest -q <method>` |
| rust | `cargo test <filter> --quiet 2>&1 \| grep -qE 'test result: ok\. [1-9]'` | `cargo test <filter> --quiet` |
| go | `go test -run '^<Test>$' . 2>&1 \| grep -qE '^ok'` | `go test -run '^<Test>$' .` |
| java | `javac … 2>&1 && java TestRunner <name> 2>&1 \| grep -qx PASS` | `javac … && java TestRunner <name>` |

Each runner exits non-zero on any test failure, and non-zero on a compile/collection error:
pytest exits 1 on failure / 5 on "no tests collected"; `cargo test` exits non-zero if any test
in any binary fails; `go test` exits non-zero on failure; and the java harness `TestRunner`
already prints `PASS`/`FAIL` **and exits non-zero on failure** (verified in
`seed/TestRunner.java`), so the `&&`-chained `javac && java` yields the correct code. `py-add`
already uses a bare exit code and is unchanged.

## Why drop the pipe rather than `set -o pipefail`

Both fix the exit-code discard. We drop the pipe because:

1. **It removes the root cause.** The substring pattern is the defect; `pipefail` keeps a fragile
   output-format dependency (`'[1-9][0-9]* passed'` breaks the day a runner reformats its
   summary) that adds nothing once the exit code is authoritative.
2. **It is the literal CONTRACT.** "exit 0 ⇔ solved" *is* the runner's exit code; the accept
   should be exactly that.
3. **The "0 tests collected → exit 0" edge does not apply.** The model may edit only its impl
   file (`files:`), never the immutable acceptance test, so the fixed test filter always matches
   a real, present test. The RED-invariant CI check (every seed scores non-zero) is the backstop
   that would catch any node where the runner exits 0 without the test actually running.

## Alternatives considered

- **`set -o pipefail` + keep the grep.** Correct on exit code, but retains the brittle substring
  and does not remove the anti-pattern the CI invariant is meant to forbid. Rejected.
- **A shared wrapper script (`accept.sh <runner> …`).** Over-engineering for a one-line change;
  adds a moving part to every node's work dir. Rejected — the runner invocation is already the
  clearest possible accept.
- **Fix all 250 nodes now.** Out of scope: the ~145 Exercism nodes are separately contaminated
  (corpus#5) and mixing their de-contamination into this change would obscure the pattern and
  balloon the diff.

## Contract impact & HITL

This redefines the corpus's core invariant (what GREEN means) → a CONTRACT.md change. CONTRACT.md
is updated in the same commit (docs-with-code). `detect-hitl` is run before finalizing; a fired
checkpoint is a human sign-off point.

## Falsifier

The decision is **wrong** if a partial-pass fixture (some tests pass, some fail) scores GREEN
under the new accept, or if a fully-solved node scores RED. Pre-registered behavioral checks:
a `1 failed, N passed` fixture must exit non-zero under the new accept (it exits 0 under the old
grep); each fixed kata's seed must exit non-zero (RED); a reference solution must exit 0 (GREEN).
