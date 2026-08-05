# corpus

[![Nodes](https://img.shields.io/badge/nodes-250-blue.svg)](MANIFEST.tsv)
[![Instruments](https://img.shields.io/badge/instruments-230-brightgreen.svg)](docs/census/README.md)
[![Languages](https://img.shields.io/badge/languages-6-blue.svg)](MANIFEST.tsv)
[![License](https://img.shields.io/badge/license-MIT%20(Exercism--derived)-green.svg)](LICENSE)

**Oracle / evidence plane · Stable** — feature-complete; maintenance only. The scope is finished,
not abandoned. See the [component map](https://github.com/Barnett-Studios) for how this fits the rest.

**A 250-node acceptance suite that everyone assumed worked, audited node by node, and found to be
lying — with the per-node evidence committed.**

The corpus is 250 failing seed projects across 6 languages: each a stub that does not yet pass its
acceptance test, the fixed substrate an A/B harness scores a change against. That is what it is
*for*. What makes it worth reading is that we asked a question nobody had asked it — **how many of
these nodes function as a measurement instrument at all?** — and the answer was not 250.

> Part of the Barnett Studios agentic-harness toolkit → cxpak · commitward · abproof · cascadr ·
> cordon · **corpus** · …

## What the audit found

Every one of these was live, in CI, reported as passing, for months.

- **A node shipping `2 passed, 12 failed` and scoring GREEN.** `python-react`'s accept was
  `grep -qE '[1-9][0-9]* passed'` on runner output, which the "2 passed" satisfies. 222 of 250 nodes
  scored on a substring of stdout rather than on the runner's exit status — the practice the
  corpus's own contract forbids. *(corpus#15, repaired in #20.)*
- **26 cpp nodes that could not be solved at all**, while `verify-red-invariant.sh` printed
  `ok … RED (exit 1)` for every one of them, every run. Each `CMakeLists.txt` derived its source
  filenames from the *work directory*, so cmake failed at configure in any scratch dir
  (`Cannot find source file: tmp.Lw4Jihzyc6_test.cpp`). RED, correctly reported, for entirely the
  wrong reason. *(corpus#14; 23 of the 26 are now instruments.)*
- **145 nodes grading on exactly one test of the many their suite ships.** Exercism ships every
  test after the first disabled (`#[ignore]`, `@Disabled`, `xtest`, `#if EXERCISM_RUN_ALL_TESTS`); the port
  inherited that verbatim. `rust-acronym` ran 1 of its 10 tests, and
  `fn abbreviate(_: &str) -> String { "PNG".to_string() }` scored it GREEN.
  *(corpus#21 — found by this census, not previously known.)*
- **A whole language stratum whose verdict depended on which toolchain happened to be on `PATH`.**
  `accept: gradle test` resolves to whatever `gradle` is installed. On Gradle 9.x all 47 gradle
  nodes fail with *"Failed to load JUnit Platform"* — environmentally RED and unsolvable, exactly
  the cpp class. The seeds ship a wrapper pinned to 8.7, but `gradle-wrapper.jar` was missing, so
  `./gradlew` could not run either. Under a real 8.7 the stratum is healthy — **and two nodes CI
  had always reported RED turn out to be GREEN on the untouched seed**. *(Pinned in #23.)*
- **Nodes with no acceptance test at all, and nodes shipping a complete implementation.**
  `go-counter`, `go-ledger`, `go-markdown`, plus `java-ledger` (a finished 168-line `Ledger.java`)
  and `java-tree-building`, invisible until the tests actually ran. *(corpus#11.)*

**The resolution: `N_instrument = 230 of 250`, and all 230 grade on their full acceptance suite** —
3,613 tests across the 250 nodes, after #21 re-enabled the 2,219 that had shipped disabled across
152 of them. One row per node in
[`docs/census/validity-census.tsv`](docs/census/validity-census.tsv), each carrying the evidence
that produced its verdict, so a reader can audit a call rather than trust it. The full write-up is
[`docs/census/`](docs/census/README.md).

### What this is not

**Four of the five defect classes were our own porting bugs.** The grep oracle, the cpp
work-directory paths, the inherited disabled suites and the unpinned java accept were all
introduced by *this project* when it adapted upstream exercises — not defects in upstream, and not
a universal truth about eval corpora. Only the fifth is inherent: `javascript-ledger` is an
upstream *refactoring* exercise whose premise is that the seed passes, so no accept oracle recovers
a RED state from it.

So this is not evidence that everyone else's acceptance suite is broken in these ways. It is
evidence that a suite can be green, in CI, for months, while measuring something other than what
its owners believe — and that the only way to know is to check each node against the specification
rather than against the suite's own reports. **The transferable asset is the validation method, not
the finding.**

## The method, as questions to ask any suite

1. **Does the accept criterion discriminate at all?** Score on the runner's exit status. A
   substring of its output is a different measurement that happens to correlate.
2. **Is it RED for the right reason, or did the toolchain never run?** From outside, an
   unimplemented stub and a build that never reached the tests are the same non-zero exit.
3. **Is GREEN reachable?** A test nothing can pass is not a hard test, it is a broken one.
4. **Does the suite grade its full surface, or one assertion of it?** A one-test bar produces
   passes that a full bar would not.
5. **Is the environment pinned, or is the verdict ambient?** If a different toolchain on `PATH`
   changes the answer, the toolchain is part of the result.

Every one is mechanised here: [`ci/verify-accept-oracle.sh`](ci/verify-accept-oracle.sh),
[`ci/verify-red-invariant.sh`](ci/verify-red-invariant.sh),
[`ci/prove-solvable.sh`](ci/prove-solvable.sh), and the two-stage sweep in
[`ci/census/`](ci/census/).

## What's here

- [`red-baseline/`](red-baseline/) — the **250 node projects** (`{meta, seed, RED}`), ~23 MB across 6
  languages. This is the corpus data itself.
- [`docs/census/`](docs/census/README.md) — the validity census: the per-node TSV, the method, and
  what it means for whether a paired experiment over this corpus can be powered.
- [`CONTRACT.md`](CONTRACT.md) — the `{meta, seed, RED}` per-node contract, the RED invariant, and the
  fail-open toolchain gate.
- [`MANIFEST.tsv`](MANIFEST.tsv) — machine-readable index of all 250 nodes (id, language, accept tool,
  seed license, third-party bundle, provenance).
- [`LICENSE`](LICENSE) · [`ATTRIBUTION.md`](ATTRIBUTION.md) — full provenance (Exercism MIT + bundled
  Catch2 BSL-1.0 + Gradle-wrapper Apache-2.0).
- [`verify-attribution.sh`](verify-attribution.sh) — regenerate or (`--check`) drift-check the manifest
  against the node data. Defaults to the bundled `red-baseline/`; override with `$CORPUS_ROOT`.

## Use

```sh
# verify attribution still matches the shipped data
./verify-attribution.sh --check

# point your A/B harness (e.g. abproof) at the corpus
ABPROOF_CORPUS=/path/to/red-baseline abproof run experiment.yaml --dry-run
```

## Contamination: 225 of 250 nodes are public benchmark tasks

**Read this before reporting an absolute score from this corpus.**

| stratum | nodes | provenance | leakage status |
|---|---|---|---|
| Exercism-derived | 225 | `provenance: "exercism"` | **contaminated** — public exercises, near-certainly in the pretraining data of every model under test |
| hand-authored | 25 | `provenance: "hand-authored"` | held out — written for this corpus, never published as exercises |

This was previously disclosed only as a **licensing** matter (`ATTRIBUTION.md`). It is also, and
more importantly, a **train/test leakage** problem, and it was never named as one.

The Exercism nodes do not merely resemble public tasks — many embed the upstream instruction
text **verbatim** in `change:`, including the original `~~~~exercism/note` markers. So a model may
have memorised both the prompt and a canonical solution. On such a node, a score measures
recall, not the capability the harness change was supposed to move.

### What this does and does not invalidate

- **Absolute solve-rate on the contaminated stratum is not a capability measurement.** Do not
  report it as one, and do not compare it against a published benchmark number.
- **A paired, within-node A/B may still be internally valid for the *relative* claim.**
  Memorisation inflates *both* arms of a paired comparison, so it largely cancels in the delta.
- **But it can destroy statistical power**, which is the trap. A memorised node tends to land
  first try in both arms, making it *concordant* — it contributes a zero delta and no
  information. Contamination therefore compresses the discordant-pair count, which is the
  denominator of power. An underpowered null then reads as "no effect" when it means "this
  battery could not have detected one".

So: contamination is not a reason to discard a paired result, and it is not a licence to trust
one either. **Report the two strata separately** — `provenance` in `MANIFEST.tsv` and in each
`meta.yaml` exists to make that mechanical — and report the discordant-pair count alongside any
null.

### Contamination was not the worst thing wrong with this stratum

The defects above were. They coincided with it almost exactly — the unsound oracle hit 222 of the
same 225 Exercism nodes and **0 of the 25** hand-authored — which is why the audit had to come
first: a reader who accepted the paired-comparison argument and used the Exercism stratum anyway
would have inherited all of them, not just the one this section is named after.

Those defects are repaired. Contamination is not, and cannot be: it is a property of using public
exercises. It remains the standing reason a measured effect on this stratum might not hold.

### The held-out stratum is small

25 nodes is enough to be honest with and not enough to be conclusive with. A paired experiment
over it detects only a very large effect; anything moderate escapes. Growing it is the way to a
conclusive result — not adding more Exercism nodes, which adds contaminated mass without adding
proportionate power. The power arithmetic across every stratum is in
[`docs/census/`](docs/census/README.md#what-it-means-for-the-experiment-corpus17-dotclaude34).

### Difficulty bands were removed

A `band` field existed on 250 nodes but was populated on 11 (220 empty strings, 19 absent). A
stratification variable that is 96% empty invites accidental misuse — a "hard-band" result read
from 7 nodes — so the field is gone rather than half-kept. Reintroduce it only fully populated.

## Adding a node

Drop a `red-baseline/<id>/` with `meta.yaml` + `seed/` (must ship **failing** — the RED invariant),
then `./verify-attribution.sh` to refresh the manifest. Additive; never a breaking change. A new
node earns a census row by passing all three instrument checks, not by existing.

## License

The adaptation layer (manifest, contract, scripts) is [MIT](LICENSE). The exercise
specifications, test suites, and starter files are Exercism-derived and remain under their
upstream licenses — see [`LICENSE`](LICENSE) and [`ATTRIBUTION.md`](ATTRIBUTION.md) for full
per-node provenance.

---

Built by [Barnett Studios](https://barnett-studios.com/) — part of the agentic-harness
toolkit: [cxpak](https://github.com/Barnett-Studios/cxpak) ·
[commitward](https://github.com/Barnett-Studios/commitward) ·
[abproof](https://github.com/Barnett-Studios/abproof) ·
[cascadr](https://github.com/Barnett-Studios/cascadr) ·
[cordon](https://github.com/Barnett-Studios/cordon) · **corpus** ·
[slicr](https://github.com/Barnett-Studios/slicr).
