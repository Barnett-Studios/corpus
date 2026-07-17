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
| `files` | editable files (relative to the node work dir) the model may change |
| `accept` | shell command run in the work dir; **exit 0 ⇔ the task is solved** (the RED test's oracle) |
| `forbid` | constraints (e.g. `new_deps`) the change must not violate |
| `requires` | toolchain executables that must be on PATH; **absent ⇒ node SKIPPED, never failed** |
| `change` | the task description shown to the model |

## The RED invariant

Every node ships **failing** (`accept` returns non-zero against the seed): the stub is unimplemented.
That is the point — a harness change is scored by how often it turns RED into GREEN. A node whose seed
already passes is a corpus bug, not a task.

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
