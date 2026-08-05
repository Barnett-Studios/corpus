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

None of these was found by the suite failing. Each surfaced only when someone went looking for a
property the suite was assumed to have — and in two cases the check that appeared to cover it was
passing, correctly, the whole time.

- **A node shipping `2 passed, 12 failed` and scoring GREEN.** `python-react`'s accept was
  `grep -qE '[1-9][0-9]* passed'` on runner output, which the "2 passed" satisfies. 222 of 250 nodes
  scored on a substring of stdout rather than on the runner's exit status — the practice the
  corpus's own contract forbids. *(corpus#15, repaired in #20.)*
- **26 cpp nodes that could not be solved at all**, while `verify-red-invariant.sh` printed
  `ok … RED (exit 1)` for every one of them, every run. Each `CMakeLists.txt` derived its source
  filenames from the *work directory*, so cmake failed at configure in any scratch dir
  (`Cannot find source file: tmp.Lw4Jihzyc6_test.cpp`). RED, correctly reported, for entirely the
  wrong reason. *(corpus#14; 24 of the 26 are now instruments.)*
- **145 nodes grading on exactly one test of the many their suite ships.** Four of the six tracks
  ship every test after the first disabled (`#[ignore]`, `@Disabled`, `xtest`,
  `#if EXERCISM_RUN_ALL_TESTS`) so a learner enables them one at a time — cpp, java, javascript and
  rust; go and python ship theirs fully enabled. The port inherited the convention verbatim. `rust-acronym` ran 1 of its 10 tests, and
  `fn abbreviate(_: &str) -> String { "PNG".to_string() }` scored it GREEN.
  *(corpus#21 — found by this census, not previously known.)*
- **A whole language stratum whose verdict depended on which toolchain happened to be on `PATH`.**
  All 47 gradle accepts invoked bare `gradle`, which resolves to whatever is installed (the six
  hand-authored java nodes use `javac` directly and were never exposed). On Gradle 9.x all 47 gradle
  nodes fail with *"Failed to load JUnit Platform"* — environmentally RED and unsolvable, exactly
  the cpp class. The seeds ship a wrapper pinned to 8.7, but `gradle-wrapper.jar` was missing, so
  `./gradlew` could not run either. Under a real 8.7 the stratum is healthy — **and two nodes CI
  had always reported RED turn out to be GREEN on the untouched seed**. *(Pinned in #23.)*
- **Six nodes whose seed was never meant to fail.** `go-ledger`, `java-ledger`,
  `javascript-ledger`, `go-markdown` and `java-tree-building` are upstream **refactoring**
  exercises — their premise is that the code already works and reads badly — and `go-counter` is an
  upstream-*deprecated* exercise where the task is to write the test suite — so it has no
  acceptance test to fail, which is a different thing again. Of the five refactoring nodes, the
  three `ledger` ones say it outright in the corpus's own `meta.yaml` — *"The code however is
  rather badly written, though (somewhat surprisingly) it consistently passes the test suite"* —
  and `go-markdown` says it in its own words: *"somehow it works and all the tests are passing!"*
  Only `java-tree-building` leaves it to inference, describing the task as refactoring "a working
  but slow and ugly piece of code". All six were selected for a corpus whose defining invariant is
  that every seed ships failing.

  *One cause, filed across three tickets: corpus#11 (the go nodes), #16 (`javascript-ledger`), and
  #23 — where `java-ledger` and `java-tree-building` appear because they were **invisible until the
  gradle toolchain was pinned**. `gradle-wrapper.jar` was absent from the very first import commit,
  so no java test had ever run; and for as long as the RED-invariant check existed, it reported
  them RED.*

**The resolution: `N_instrument = 230 of 250`, and all 230 grade on their full acceptance suite** —
3,613 tests across the 250 nodes, after #21 re-enabled the 2,219 that had shipped disabled across
152 of them. One row per node in
[`docs/census/validity-census.tsv`](docs/census/validity-census.tsv), each carrying the evidence
that produced its verdict, so a reader can audit a call rather than trust it. The full write-up is
[`docs/census/`](docs/census/README.md).

### What this is not

**None of the five is a defect in upstream.** Two were written here; three are upstream content
that a porting decision made here broke. That distinction is the honest one, and it is finer than
"our bugs".

**Written here — two.** The grep oracle and the unpinned `gradle test` both live in `accept:`, a
field this corpus invented — upstream ships per-track runner tooling, but nothing that commits a
per-node shell string as data. Nobody but this project ever chose either string.

**Upstream content, broken by a decision made here — three.**

- The cpp `CMakeLists.txt` derived the exercise name from its own directory
  (`get_filename_component(exercise ${CMAKE_CURRENT_SOURCE_DIR} NAME)`) — upstream's line, and
  correct upstream, where the directory *is* the exercise name. It broke because this harness
  materialises each seed into a randomly-named scratch dir. The pin that replaced it is ours; the
  line that failed was not.
- The disabled suites are upstream's by design: a learner enables the tests one at a time. The
  defect was not re-enabling them when building a *graded* corpus, where nobody is learning.
- The six passing-seed nodes are upstream exercises working as upstream meant them to —
  a refactoring exercise is supposed to start green, and `go-counter` is a deprecated exercise
  shipping zero tests because the learner is meant to write them. The defect was **selecting** them
  for a corpus whose defining invariant is that every seed ships failing. Nothing that makes them
  pass was introduced here.

So this is not evidence that everyone else's acceptance suite is broken in these ways. The
transferable claim is narrower: **a suite reports on the property it was built to check, and is
silent on every property nobody built a check for.** No class here was caught by a test going red
on its own; each surfaced only when someone wrote a check for something the suite was assumed to
guarantee.

Writing the check was not always enough, and the five classes split three ways by how they actually
surfaced.

- **Two fell out of a check that failed the first time it ran** — the grep oracle and the
  passing-seed nodes, both from the RED-invariant sweep added in #3, which went red on six nodes
  immediately and a seventh shortly after.
- **Two were checks that passed for the wrong reason.** `verify-red-invariant.sh` reported RED for
  all 26 cpp nodes and all 47 gradle nodes, correctly, on every run — while in neither stratum did a
  single test execute. cpp surfaced because someone noticed each pass took ~0.17s, below the floor
  for a cmake configure alone, and went looking. java surfaced by accident: the census host happened
  to have a Gradle the seeds' wrapper does *not* name, on which all 47 fail before any test runs.
  Under the 8.7 the wrapper does name, the stratum is healthy — so the defect was only ever visible
  from the wrong host. **A check that passes for the wrong reason is the hardest kind to find,
  because the only signal it leaves is in the shape of a green result.**
- **One was a quantity nobody had built a threshold for** — the disabled suites. At the time,
  nothing in `ci/` asserted anything about how many tests ran, so no check could have failed; the
  mechanism differs per track, which is why no single grep found it earlier either. #21 added the
  missing assertion as part of the fix — `verify-accept-oracle.sh` now fails any node that "ships
  disabled test(s)" — so this gap is closed, unlike the fifth question's for five of six toolchains.

The middle pair is the part worth carrying away, and not for the reason it first appears. Both were
invisible to the check that *looked* like it covered them — but `verify-red-invariant.sh` asserts
only that `accept` exits non-zero on the untouched seed, and a toolchain that never reached the
tests exits non-zero exactly as reliably as an unimplemented stub. It was never written for the
property everyone read its green tick as guaranteeing. The guard that would have caught both — a
check that the *runner actually ran*, not merely that the command failed — did not exist, and was
still an open proposal when the census found the second instance.

So this is not a case of writing the check and having it fail you. It is the thesis above,
arriving in its most expensive form: **the property had no check, and an adjacent check's green
tick was mistaken for one.** java was found because cpp had prompted the census that swept the
whole corpus — not because anyone had learned to reread that script's passes.

**The transferable asset is the validation method, not the finding.**

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

The first four are mechanised here: [`ci/verify-accept-oracle.sh`](ci/verify-accept-oracle.sh),
[`ci/verify-red-invariant.sh`](ci/verify-red-invariant.sh),
[`ci/prove-solvable.sh`](ci/prove-solvable.sh), and the two-stage sweep in
[`ci/census/`](ci/census/). **The fifth is mechanised for exactly one toolchain — the one that
already cost us.** After the java stratum's verdict turned out to depend on which Gradle was
installed, #23 taught `verify-accept-oracle.sh` to check the wrapper jar's published SHA-256 and to
fail any accept that invokes ambient `gradle` instead of the pinned `./gradlew`.

**It pinned Gradle, not the JDK those tests compile against** — none of the 47 `build.gradle` files
sets `sourceCompatibility`, `targetCompatibility` or `languageVersion`, so the java verdict can
still move on a different JDK. That is the same defect one layer down, inside the fix for it. The
other five toolchains have no pin at all, which is why the census names the versions it was taken
under — Gradle 8.7, **JDK 21**, cmake 4.4.2, go 1.24.3, node 24, python 3.13, cargo stable — and
treats that list as part of its result rather than a footnote. The question that cost the most is
the only one anyone mechanised, it took the cost to get there, and it is still only half done.

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

The Exercism nodes do not merely resemble public tasks — 220 of the 225 embed the upstream
instruction text **verbatim** in `change:`, and 19 of those carry it down to upstream's own
`~~~~exercism/note` markers. So a model may
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

Those defects are repaired for the 230 nodes the census calls instruments. **They are not repaired
everywhere:** 19 nodes remain `BROKEN` and one `UNUSABLE_BY_DESIGN` — 2 of the 26 cpp nodes (both
needing Boost, which `requires:` does not declare) and the six passing-seed nodes among them, with
corpus#11 still open. Those 20 are excluded from `N_instrument` rather than fixed, and the census
names each one with its reason.

Contamination is in a different category again — it is not repaired, and cannot be, because it is a
property of using public exercises. It remains the standing reason a measured effect on this
stratum might not hold.

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
