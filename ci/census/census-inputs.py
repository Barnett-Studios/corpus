#!/usr/bin/env python3
"""corpus#26 — the drift gate for `docs/census/validity-census.tsv`.

## Why this shape, and not the one the ticket proposed

corpus#26 asks for "a `census-drift` job that re-runs stage 2 and diffs against the
committed TSV", on the grounds that classification is offline and therefore cheap. The
offline part is true and the cheap part is not: `classify.py` reads
`.census-work/census-runs/all.tsv` and the per-node `*.exit.log` files, and
`.census-work/` is **gitignored**. Nothing in the repo can reproduce stage 2 without first
re-running stage 1 — 250 accepts across six toolchains — so the proposed job would either
not run or run for an hour per PR.

What the ticket actually cares about is stated one line above the proposal: *"The moment
any node's meta.yaml, accept, or test file changes, the TSV is stale and nothing says
so."* That is detectable without any of the census machinery, because it is a statement
about the **inputs**, not about the classification.

So: record what the census was computed over, and fail when the tree no longer matches.

## What is recorded

One row per node, `node_id<TAB>digest`, where the digest covers **every tracked file under
that node's directory**: git enumerates the paths, and the content is hashed from the
working tree.

Both halves deliberately. Enumerating from git keeps build output and `.census-work/`
spill out of the digest; hashing from disk means the gate sees what the accept would
actually run. Taking git's own blob hashes from `ls-files -s` would have been shorter and
wrong — those come from the index, so an edited-but-unstaged `meta.yaml` hashes to its
committed content and the gate reports the census current while the tree it describes has
already moved.

The whole directory, not `meta.yaml` plus a guess at which files are tests: choosing the
subset would need per-language knowledge of test layout, and getting it wrong produces a
gate that is silent for exactly the languages it guessed wrong about. The cost is that an
unrelated edit inside a node re-fires this gate, and the remedy — re-run the census, or
re-record if the verdicts genuinely did not move — is the honest response either way.

## What it cannot do

It does not verify the verdicts. It says the inputs are unchanged since someone recorded
them, so the committed census still describes this tree. If the census was wrong when it
was recorded, this gate keeps it wrong and says nothing.

Usage:
    census-inputs.py            # check; exit 2 on drift
    census-inputs.py --write    # re-record after re-running the census
"""

import hashlib
import os
import subprocess
import sys

import spec

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(REPO, "docs", "census", "census-inputs.tsv")
CENSUS = os.path.join(REPO, "docs", "census", "validity-census.tsv")
CORPUS_REL = os.path.relpath(spec.CORPUS, REPO)


def tracked_digests():
    """`{node: sha256 over `<path>\\n<sha256 of its bytes>` for every tracked file}`."""
    try:
        out = subprocess.run(
            ["git", "-C", REPO, "ls-files", "-z", "--", CORPUS_REL],
            capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        # Not `return {}`. An unavailable git would otherwise digest nothing, match a
        # manifest of nothing, and report the census current — a gate green over a
        # population it never read.
        sys.exit("census-inputs: cannot list tracked files under %s (%s). Refusing to "
                 "report the census current without having read the tree." % (CORPUS_REL, exc))

    per_node = {}
    for path in out.split("\0"):
        # -z, because a corpus of upstream exercise seeds is exactly the place a filename
        # with a newline in it turns a line-oriented parse into a silently short listing.
        if not path:
            continue
        rel = os.path.relpath(path, CORPUS_REL)
        node = rel.split(os.sep, 1)[0]
        full = os.path.join(REPO, path)
        try:
            with open(full, "rb") as fh:
                blob = hashlib.sha256(fh.read()).hexdigest()
        except OSError as exc:
            # A tracked file that is not on disk is a deleted-but-unstaged node file. The
            # accept would fail on it; the gate must not pass over it.
            sys.exit("census-inputs: %s is tracked but unreadable (%s). The working tree "
                     "does not contain the corpus the census describes." % (path, exc))
        per_node.setdefault(node, []).append("%s\n%s" % (rel, blob))

    return {node: hashlib.sha256("\n".join(sorted(lines)).encode("utf-8")).hexdigest()
            for node, lines in per_node.items()}


def read_manifest():
    if not os.path.exists(MANIFEST):
        sys.exit("census-inputs: %s does not exist. The committed census records no "
                 "inputs, so nothing can say whether it is stale. Run with --write after "
                 "re-running the census." % MANIFEST)
    rows = {}
    with open(MANIFEST, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 2:
                sys.exit("census-inputs: %s:%d is not `node<TAB>digest`: %r"
                         % (MANIFEST, lineno, line[:120]))
            rows[parts[0]] = parts[1]
    return rows


def census_membership():
    """The node ids the committed census actually has a verdict for."""
    if not os.path.exists(CENSUS):
        sys.exit("census-inputs: %s does not exist." % CENSUS)
    ids = set()
    with open(CENSUS, encoding="utf-8") as fh:
        header = next(fh, "").rstrip("\n").split("\t")
        if not header or header[0] != "node_id":
            sys.exit("census-inputs: %s does not start with a `node_id` column; its shape "
                     "has changed and this gate is no longer reading what it thinks."
                     % CENSUS)
        for line in fh:
            row = line.rstrip("\n").split("\t")
            if row and row[0]:
                ids.add(row[0])
    return ids


def main():
    live = tracked_digests()
    spec.require_complete("the tracked-file digest", live, "git ls-files")

    if "--write" in sys.argv[1:]:
        os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
        with open(MANIFEST, "w", encoding="utf-8") as fh:
            fh.write("# Generated by ci/census/census-inputs.py --write (corpus#26).\n")
            fh.write("# What docs/census/validity-census.tsv was computed over: one\n")
            fh.write("# sha256 per node across every tracked file in its directory.\n")
            fh.write("# Re-record ONLY after re-running the census, never to silence it.\n")
            for node in sorted(live):
                fh.write("%s\t%s\n" % (node, live[node]))
        print("census-inputs: recorded %d node(s) -> %s"
              % (len(live), os.path.relpath(MANIFEST, REPO)))
        return 0

    recorded = read_manifest()
    problems = 0

    # 1. The census must have a verdict for every node in the tree. Membership drift is
    #    the cheap half and catches an added or deleted node immediately.
    verdicts = census_membership()
    added = sorted(set(live) - verdicts)
    dropped = sorted(verdicts - set(live))
    if added or dropped:
        problems = 1
        print("census-inputs: the committed census does not describe this corpus",
              file=sys.stderr)
        for n in added:
            print("  node in the tree with NO census verdict: %s" % n, file=sys.stderr)
        for n in dropped:
            print("  census verdict for a node not in the tree: %s" % n, file=sys.stderr)

    # 2. The inputs each verdict was computed over must be unchanged.
    moved = sorted(n for n in set(live) & set(recorded) if live[n] != recorded[n])
    unrecorded = sorted(set(live) - set(recorded))
    stale_rows = sorted(set(recorded) - set(live))
    if moved or unrecorded or stale_rows:
        problems = 1
        print("census-inputs: %d node(s) changed since the census was recorded, so "
              "docs/census/validity-census.tsv is stale" % len(moved), file=sys.stderr)
        for n in moved[:25]:
            print("  changed:    %s" % n, file=sys.stderr)
        if len(moved) > 25:
            print("  … and %d more" % (len(moved) - 25), file=sys.stderr)
        for n in unrecorded:
            print("  unrecorded: %s (in the tree, absent from the manifest)" % n,
                  file=sys.stderr)
        for n in stale_rows:
            print("  vanished:   %s (in the manifest, absent from the tree)" % n,
                  file=sys.stderr)
        print("\n  N_instrument is an input to a power calculation, and a figure computed "
              "over a stale membership set is worse than none.", file=sys.stderr)
        print("  Re-run the census (ci/census/sweep.sh -> classify.py -> build-census.py), "
              "commit the new TSV, then `ci/census/census-inputs.py --write`.",
              file=sys.stderr)
        print("  Re-recording WITHOUT re-running the census makes this gate agree with "
              "whatever the tree says and check nothing.", file=sys.stderr)

    if problems:
        return 2
    print("census-inputs: ok — %d node(s), census inputs unchanged since recording"
          % len(live))
    return 0


if __name__ == "__main__":
    sys.exit(main())
