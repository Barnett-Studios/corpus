# corpus

**The RED-baseline measurement corpus — 250 failing seed projects across 6 languages, the fixed
substrate the Proving Ground A/Bs a harness change against.**

Each node is a failing exercise (`{meta, seed, RED}`): a stub that doesn't yet pass its acceptance
test. A harness change is scored by how reliably it turns RED into GREEN over the battery. Keeping the
corpus a separate, versioned component — not baked into the harness that measures it — is what makes a
measurement reproducible and the Proving Ground/Corpus separation clean.

> Part of the Barnett Studios agentic-harness toolkit → cxpak · commitward · abproof · cascadr ·
> cordon · **corpus** · …

## What's here (and what isn't, yet)

This directory is the corpus component's **license clearance + contract**:

- [`LICENSE`](LICENSE) · [`ATTRIBUTION.md`](ATTRIBUTION.md) — full provenance (Exercism MIT + bundled
  Catch2 BSL-1.0 + Gradle-wrapper Apache-2.0).
- [`CONTRACT.md`](CONTRACT.md) — the `{meta, seed, RED}` per-node contract, the RED invariant, and the
  fail-open toolchain gate.
- [`MANIFEST.tsv`](MANIFEST.tsv) — machine-readable index of all 250 nodes (id, language, accept tool,
  seed license, third-party bundle).
- [`verify-attribution.sh`](verify-attribution.sh) — regenerate or (`--check`) drift-check the manifest
  against the node data.

The **23 MB of node data** still lives at `measurement/corpus/red-baseline/` in the source monorepo.
It is deliberately **not copied here** — duplicating 23 MB into git history would be permanent bloat.
At repo-creation time the data is `git mv`'d into this component's repo (a move, not a copy); see
`docs/module-extraction/corpus-consume-back.md`. Until then, the scripts resolve the data via
`$CORPUS_ROOT` (default: `../../measurement/corpus/red-baseline`).

## Use

```sh
# verify attribution still matches the shipped data
./verify-attribution.sh --check

# point the Proving Ground at the corpus
ABPROOF_CORPUS=/path/to/red-baseline abproof run experiment.yaml --dry-run
```

## Adding a node

Drop a `red-baseline/<id>/` with `meta.yaml` + `seed/` (must ship **failing** — the RED invariant),
then `./verify-attribution.sh` to refresh the manifest. Additive; never a breaking change.
