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
