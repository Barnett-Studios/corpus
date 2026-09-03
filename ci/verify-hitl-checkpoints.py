#!/usr/bin/env python3
"""The redistribution tripwire must be declared, and it must actually cover the surface.

corpus#1 asked for a HITL checkpoint so a future change to what this repo redistributes stops for
a human. A registry file alone does not do that: a pattern that matches nothing, a regex that does
not compile, or a node whose notice lives at a depth the pattern misses all leave a gate that
loads cleanly and fires on nothing.

TWO DENOMINATORS, DELIBERATELY, because they catch opposite failures.

  * MUST_FIRE / MUST_NOT_FIRE below are enumerated from the SPECIFICATION — corpus#1's founder
    decision and this repo's own redistribution surface — and never from the registry. A
    completeness check that reads its expectations out of the thing it checks can only confirm
    that a file agrees with itself.

  * `live_notice_paths()` enumerates from the TREE instead, and asserts every notice actually
    shipped is matched. That one has to share its enumeration with reality: it is a drift check,
    and a node whose LICENSE sits somewhere the pattern does not reach is what it exists to find.

WHAT THIS DOES NOT VERIFY: that Rust's `regex` crate agrees with Python's `re`. The gate is the
authority on matching. These patterns are anchored literals and character classes where the two
engines do not differ, and the registry is deliberately path-mode so nothing exotic appears — but
a pattern using a construct the engines read differently would pass here and behave otherwise in
the gate.

Usage: verify-hitl-checkpoints.py [--self-test]
"""
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
REGISTRY = ROOT / ".dotclaude" / "checkpoints.yaml"

# Exactly one of these may be declared per checkpoint (detect_hitl::compile -> AmbiguousMode).
MODES = ("paths", "content", "semantic")

# From corpus#1's founder decision ("at minimum red-baseline/**/seed/LICENSE, MANIFEST.tsv,
# ATTRIBUTION.md and the root LICENSE") plus the bundled-third-party notices LICENSE carves out.
# Written here, not derived.
MUST_FIRE = [
    "MANIFEST.tsv",
    "ATTRIBUTION.md",
    "LICENSE",
    "NOTICE",
    "red-baseline/py-add/seed/LICENSE",
    "red-baseline/cpp-allergies/seed/NOTICE",
]

# The names this registry is allowed to declare — a hand-written specification, exactly like
# MUST_FIRE, and for the same reason: it states what the file MUST say rather than reporting
# what it happens to say.
#
# `detect_hitl::merge` keys the union by name, so a repo entry sharing a baseline entry's name
# REPLACES it rather than adding to it. The baseline `license-or-ip-grant` carries nine patterns
# and this one carries four, so a rename to that name would silently drop `COPYING`,
# `THIRD-PARTY-LICENSES.md`, `about.toml`, `Cargo.toml`, `^attribution/`, `^agents/.*\.md$` and
# `^skills/.*/SKILL\.md$` — 37 tracked files in this repo, every `red-baseline/rust-*/seed/
# Cargo.toml` among them — while both CI steps still printed `checkpoints ok`. Measured, on the
# tree, at the head this check was added to.
#
# A rename is a reasonable thing for a contributor to want; the point is that it must be a
# deliberate two-line edit here rather than a one-line tidy-up in the YAML.
ALLOWED_NAMES = {"corpus-redistribution"}

# Names owned by the installed baseline registry. Colliding with one of these is the specific
# failure above and gets its own message, because "unexpected name" would send the next reader
# looking for a typo rather than for a silently narrowed gate.
BASELINE_NAMES = {
    "license-or-ip-grant",
    "agent-instructions-self-mod",
    "destructive-ops",
}

# The other half of a coverage claim. A registry matching everything would satisfy MUST_FIRE
# completely and be worthless — a gate that fires on every commit is a gate nobody reads.
MUST_NOT_FIRE = [
    "README.md",
    "CONTRACT.md",
    "CONTRIBUTING.md",
    "VERSION",
    "red-baseline/py-add/seed/calc.py",
    "red-baseline/py-add/meta.yaml",
    "ci/verify-hitl-checkpoints.py",
    "docs/anything.md",
    ".github/workflows/ci.yml",
]


class Failure(Exception):
    """A checked property that does not hold."""


def load(text=None):
    raw = text if text is not None else REGISTRY.read_text()
    try:
        doc = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        raise Failure(f"{REGISTRY.name} is not valid YAML: {e}") from e
    if not isinstance(doc, dict) or "checkpoints" not in doc:
        raise Failure(f"{REGISTRY.name} has no `checkpoints` list — the gate loads nothing")
    if str(doc.get("version")) != "1":
        raise Failure(f"unsupported registry version {doc.get('version')!r}, expected \"1\"")
    cps = doc["checkpoints"]
    if not isinstance(cps, list) or not cps:
        raise Failure("`checkpoints` is empty — a registry that declares nothing cannot fire")
    return cps


def check_shape(cps):
    for cp in cps:
        name = cp.get("name")
        if not name:
            raise Failure("a checkpoint has no `name`; it cannot be acked, so it cannot be used")
        if name in BASELINE_NAMES:
            raise Failure(
                f"{name}: this name belongs to the installed baseline registry, and "
                f"detect_hitl::merge keys the union by name — declaring it here REPLACES the "
                f"baseline entry instead of adding to it, narrowing the gate to this file's "
                f"patterns alone. Use a name of this repo's own: {sorted(ALLOWED_NAMES)}."
            )
        if name not in ALLOWED_NAMES:
            raise Failure(
                f"{name}: not in ALLOWED_NAMES {sorted(ALLOWED_NAMES)}. The name is load-bearing "
                f"(see the comment there), so renaming a checkpoint is a deliberate edit in both "
                f"places, not a one-line tidy-up in the YAML."
            )
        for field in ("summary", "standards_doc"):
            if not cp.get(field):
                raise Failure(f"{name}: missing `{field}` — a fired gate must say what governs it")
        declared = [m for m in MODES if cp.get(m)]
        if len(declared) != 1:
            raise Failure(
                f"{name}: declares {declared or 'no'} mode(s); exactly one of {MODES} is "
                f"required (a mixed declaration is rejected by the gate itself)"
            )
        if declared[0] != "paths":
            raise Failure(
                f"{name}: mode is {declared[0]!r}. This registry is path-mode only — CLAUDE.md "
                f"treats content-mode as best-effort against an honest operator and not an "
                f"adversarial control, and a licence tripwire must not imply otherwise."
            )
        if not (ROOT / cp["standards_doc"]).is_file():
            raise Failure(f"{name}: standards_doc {cp['standards_doc']!r} does not exist")
        for pat in cp["paths"]:
            try:
                re.compile(pat)
            except re.error as e:
                raise Failure(f"{name}: pattern {pat!r} does not compile: {e}") from e


def matchers(cps):
    return [(cp["name"], re.compile(p)) for cp in cps for p in cp["paths"]]


def fires(ms, path):
    return sorted({name for name, rx in ms if rx.search(path)})


def check_coverage(cps):
    ms = matchers(cps)
    missed = [p for p in MUST_FIRE if not fires(ms, p)]
    if missed:
        raise Failure(
            "these paths carry redistribution exposure and no checkpoint matches them:\n  "
            + "\n  ".join(missed)
        )
    over = [(p, fires(ms, p)) for p in MUST_NOT_FIRE if fires(ms, p)]
    if over:
        raise Failure(
            "these paths must NOT stop a commit; a gate that fires on ordinary work is a gate "
            "that gets acked without reading:\n  "
            + "\n  ".join(f"{p} -> {n}" for p, n in over)
        )


def live_notice_paths():
    """Every per-node notice actually shipped, enumerated from the tree."""
    base = ROOT / "red-baseline"
    if not base.is_dir():
        return []
    return sorted(
        str(p.relative_to(ROOT))
        for p in base.glob("*/seed/*")
        if p.name in ("LICENSE", "NOTICE") or p.name.startswith("LICENSE.")
    )


def check_live_surface(cps):
    ms = matchers(cps)
    live = live_notice_paths()
    if not live:
        raise Failure(
            "no per-node notice found under red-baseline/*/seed/ — this check cannot answer, and "
            "reporting success would mean 'the corpus ships no notices', which the manifest "
            "denies. Run from the repo root with the corpus present."
        )
    missed = [p for p in live if not fires(ms, p)]
    if missed:
        raise Failure(
            f"{len(missed)} of {len(live)} shipped notices are not covered by any pattern:\n  "
            + "\n  ".join(missed[:10])
        )
    return len(live)


def run(text=None):
    cps = load(text)
    check_shape(cps)
    check_coverage(cps)
    return cps, check_live_surface(cps)


def self_test():
    """The guard must bite. Each mutation is a way the registry could stop protecting anything
    while still loading, and each must be reported rather than passed over."""
    good = REGISTRY.read_text()
    run(good)  # precondition: the real registry passes, or nothing below means anything

    cases = [
        ("a path pattern is dropped",
         lambda t: t.replace('      - "(^|/)MANIFEST\\\\.tsv$"\n', "")),
        ("the notice pattern is dropped",
         lambda t: t.replace('      - "(^|/)LICENSE([-.].*)?$"\n', "")),
        ("a pattern is broadened to everything", lambda t: t.replace('"(^|/)NOTICE$"', '"."')),
        ("the mode becomes content", lambda t: t.replace("    paths:", "    content:")),
        ("a second mode is added", lambda t: t.replace("    paths:", "    semantic: x\n    paths:")),
        ("standards_doc points nowhere",
         lambda t: t.replace('standards_doc: "ATTRIBUTION.md"', 'standards_doc: "NOPE.md"')),
        ("a pattern stops compiling", lambda t: t.replace('"(^|/)NOTICE$"', '"(^|/)NOTICE($"')),
        ("the checkpoint list is emptied",
         lambda t: t[: t.index("checkpoints:")] + "checkpoints: []\n"),
        ("the version is unrecognised", lambda t: t.replace('version: "1"', 'version: "99"')),
        # The mutation that passed both CI steps before this head. `license-or-ip-grant` is the
        # baseline entry whose nine patterns cover 263 files here; replacing it with this one's
        # four drops 37 of them, with `checkpoints ok` on stdout either way.
        ("the name collides with a baseline entry",
         lambda t: t.replace("corpus-redistribution", "license-or-ip-grant")),
        # And the general form: any rename, not only a colliding one. Without this, a check that
        # only knew BASELINE_NAMES would wave through `corpus-redistributionn`.
        ("the name is changed to one nobody owns",
         lambda t: t.replace("corpus-redistribution", "corpus-redistribution-v2")),
    ]

    survived = []
    for label, mutate in cases:
        mutated = mutate(good)
        if mutated == good:
            survived.append(f"{label} (MUTATION DID NOT APPLY — the anchor moved)")
            continue
        try:
            run(mutated)
        except Failure:
            continue
        survived.append(label)

    if survived:
        print("SELF-TEST FAILED — these mutations were not caught:", file=sys.stderr)
        for s in survived:
            print(f"  {s}", file=sys.stderr)
        return 1
    print(f"self-test: {len(cases)} mutations, all caught")
    return 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()
    try:
        cps, n = run()
    except Failure as e:
        print(f"verify-hitl-checkpoints: {e}", file=sys.stderr)
        return 1
    names = ", ".join(cp["name"] for cp in cps)
    print(f"checkpoints ok: {names}; {n} shipped notices covered, "
          f"{len(MUST_NOT_FIRE)} ordinary paths left alone")
    return 0


if __name__ == "__main__":
    sys.exit(main())
