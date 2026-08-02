# corpus

[![Nodes](https://img.shields.io/badge/nodes-250-blue.svg)](MANIFEST.tsv)
[![Languages](https://img.shields.io/badge/languages-6-blue.svg)](MANIFEST.tsv)
[![License](https://img.shields.io/badge/license-MIT%20(Exercism--derived)-green.svg)](LICENSE)

**The RED-baseline measurement corpus — 250 failing seed projects across 6 languages, the fixed
substrate an A/B eval harness scores a change against.**

Each node is a failing exercise (`{meta, seed, RED}`): a stub that doesn't yet pass its acceptance
test. A harness change is scored by how reliably it turns RED into GREEN over the battery. Keeping the
corpus a separate, versioned component — not baked into the harness that measures it — is what makes a
measurement reproducible and the eval-harness/corpus separation clean.

> Part of the Barnett Studios agentic-harness toolkit → cxpak · commitward · abproof · cascadr ·
> cordon · **corpus** · …

## What's here

- [`red-baseline/`](red-baseline/) — the **250 node projects** (`{meta, seed, RED}`), ~23 MB across 6
  languages. This is the corpus data itself.
- [`LICENSE`](LICENSE) · [`ATTRIBUTION.md`](ATTRIBUTION.md) — full provenance (Exercism MIT + bundled
  Catch2 BSL-1.0 + Gradle-wrapper Apache-2.0).
- [`CONTRACT.md`](CONTRACT.md) — the `{meta, seed, RED}` per-node contract, the RED invariant, and the
  fail-open toolchain gate.
- [`MANIFEST.tsv`](MANIFEST.tsv) — machine-readable index of all 250 nodes (id, language, accept tool,
  seed license, third-party bundle).
- [`verify-attribution.sh`](verify-attribution.sh) — regenerate or (`--check`) drift-check the manifest
  against the node data. Defaults to the bundled `red-baseline/`; override with `$CORPUS_ROOT`.

## Use

```sh
# verify attribution still matches the shipped data
./verify-attribution.sh --check

# point your A/B harness (e.g. abproof) at the corpus
ABPROOF_CORPUS=/path/to/red-baseline abproof run experiment.yaml --dry-run
```

## Adding a node

Drop a `red-baseline/<id>/` with `meta.yaml` + `seed/` (must ship **failing** — the RED invariant),
then `./verify-attribution.sh` to refresh the manifest. Additive; never a breaking change.

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

- **The accept oracle is unsound (#15) — 222 of the 225.** They score by `grep` on runner output
  instead of on the runner's exit status, the practice this contract forbids two sections up. The
  demonstration case was `python-react`: it ships **2 passed, 12 failed** and scored GREEN, because
  `grep -qE '[1-9][0-9]* passed'` matches the "2 passed". Three such nodes are repaired in #3;
  222 remain.

  This is not a memorisation effect and it does not cancel in a paired delta. It is a *mislabelled
  outcome*: a partial pass counted as a full one moves a node from discordant to concordant, the
  same way a memorised node does, while also corrupting the absolute rate for reasons that have
  nothing to do with what any model learned. Until #15 is repaired the power these nodes appear to
  offer is not reachable, so growing a battery with more of them buys less than the count suggests.

- **GREEN-reachability is unverified across all 225 (#14).** `ci/verify-red-invariant.sh` proves
  each accept is RED on the seed; `prove-solvable.sh` proves a reference solution reaches GREEN and
  covers only the 25 hand-authored nodes. From outside, a node that is RED because its toolchain
  never reached the tests is indistinguishable from one that is RED because the stub is
  unimplemented — and in CI the 26 cpp nodes each report RED in ~0.17s, below the floor for a real
  cmake configure and build.

**The splits coincide, and that is the point.** Contaminated: 225. Unsound oracle: 222 of those
same 225, and **0 of the 25** hand-authored. Unverified solvability: the same 225. These are not
three overlapping populations, they are one population with three defects. A reader who accepts
the paired-comparison argument above and uses the Exercism stratum anyway inherits all three, not
the one this section is named after.

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

