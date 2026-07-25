---
title: GREEN is the runner's exit code, and the test lives outside the editable file
issue: Barnett-Studios/corpus#4
status: Proposed
created: 2026-07-22T08:51:51Z
updated: 2026-07-22T09:07:11Z
---

# ADR 0001 — GREEN is the runner's exit code

## Context

The corpus's core invariant is `accept | exit 0 ⇔ solved` (CONTRACT.md). The shipped accepts
break it in the clean subset (the 24 katas + `py-add`) two ways:

1. **The pipe discards the exit code.** Every kata accept pipes the test runner into
   `grep -q <success-substring>`, so the pipeline's exit status is **grep's**, not the runner's.
   The oracle is really "≥ 1 line matched a success substring", which scores partial passes GREEN
   (Spec 0001). Each kata runs a *single* immutable test, so this does not actively mis-score a
   kata *today*, but it violates the CONTRACT's letter and is a live hazard for any future
   multi-test node.
2. **For rust, the test co-lives in the editable file — and the `grep` was accidentally guarding
   it.** The rust katas set `files: ["src/lib.rs"]`, and the acceptance test lives *inside*
   `src/lib.rs` as `#[cfg(test)] mod tests`. The model may edit that file. `cargo test <filter>`
   **exits 0 when the filter matches zero tests** (verified). So a model that leaves the stub
   `todo!()` and deletes/renames the in-file test scores an *unsolved* node **GREEN**. The old
   accept's `grep -qE 'test result: ok\. [1-9]'` required a nonzero *passed count*, which
   incidentally rejected the zero-match state (RED) — a load-bearing side effect. Dropping the
   pipe without moving the test would **regress** rust oracle integrity (empirically reproduced:
   stub + deleted test → bare accept exit 0 GREEN; old grep exit 1 RED).

This redefines what GREEN means, so it is a CONTRACT-level decision.

## Decision

**GREEN ⇔ the test runner exits 0, and the acceptance test never lives in an editable
(`files:`) file.** Two coupled changes across the clean subset:

**(1) Drop the `grep` filter — the accept is the runner invocation itself.**

| lang | before | after |
|---|---|---|
| python | `python3 -m unittest -q <method> 2>&1 \| grep -qE '^OK'` | `python3 -m unittest -q <method>` |
| rust | `cargo test <filter> --quiet 2>&1 \| grep -qE 'test result: ok\. [1-9]'` | `cargo test <filter> --quiet` |
| go | `go test -run '^<Test>$' . 2>&1 \| grep -qE '^ok'` | `go test -run '^<Test>$' .` |
| java | `javac … 2>&1 && java TestRunner <name> 2>&1 \| grep -qx PASS` | `javac … && java TestRunner <name>` |

Each runner exits non-zero on any test failure and on a compile/collection error: the clean
subset's `python3 -m unittest -q <method>` exits non-zero on a failure or a missing test method
(and pytest, used by the out-of-scope Exercism nodes, exits 1 on failure / 5 on "no tests
collected"); `cargo test` exits non-zero if any run test fails or the
crate fails to compile; `go test` exits non-zero on failure or build error; the java harness
`TestRunner` prints `PASS`/exits 0 on success and `System.exit(1)`/`exit(2)` on failure/bad-arg
(verified in `seed/TestRunner.java`), so the `&&`-chained `javac && java` yields the correct code.
`py-add` already uses a bare exit code and is unchanged.

**(2) Relocate the rust test out of the editable file.** Move `#[cfg(test)] mod tests` from
`src/lib.rs` into a non-editable integration test `tests/katas.rs` (`use eval_rust::*;` — every
tested function is already `pub`). The model still edits only `src/lib.rs`'s impl; the test is now
un-deletable, so `cargo test <filter>` always finds its (present) test. Empirically: stub → RED
(exit 101); correct impl → GREEN (exit 0); **editable file emptied → RED (compile error, exit
101)** — the false-GREEN hole is closed. go/java/python already keep the test in a non-editable
file (`util_test.go` / `TestRunner.java` / `test_util.py`); only rust needed relocating.

**The structural invariant that guards this:** *no file listed in a node's `files:` may contain a
test-definition marker* (rust `#[test]`/`#[cfg(test)]`, go `func Test`/`Example`/`Benchmark`,
python `def test`/`unittest`, java `@Test`/`TestRunner`). A CI check enforces it (fails for the rust
katas until relocation, passes for the other three languages already).

`ci/verify-accept-oracle.sh`'s static check (A) forbids **any** pipe in an accept, not just `grep`
— a pipe into `rg`/`awk`/`perl`/`sed` discards the runner's exit code the same way. The clean-subset
accepts are bare runners or `&&`-chains, so any `|` is the anti-pattern. The script also asserts the
clean subset's node count (a drift tripwire against a renamed/dropped node scoring the gate
vacuously green) and the CI job requires every toolchain to be present (so no check silently skips).

## Why drop the pipe rather than `set -o pipefail`

For the runners whose test is non-editable, dropping the pipe removes the root cause: the
substring pattern is the defect, and `pipefail`+grep keeps a fragile output-format dependency
(`'test result: ok\. [1-9]'` breaks the day a runner reformats its summary) that adds nothing once
the exit code is authoritative. "exit 0 ⇔ solved" *is* the runner's exit code; the accept should
be exactly that.

The one place `pipefail`+grep did real work — the rust `[1-9]` passed-count guard against the
zero-match state — is a symptom of the actual defect (an editable test), not a reason to keep the
grep. Retaining grep for rust only would (a) preserve the brittle substring, (b) carve a rust
exception into the "no accept contains grep" invariant, and (c) leave the editable test in place
where a renamed test still silently changes what is scored. Relocating the test fixes the root
cause and lets the exit-code oracle be uniform across all four languages. Rejected: keep grep.

## Alternatives considered

- **`set -o pipefail` + keep the grep (all langs, or rust-only).** Correct on the exit code, but
  retains the brittle substring, and rust-only keeps the editable-test root cause. Rejected — see
  above.
- **Run rust unfiltered (`cargo test`) so a missing test can't hide.** Runs all six functions'
  tests; five are still `todo!()` in a single-region kata → the node can never go GREEN. Breaks
  the single-region kata design. Rejected.
- **Exclude rust from this ticket.** Leaves 6 of 24 katas CONTRACT-violating and unfixed, failing
  the ticket's own goal. Rejected.
- **A shared wrapper script (`accept.sh <runner> …`).** Over-engineering for a one-line change.
  Rejected — the runner invocation is the clearest possible accept.
- **Fix all 250 nodes now.** Out of scope: the ~145 Exercism nodes are separately contaminated
  (corpus#5); mixing their de-contamination in would obscure the pattern and balloon the diff.

## Contract impact & HITL

This redefines the corpus's core invariant (what GREEN means) and moves the rust acceptance test →
a CONTRACT.md change, updated in the same commit (docs-with-code). `detect-hitl` is run before
finalizing; a fired checkpoint is a human sign-off point.

## Falsifier

The decision is **wrong** if, under the new accepts, any of these hold. Pre-registered checks
(the CI invariant + the reference-solution spot-check):

- a partial-pass fixture (some tests pass, some fail) scores GREEN — the pipe-discard mechanism
  fixture must score RED under a bare runner and is shown GREEN under the old grep;
- a fully-solved node scores RED — a reference solution per language makes all its katas exit 0;
- a fixed kata's unmodified seed scores GREEN — every seed must exit non-zero (RED-invariant);
- **a rust node with its editable file emptied scores GREEN** — must exit non-zero (relocation);
- any editable (`files:`) file still contains its acceptance test — the structural check must fail.
