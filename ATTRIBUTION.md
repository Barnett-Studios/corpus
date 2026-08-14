# Attribution — red-baseline corpus

This corpus is **derived from [Exercism](https://exercism.org)** practice exercises. Exercism's
exercises and their test suites are open-source; each seed project reproduced here that carries an
Exercism `LICENSE` file is under the **MIT License, © Exercism and contributors**. This component
redistributes them under those terms, with the attribution below, and adds its own RED-baseline
adaptation layer (the `meta.yaml` task descriptors and the RED framing) © Barnett Studios under MIT.

Provenance and per-license breakdown are machine-verifiable: [`MANIFEST.tsv`](MANIFEST.tsv) lists
every one of the 250 nodes with its language, `requires` (the ambient toolchain the node declares
it still needs — empty where it declares none; for the 47 gradle-wrapper nodes that is because the
accept invokes `./gradlew`, which needs no ambient `gradle`), seed license, and any bundled third-party
component; [`verify-attribution.sh --check`](verify-attribution.sh) fails if the manifest
ever drifts from the actual data.

## Upstream: Exercism (MIT)

- **What** — the exercise *specifications*, canonical *test suites*, and starter/stub files, across
  the C++, Go, Java, JavaScript, Python, and Rust tracks.
- **License** — MIT, `Copyright (c) Exercism and contributors`. 49 nodes ship the upstream `LICENSE`
  verbatim under `seed/LICENSE`; the remaining nodes reproduce exercise material from the same
  MIT-licensed tracks and are covered by the same terms (the upstream tracks are MIT at the
  repository level).
- **Source** — https://github.com/exercism (per-language track repositories).
- **Requirement honored** — the MIT permission notice is retained; this file plus the per-node
  `seed/LICENSE` files carry the copyright + permission notice as MIT requires.

## Bundled third-party components (inside seed projects)

| Component | Where | License | Nodes |
|---|---|---|---|
| **Catch2** (`catch.hpp`, single-header test framework) | `<node>/seed/test/catch.hpp` | Boost Software License 1.0 (BSL-1.0) | 26 (all `cpp-*`) |
| **Gradle wrapper** (`gradlew`, `gradlew.bat`, `gradle/wrapper/*`) | `<node>/seed/` | Apache License 2.0 | 47 (`java-*` using Gradle) |

- **Catch2 / BSL-1.0** — © Catch2 Authors. BSL-1.0 permits redistribution including the copy of the
  license in the file header; `catch.hpp` retains its own header notice. Source:
  https://github.com/catchorg/Catch2.
- **Gradle wrapper / Apache-2.0** — © Gradle Inc. The wrapper is the standard redistributable Gradle
  bootstrap. Source: https://github.com/gradle/gradle.

  Until #23 this row was **inaccurate**: it claimed `gradle/wrapper/*` was bundled, but
  `gradle-wrapper.jar` — the only part of the wrapper that is actually a Gradle Inc. artifact, and
  the only part that carries the Apache-2.0 obligation — had never been committed. The attribution
  described a redistribution that was not happening. `gradlew` and `gradlew.bat` are shell/batch
  bootstraps; without the jar they cannot run.

  The jar is now present in all 47 nodes, pinned to the version the seeds' own
  `gradle-wrapper.properties` names:

  | | |
  |---|---|
  | version | 8.7 |
  | sha256 | `cb0da6751c2b753a16ac168bb354870ebb1e162e9083f116729cec9c781156b8` |
  | verified against | `https://services.gradle.org/distributions/gradle-8.7-wrapper.jar.sha256` |

  `ci/verify-accept-oracle.sh` check F asserts that digest on every run. The jar is a binary each
  java node executes, so an unnoticed swap would be arbitrary code execution across 47 nodes;
  attribution and integrity are the same problem here, and the check covers both.

  **The distribution the wrapper fetches is pinned too (#27).** Nothing in this repo redistributes
  it — the 43 KB jar downloads it at first run — but the same execution surface applies one link
  down the chain, and until #27 those ~130 MB of bytes were unverified. `validateDistributionUrl`
  validates the URL, not the payload.

  | | |
  |---|---|
  | distribution | `gradle-8.7-bin.zip` |
  | sha256 | `544c35d6bd849ae8a5ed0bcea39ba677dc40f49df7d1835561582da2009b961d` |
  | published at | `https://services.gradle.org/distributions/gradle-8.7-bin.zip.sha256` |
  | also verified against | the 128 MB payload actually served, hashed locally — not transcribed on trust |

  All 47 seeds now carry it as `distributionSha256Sum`, and check F fails a node that omits it, sets
  it wrong, or names a gradle version whose digest the script does not record. The residual is
  vendor-host trust: digest and payload come from the same origin, and nothing here can close that.

Language scaffolds without a separate license obligation — `go.mod` (45), `Cargo.toml` (37 — one more
than the 36 `rust-*` nodes because `rust-macros` ships a workspace + proc-macro pair),
`CMakeLists.txt`, JavaScript `package.json` — are trivial build descriptors generated per exercise
and carry no third-party copyright beyond the Exercism MIT grant.

## Scope note (before any public release)

This attribution is complete for the components actually present (verified by `MANIFEST.tsv`).
Public redistribution of the corpus is gated the same way every component is: private until the
§3 gates are green. Because this bundles multiple upstream licenses (MIT + BSL-1.0 + Apache-2.0),
a public flip is a good candidate for a legal-review HITL checkpoint — the licenses are all
permissive and redistribution-compatible, but the sign-off is a human's to give.
