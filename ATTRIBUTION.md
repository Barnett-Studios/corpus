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

Drift is not the whole claim, so the same script asks a second question with an enumeration
that does **not** come from the two filename rules the manifest is built on: every shipped
file is swept for a licence header or a bundled-artifact shape, and anything not explicitly
classified is a **hard failure**. Detection is an allowlist with a refusal rather than a
denylist, so an unrecognised bundled dependency stops the gate instead of being recorded as
`-`. Today that sweep classifies 225 `LICENSE`, 47 `gradlew`/`gradlew.bat`, 47
`gradle-wrapper.jar` and 26 `catch.hpp`, and finds nothing else across 1696 shipped files.

Its honest limit is narrower than "no licence header", and the axis is the **form of the
copyright line**, not the licence family. The content signal is three literal forms —
`copyright (c)`, `SPDX-License-Identifier`, `Licensed under the Apache|MIT|Boost` — matched
case-insensitively, so `copyright (c)` also catches `Copyright (C)`. That one character does
most of the work: the canonical GPL, BSD-3-Clause, ISC and MIT headers all open with exactly
that line, and all four are refused.

Measured against 14 header shapes, 6 refuse and 8 pass through. What escapes is a copyright
line in some other form, or none at all: `Copyright © 2020 Acme`; a bare `(C) 2020 Acme Corp`
with no `copyright` keyword; `Copyright 2020 Acme Inc. All rights reserved.`; an MPL-2.0
notice alone; a "this program is free software" preamble alone; the GPL and BSD bodies with
their copyright lines stripped; and a file with no header at all.

So a vendored *source* file with an ordinary extension escapes the sweep when it carries none
of those three forms (#2). Nothing about the current corpus changes: the signal is exact on
all 1696 shipped files today, and every binary in `red-baseline/` is caught by the shape
signal — 47 tracked files carry a NUL byte in their first 8KB and every one is a
`gradle-wrapper.jar`, which `\.jar$` matches. That is a measurement of this corpus, not a
general property: the shape signal is an extension and vendor-path list, so a headerless `.o`
or `.png` would pass through it.

## Upstream: Exercism (MIT)

- **What** — the exercise *specifications*, canonical *test suites*, and starter/stub files, across
  the C++, Go, Java, JavaScript, Python, and Rust tracks.
- **License** — MIT, `Copyright (c) 2021 Exercism`. **All 225 Exercism-derived nodes ship the
  upstream `LICENSE` verbatim under `seed/LICENSE`**, byte-identical
  (`sha256 e52f804e…44df`). Until #1 only 49 did, and this file argued the other 176 were
  "covered by the same terms … at the repository level". That argument does not survive the way
  a node is actually used: `seed/` is materialized into a work tree on its own, so a
  repository-level notice never reaches the material it is supposed to travel with. The 176 now
  carry it.
- **Source** — https://github.com/exercism (per-language track repositories).
- **Requirement honored** — the MIT copyright and permission notice travels with every node it
  applies to, enforced rather than asserted: `verify-attribution.sh` fails if a node declaring
  `provenance: exercism` is missing the notice, ships altered bytes, or ships a file that hashes
  correctly but is not a licence, and if a node declaring `hand-authored` ships Exercism's notice.

### What the manifest records, and what it does not

`seed_license` is derived from the node's declared `provenance`, not from whether a `LICENSE`
file happens to be present — 225 `MIT(Exercism)`, 25 `none`. The presence of the notice is an
invariant the sweep enforces, not a value the manifest quietly reports; those are different
claims and conflating them is what let 176 nodes read `none` on a public repository (#1).

**Not covered here.** Whether this corpus may be publicly redistributed at all is a legal
question, not a mechanical one. This file records what is shipped and under what asserted terms;
it is not a legal review and no session can stand in for one. That review, and the HITL
checkpoint that should gate public distribution, remain open on #1.

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
