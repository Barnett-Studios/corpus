# Attribution — red-baseline corpus

This corpus is **derived from [Exercism](https://exercism.org)** practice exercises. Exercism's
exercises and their test suites are open-source; each seed project reproduced here that carries an
Exercism `LICENSE` file is under the **MIT License, © Exercism and contributors**. This component
redistributes them under those terms, with the attribution below, and adds its own RED-baseline
adaptation layer (the `meta.yaml` task descriptors and the RED framing) © Barnett Studios under MIT.

Provenance and per-license breakdown are machine-verifiable: [`MANIFEST.tsv`](MANIFEST.tsv) lists
every one of the 250 nodes with its language, accept toolchain, seed license, and any bundled
third-party component; [`verify-attribution.sh --check`](verify-attribution.sh) fails if the manifest
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
