# corpus — Contract

The **corpus**: a collection of RED-baseline tasks that an A/B eval harness (such as abproof)
scores a harness change against. Each task is a **failing seed project** plus the metadata to run and
score it — the fixed measurement substrate, kept separate from the harness that measures it.

## Versioning

The corpus is versioned. `VERSION` holds the current number and every release carries a matching
`v<version>` tag, so a consumer can pin a **version** rather than a commit SHA.

That distinction is not bookkeeping. This repo had no version at all until 0.1.0, so the only way to
depend on it was a raw SHA — and dotclaude's submodule pointer sat five commits behind for twelve
days, through two oracle *soundness* fixes, with nothing able to describe the gap as a version skew
(dotclaude#66). A SHA pin cannot be compared; a version pin can.

Semantics under the 0.x rule, where the **minor** is the breaking position:

| Change | Bump |
|---|---|
| a node's `accept`, oracle mechanism, or seed layout changes | **minor** — a consumer's loader may no longer materialize it |
| nodes added or removed | **minor** — battery composition moves, so scores are not comparable across it |
| metadata-only fields, prose, CI | patch |

Composition changes are deliberately breaking: a battery whose membership shifted produces numbers
that must not be compared to the previous one, and a version that says so is the cheapest way to
stop someone doing it by accident.

## Per-node shape: `{meta, seed, RED}`

Each node is a directory `red-baseline/<id>/`:

```
<id>/
  meta.yaml            # the descriptor (below)
  seed/                # the complete RED project: stub source(s), the acceptance
                       # test(s), scaffold (Cargo.toml / go.mod / build.gradle / …),
                       # and any seed/LICENSE
  context.md           # optional: extra context shown to the model
```

Legacy nodes carry a flat `stub.<ext>` + `acceptance_test.<ext>` pair instead of `seed/`; loaders
synthesize the seed from that pair.

`meta.yaml`:

| Field | Meaning |
|---|---|
| `id` | node id (matches the directory name) |
| `language` | `cpp` \| `go` \| `java` \| `javascript` \| `python` \| `rust` |
| `files` | editable files (relative to the node work dir) the model may change; the acceptance test is **never** among them (see below) |
| `accept` | shell command run in the work dir; **exit 0 ⇔ the task is solved** — the test runner's own exit status, **not** a `grep` of its output (a success-substring filter discards the runner's exit code and scores partial passes GREEN) |
| `forbid` | constraints (e.g. `new_deps`) the change must not violate |
| `requires` | toolchain executables that must be on PATH; **absent ⇒ node SKIPPED, never failed** |
| `change` | the task description shown to the model |
| `provenance` | `"exercism"` (contaminated — a public exercise) or `"hand-authored"` (held out). **Declared, never inferred**: it decides which nodes count as held-out, so it is not left to a filename heuristic. See the contamination section below |

## The RED invariant

Every node ships **failing** (`accept` returns non-zero against the seed): the stub is unimplemented.
That is the point — a harness change is scored by how often it turns RED into GREEN. A node whose seed
already passes is a corpus bug, not a task: it is a free point for *both* arms of every A/B, so it
inflates solve-rate while contributing no discriminating signal.

`ci/verify-red-invariant.sh` enforces this in CI over **every** node, sharded by language, materialising
each seed and asserting `accept` exits non-zero. A node that is GREEN at HEAD fails the build and is
named. It is the complement of `ci/prove-solvable.sh`: together they bracket the oracle — RED on the
seed, GREEN on a reference solution. Neither alone suffices, since an accept that *always* fails passes
the first and an accept that *always* succeeds passes the second.

Fail-open per node on toolchain (an absent `requires:` executable SKIPs, per the table above);
fail-loud on vacuity (a sweep that checked nothing exits non-zero rather than reporting green over an
empty set).

**What a passing RED sweep does not establish.** It shows `accept` exits non-zero on the seed. It
cannot distinguish "RED because the stub is unimplemented" from "RED because the toolchain never
reached the tests". A broken-unsolvable node passes it. GREEN-reachability is `prove-solvable.sh`'s
job and that covers only the 25-node clean subset, so the 225 Exercism nodes have their RED verified
and their solvability unverified.

## The acceptance test is not editable

The acceptance test must live **outside** the node's `files:` set (e.g. go's `util_test.go`, rust's
`tests/`, java's `TestRunner.java`, python's `test_util.py`) — never inside an editable file. If the
test co-lives with the impl the model may edit, a model can score an *unsolved* node GREEN by
deleting or renaming the test (some runners, e.g. `cargo test <filter>`, exit 0 when the filter
matches zero tests). `ci/verify-accept-oracle.sh` enforces both this and the exit-code rule above,
and is wired into CI for the clean subset (the 24 hand-authored katas + `py-add`).

## The acceptance test does not share a process with the model's code

Not editing the test is not enough. Where the model's code and the assertions run in **one
process**, the model can score an unsolved node GREEN without touching the test at all — it need
only edit the file every node already lets it edit:

- **exit-zero** — end the process with status 0 before the assertions run (`os._exit(0)`,
  `std::process::exit(0)`, which returns `!` and so type-checks anywhere, `System.exit(0)`).
- **neuter** — replace the assertion machinery with no-ops (`unittest.TestCase.assert*`).

So every clean-subset acceptance test is a **supervising parent**. A fixed, non-editable probe
(`probe.py`, `src/main.rs`, `UtilProbe.java`) is the only caller of the model's code; it computes
observations, prints them, and asserts nothing. The test runs that probe as a **subprocess** and
judges its output, requiring **positive evidence** — a complete, matching observation — rather than
merely a zero exit. A child that dies early prints nothing, and a neutered assertion library in the
child is irrelevant to a parent that does its own asserting.

Go already had this shape: `go test` supervises a child test binary and requires evidence of
completion. The other three languages now match it. `ci/verify-oracle-sabotage.sh` enforces it in
CI, replaying both vectors against every clean-subset node.

Both probes are bounded: a child that has not produced complete output within 60s is killed and
scores RED. A measurement harness that hangs is worse than one that fails, and a hung
implementation is not a pass. The observation channel is pinned to UTF-8 on both sides rather
than inherited from the locale, so a correct answer containing `…` cannot be turned into an
encode error by a C/POSIX environment.

**The limit, stated plainly.** This does not make the oracle adversarially sound. The probe is still
a process the model's code runs inside, so it can *forge* the expected observations on stdout and
exit 0 — and that works against **go too**, so it is a property of the execution model, not of any
one language's runner. What changed is the cost: exit-zero and neuter are one-line, task-independent
sabotage that works on every node in the corpus; forging requires producing the exact expected
output for one specific kata. Closing the remainder needs the harness to run `accept` under process
isolation (see `cordon`), which is outside what corpus data can express.

## Toolchain gating (fail-open)

`requires` is a hard gate: if any listed tool is missing, the node is **skipped**, never scored as a
failure — so a corpus with `java-*` nodes stays honest on a host without a JDK. Pure-Python /
JavaScript nodes carry `requires: []`.

## Consumption

- **abproof** reads the corpus via `$ABPROOF_CORPUS` pointing at `red-baseline/`,
  loads a battery by id/glob, and materializes each node's seed into a clean git work tree per rep.
- The `{meta, seed, RED}` shape is the stable contract; adding nodes or languages is additive, not a
  breaking change. `MANIFEST.tsv` is the machine-readable index; `verify-attribution.sh --check`
  gates it against the data.

## Licensing

Exercism-derived (MIT) + bundled Catch2 (BSL-1.0) and Gradle wrapper (Apache-2.0). See
[`ATTRIBUTION.md`](ATTRIBUTION.md) and [`LICENSE`](LICENSE). Public redistribution is *intended* to be
gated behind a legal-review checkpoint (permissive licenses, but a human's sign-off) — **proposed, not
yet registered** in `promise/checkpoints.yaml`; the consume-back adds it before any public flip.

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

### Contamination is not the worst thing wrong with this stratum

This section would mislead if it stopped here, because it documents the *lesser* risk in detail.
The same nodes carry two further defects, and by this project's own analysis the first outranks
contamination:

- **The accept oracle was unsound (#15) — 222 of the 225. Repaired.** They scored by `grep` on
  runner output instead of on the runner's exit status, the practice this contract forbids two
  sections up. The demonstration case was `python-react`: it ships **2 passed, 12 failed** and
  scored GREEN, because `grep -qE '[1-9][0-9]* passed'` matches the "2 passed". Three such nodes
  were repaired in #3; the remaining 222 in #15, which also widened
  `ci/verify-accept-oracle.sh` from the 25-node clean subset to all 250 — the scoping that let
  this survive is that the guard never looked at the population it certifies. The reproduction is
  kept as a fixture (`ci/fixtures/partial-pass/`, check E), so a partial pass scoring GREEN is now
  a build failure rather than a discovery.

  This was not a memorisation effect and it did not cancel in a paired delta. It is a *mislabelled
  outcome*: a partial pass counted as a full one moves a node from discordant to concordant, the
  same way a memorised node does, while also corrupting the absolute rate for reasons that have
  nothing to do with what any model learned.

  **A sound oracle is necessary, not sufficient.** Converting these accepts changed no node's
  verdict on its own seed — all 250 were measured under both forms and none flipped. The
  conversion's value is on *solved* states, which is where a substring filter mislabels. Two
  further defects, below, decide whether a node is usable at all.

- **GREEN-reachability is unverified across all 225 (#14).** `ci/verify-red-invariant.sh` proves
  each accept is RED on the seed; `prove-solvable.sh` proves a reference solution reaches GREEN and
  covers only the 25 hand-authored nodes. From outside, a node that is RED because its toolchain
  never reached the tests is indistinguishable from one that is RED because the stub is
  unimplemented.

  The 26 cpp nodes were that case, and it is now confirmed rather than suspected. Their
  `CMakeLists.txt` derived the exercise name — and therefore its **source filenames** — from the
  work directory (`get_filename_component(exercise ${CMAKE_CURRENT_SOURCE_DIR} NAME)`). A harness
  materialises each seed into a scratch directory, so cmake looked for `<scratchdir>_test.cpp`
  and failed at *configure*, which is what the ~0.17s CI timings were. Every cpp node was RED for
  an environmental reason and unsolvable with any submission. Compounding it, no cpp node
  registers a `ctest` test at all, so the `ctest … | grep '0 tests failed'` leg of the shipped
  accept could never match: the accept was not merely unsound, it was **unsatisfiable**. Both are
  repaired in #15 — the name is pinned to the node's own exercise and the accept is
  `cmake -S . -B build && cmake --build build`, the `add_custom_target(… ALL … COMMAND ${exercise})`
  already running the test binary as part of the build. Verified end to end: stub → exit 2 (RED),
  reference solution → exit 0 (GREEN).

**The splits coincide, and that is the point.** Contaminated: 225. Unsound oracle: 222 of those
same 225, and **0 of the 25** hand-authored. Unverified solvability: the same 225. These are not
three overlapping populations, they are one population with three defects. A reader who accepts
the paired-comparison argument above and uses the Exercism stratum anyway inherits all three, not
the one this section is named after.

### How many nodes actually work: the validity census

**`N_instrument = 232` of 250.** Measured per node, one row each, in
[`docs/census/`](docs/census/README.md) — a node counts only if its accept scores on the runner's
exit status, it is RED on the seed *because the stub is unimplemented* rather than because the
toolchain never ran, and a reference solution actually reaches GREEN.

| | nodes |
|---|---|
| INSTRUMENT | **232** |
| BROKEN | 17 |
| UNUSABLE_BY_DESIGN (`javascript-ledger`, #16) | 1 |

Quote it at two bars, because they answer different questions:

| bar | N |
|---|---|
| all three columns hold | **232** |
| …and the node grades on its **full** suite (see #21 below) | **96** |
| …and the node is also uncontaminated | **25** |

**Do not mix the bars across a power calculation.** The discordant rate `d = 0.375`
(dotclaude#34) was measured on the clean 25, which are 25/25 full-suite. Applying it to N=232 —
59% of which grade on a single test — takes `N` from one population and `d` from another, and the
error has a direction: an easier pass bar produces concordance, concordance suppresses the
*measured* `d`, and a low `d` is exactly what would justify an expensive authoring program. Fix
#23 (toolchain pinning, which decides whether N is 232 or 185) and #21 (the pass bar) before
estimating `d`. See [`docs/census/README.md`](docs/census/README.md).

GREEN-reachability across the 225 needed no authoring: each maps 1:1 onto an upstream Exercism
exercise shipping a canonical example, and slug coverage was 225 of 225.

### A fourth defect: most nodes grade on one test (#21)

**149 of 250 nodes ship most of their acceptance suite disabled**, and 145 of those grade on
**exactly one** test. The corpus inherited Exercism's learner convention — `#[ignore]` (rust),
`@Disabled` (java), `xtest` (javascript), `#if defined(EXERCISM_RUN_ALL_TESTS)` (cpp) — and never
re-enabled anything. go and python are unaffected; the hand-authored katas are unaffected.

| language | tests shipped | tests enabled |
|---|---|---|
| cpp | 459 | 31 |
| java | 790 | 48 |
| javascript | 885 | 51 |
| rust | 686 | 66 |

`rust-acronym` runs 1 of 10 tests, and `fn abbreviate(_: &str) -> String { "PNG".to_string() }`
scores it GREEN. **A sound oracle does not repair this** — `cargo test` exits 0 with 620 ignored
tests. It is a third mechanism producing concordance, alongside contamination and the permanently
GREEN/RED nodes, and it is the reason the census reports a full-suite bar separately.

### Toolchain versions are not pinned, and it matters

`accept` invokes ambient tools (`gradle`, `cmake`, `go`, `npm`). Nothing pins a version, so a
node's verdict can depend on the host. This is not theoretical: on **Gradle 9.x** every one of the
47 gradle-java nodes fails with *"Failed to load JUnit Platform"* — RED for an environmental
reason and unsolvable, exactly cpp's class. The seeds carry a wrapper pinned to 8.7 but omit
`gradle-wrapper.jar`, so `./gradlew` cannot run either. Under a real 8.7 the stratum is healthy —
and two nodes CI has always reported RED are in fact **GREEN on the untouched seed**
(`java-ledger`, `java-tree-building`), a #11-class defect invisible until the tests ran.

Report the toolchain versions alongside any result taken from this corpus.

The 25 hand-authored nodes are clean on every count — which is why they are the held-out stratum
in more than the leakage sense, and why their small size (below) is this corpus's binding
constraint rather than a footnote to it.

### The held-out stratum is small

25 nodes is enough to be honest with and not enough to be conclusive with. A paired experiment
over it detects only a very large effect; anything moderate escapes. Growing it is the way to a
conclusive result — not adding more Exercism nodes, which adds contaminated mass without adding
proportionate power.

### Difficulty bands were removed

A `band` field existed on 250 nodes but was populated on 11 (220 empty strings, 19 absent). A
stratification variable that is 96% empty invites accidental misuse — a "hard-band" result read
from 7 nodes — so the field is gone rather than half-kept. Reintroduce it only fully populated.

