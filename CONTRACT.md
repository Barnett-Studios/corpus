# corpus — Contract

The **corpus**: a collection of RED-baseline tasks that an A/B eval harness (such as abproof)
scores a harness change against. Each task is a **failing seed project** plus the metadata to run and
score it — the fixed measurement substrate, kept separate from the harness that measures it.

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
