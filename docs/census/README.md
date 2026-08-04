# The validity census

**`N_instrument = 230` of 250 — and all 230 grade on their full acceptance suite.**

One row per node in [`validity-census.tsv`](validity-census.tsv). It answers the question the
corpus had never been asked: *how many of these nodes function as a measurement instrument?*
Everything downstream — whether a paired A/B is powered, whether an authoring program is needed,
how large it must be — was being sized against a guess, because that denominator had never been
measured.

## What "instrument" means

A node is usable only if **all three** hold. Any one failing makes its verdict uninformative:

| column | question | how it was measured |
|---|---|---|
| `oracle_sound` | does the accept score on the runner's **exit status**? | static, all 250 (corpus#15 / PR #20) |
| `red_for_right_reason` | is it RED on the untouched seed **because the stub is unimplemented**, rather than because the toolchain never ran? | every accept run against a pristine seed; the runner's own output classified per language |
| `green_reachable` | does a reference solution actually reach GREEN? | reference solution overlaid, accept re-run |

`verdict` is `INSTRUMENT`, `BROKEN`, or `UNUSABLE_BY_DESIGN`. Every row carries the evidence that
produced it, so a reader can audit a call rather than trust it.

## Result

| | nodes |
|---|---|
| **INSTRUMENT** | **230** |
| BROKEN | 19 |
| UNUSABLE_BY_DESIGN | 1 |

| column | outcome | nodes |
|---|---|---|
| `oracle_sound` | yes | 250 |
| `red_for_right_reason` | TASK — the runner ran and the stub failed it | 242 |
| | NOT_RED — accept exits 0 on the seed | 6 |
| | ENV — RED because the toolchain never got there | 2 |
| `green_reachable` | PROVEN | 235 |
| | UNPROVEN | 15 |

By provenance — and the split is the whole point:

| stratum | nodes | instruments | of which grade on their **full** suite |
|---|---|---|---|
| hand-authored (held out) | 25 | 25 | **25** |
| Exercism (contaminated) | 225 | 205 | **205** |
| | | **230** | **230** |

## The second bar closed (#21)

The first version of this census reported two bars, because 136 of its 232 instruments graded on
**one test out of many** — Exercism's convention of shipping every test after the first disabled
(`#[ignore]`, `@Disabled`, `xtest`, `#if EXERCISM_RUN_ALL_TESTS`), inherited verbatim. `rust-acronym`
ran 1 of 10 tests, and `fn abbreviate(_: &str) -> String { "PNG".to_string() }` scored it GREEN.

#21 re-enabled them: **2,219 tests across 152 nodes**, and every one of the 250 nodes now runs its
full suite (3,613 tests). The cost was two nodes.

| | before #21 | after #21 |
|---|---|---|
| INSTRUMENT | 232 | **230** |
| …grading on their full suite | 96 | **230** |

Re-enabling did not, as expected, trade too-easy nodes for unsolvable ones. Upstream examples
satisfy full suites — which upstream's own CI implies, but nothing here had checked. What it did
instead was **expose three port-drift cases** that a one-test bar had hidden (`java-sgf-parsing`,
`javascript-forth` at 6 failed / 43 passed of 49, `javascript-phone-number`), and **fix one false
negative**: `cpp-complex-numbers` was scored unsolvable because the seeds set `-Werror` and a
helper in its own test file goes unused when only one test compiles —
`error: unused function 'require_approx_equal' [-Werror,-Wunused-function]`. It builds cleanly with
the full suite.

So the disabled-suite defect was distorting the census in **both** directions at once, and both
distortions were invisible for the same reason.

## What was actually wrong, by class

The census confirms four of the five classes already filed and adds two that were not.

**Confirmed.**

- **corpus#15 — grep oracle, 222 nodes.** Repaired in PR #20. Measured under both oracles first:
  no node's verdict on its own seed flips, so the conversion is not a rescoring of the baseline.
- **corpus#11 — content defects.** `go-counter` (no acceptance test at all), `go-ledger`,
  `go-markdown` (complete implementations shipped).
- **corpus#16 — `javascript-ledger`.** The one `UNUSABLE_BY_DESIGN`: an upstream *refactoring*
  exercise whose premise is that the seed passes. No accept oracle recovers a RED state.
- **corpus#14 — cpp.** Confirmed, and worse than the ticket inferred from timings. Every
  `CMakeLists.txt` derived its **source filenames** from the work directory, so cmake failed at
  *configure* in any scratch dir (`Cannot find source file: tmp.Lw4Jihzyc6_test.cpp`), and no cpp
  node registers a `ctest` test, so the shipped accept's `grep '0 tests failed'` leg was
  unsatisfiable. All 26 were RED for an environmental reason and unsolvable — while
  `verify-red-invariant.sh` reported `ok … RED (exit 1)` for every one of them, every run.
  Repaired in PR #20: **23 of 26 are now instruments.**

**Not previously known.**

- **corpus#21 — 149 nodes ship most of their suite disabled**, 145 of them grading on exactly one
  test. Filed from this census.
- **The java accept is unpinned, and it hid two GREEN nodes.** `accept: gradle test` resolves to
  whatever `gradle` is on PATH. On Gradle 9.x every one of the 47 gradle nodes fails with
  *"Failed to load JUnit Platform"* — RED for an environmental reason, unsolvable, exactly cpp's
  class. The seeds ship a wrapper pinned to 8.7, but `gradle/wrapper/gradle-wrapper.jar` is
  missing, so `./gradlew` cannot run either. Under a real 8.7 the stratum is healthy (45 of 47
  nodes run their tests and reach GREEN with a reference solution) — **and two nodes that CI has
  always reported RED turn out to be GREEN on the untouched seed**: `java-ledger` (a complete
  168-line `Ledger.java`) and `java-tree-building`. Both are corpus#11's class, invisible until
  the tests actually ran. Filed separately.

## Method

Two stages, so a re-classification never costs a re-run.

1. **Run.** Every node's accept against a pristine copy of its seed, output captured.
2. **Classify.** Per-language signatures separate *the stub failed the test* from *the toolchain
   never got there*. `pytest` exit 1 vs 2; `[build failed]` naming the node's own package;
   `Execution failed for task ':test'` vs `Could not resolve`; a `_test.cpp.o` compile error vs a
   `CMake Error`.

`green_reachable` at 225-node scale needed no authoring: every Exercism node maps 1:1 onto an
upstream exercise that ships a canonical example (`.meta/example.*`, `.meta/proof.ci.js`,
`.meta/src/reference/java/`). Slug coverage was **225 of 225**. Reference solutions live outside
`red-baseline/` and are never shipped into it — abproof reads only `red-baseline/`, so it must
never see one.

### What the census does not establish

- The 13 `UNPROVEN` nodes are **not** proven unsolvable. In each case the *upstream example*
  failed against the *corpus's* test file — port drift between the two — so the honest reading is
  "no reference solution has reached GREEN", not "no solution can".
- `cpp-gigasecond` and `cpp-meetup` require Boost, which `requires:` does not declare. They are
  ENV-broken on any host without it; the fix is a `requires:` entry, not a seed change.
- Toolchain versions matter. This census was taken with Gradle **8.7** (the version the seeds'
  own wrapper names), cmake 4.4.2, go 1.24.3, JDK 21, node 24, python 3.13, cargo (stable). The
  java result would have been entirely different on Gradle 9 — which is why #23 pinned it. The
  other five toolchains are still unpinned, so this list is part of the result, not a footnote.

## Reproducing it

`ci/census/` holds the two stages and the power derivation. The full sweep is ~1 hour of machine
time across six toolchains, so it is not wired into CI; the committed TSV is the artifact, and the
scripts exist so a reader can re-derive rather than take it on faith.

## What it means for the experiment (corpus#17, dotclaude#34)

dotclaude#34 measured the discordant rate on the **clean 24-kata stratum**: `d = 9/24 = 0.375`,
95% CI `[0.212, 0.573]`. Its power model is reproduced exactly by `ci/census/power.py` — 0.138 at
N=25, and 138 / 245 nodes for 80% power at π=0.70 / 0.65.

Applying it to the measured N:

| stratum | N | π=0.60 | π=0.65 | π=0.70 (large) |
|---|---|---|---|---|
| all instruments | **232** | 0.42 | **0.78** | **0.96** |
| full-suite instruments | 96 | 0.18 | 0.37 | 0.62 |
| clean + full-suite | 25 | 0.05 | 0.08 | 0.14 |

**If `d` holds on the repaired Exercism stratum, the experiment is already powered for a large
effect at N=232 — without authoring a single node.** #34 computed that prize conditionally
("power at N=250 would be … 0.97 (π=0.70)") and could not claim it, because the stratum was
unsound. The census is what makes it claimable.

### The confound is resolved, not caveated

The first version of this census reported 0.96 at N=232 with a warning attached: it took `N` from
one population and `d` from another. `d = 0.375` was measured on the clean 25, which are **25 of 25
full-suite**; it was being applied to 232 nodes of which 136 graded on a single test. The
sensitivity ran the wrong way, too — an easier pass bar produces concordance, concordance
suppresses the *measured* `d`, and a low `d` is exactly what would have justified an expensive
authoring program.

**#21 closed that gap.** All 230 instruments now grade on their full suite, so `N` and `d` are
drawn from populations with the same pass bar. The arithmetic is barely different; what changed is
that it is now a legitimate calculation rather than an extrapolation across two bars.

| stratum | N | π=0.60 | π=0.65 | π=0.70 (large) |
|---|---|---|---|---|
| **post-#21 — all instruments, all full-suite** | **230** | 0.42 | **0.77** | **0.96** |
| pre-#21 — full-suite subset only | 96 | 0.18 | 0.37 | 0.62 |
| pre-#21 — all instruments (mixed bar, **not valid**) | 232 | 0.42 | 0.78 | 0.96 |
| clean + full-suite (held-out) | 25 | 0.05 | 0.08 | 0.14 |

The pre- and post-#21 headline figures differ by 0.001. That is the point worth keeping: **#21 was
not worth doing because it moved the number, it was worth doing because it made the number mean
something.** Had the bars not been reconciled, the same 0.96 would have rested on 59% of the
population being one-assertion nodes.

**The binding constraint is now `d`, and only `d`.** Contamination remains a reason it might not
hold on this stratum — a memorised node lands first try in both arms and contributes nothing — but
the second mechanism (#21's one-assertion bar) is gone.

Sensitivity at N=230:

| d | π=0.65 | π=0.70 | N needed for 80% at π=0.70 |
|---|---|---|---|
| 0.573 (upper CI) | 0.93 | 1.00 | 90 |
| **0.375 (measured)** | **0.77** | **0.96** | **138** |
| 0.30 | 0.67 | 0.91 | 172 |
| 0.25 | 0.58 | 0.85 | 207 |
| 0.212 (lower CI) | 0.51 | 0.78 | 244 |
| 0.15 | 0.36 | 0.60 | 345 |

Even at the pessimistic end of `d`'s own CI (0.212), N=230 gives 0.78.

So the next act is the cheap one #34 already named — **measure `d` before committing to an
authoring program**, because `d` is a rate and needs far fewer runs to pin than a difference does
— and that is now unblocked: #23 fixed the population's size (a runner resolving Gradle 9 would
have made it 185 rather than 230) and #21 fixed its pass bar. See corpus#17 for the derivation and the
decision it gates.
