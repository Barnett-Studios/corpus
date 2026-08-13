#!/usr/bin/env python3
"""The census's SPECIFICATION side — what the corpus contains, read from the tree.

corpus#26. Every count the census reports is a count over some input file: `all.tsv` for
the RED arm, `green/<lang>.tsv` for the GREEN arm, `active-tests.tsv` for suite coverage.
Each of those is produced by a sweep that can partially fail, and every consumer of them
skipped silently on absence — a short `all.tsv` produced a short census, printed `rows: N`
for whatever N happened to be, and exited 0.

The fix is not a bigger literal. `EXPECTED_NODES = 250` would be a number inherited from
the last time someone counted, and PR #25 moved that figure twice inside one stack. The
denominator has to come from the thing being described: the node directories on disk.

This module is deliberately the ONLY place either census script learns what the corpus
contains, and it never reads a census input to find out. That direction matters — a
completeness check that enumerated from `all.tsv` would be asking the measurement whether
the measurement is complete.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORPUS = os.environ.get("CORPUS_ROOT", os.path.join(REPO, "red-baseline"))


def nodes():
    """Every node in the corpus: a directory under CORPUS_ROOT carrying a `meta.yaml`.

    `meta.yaml` rather than "is a directory", because that file is what makes a directory
    a node — it carries the accept, and a node without one cannot be measured at all.
    """
    try:
        entries = os.listdir(CORPUS)
    except OSError as exc:
        sys.exit("census: cannot read CORPUS_ROOT %s (%s). The specification is "
                 "unreadable, so nothing below it can be checked." % (CORPUS, exc))
    found = {d for d in entries
             if os.path.isfile(os.path.join(CORPUS, d, "meta.yaml"))}
    if not found:
        # A wrong CORPUS_ROOT would otherwise make every check below pass over an empty
        # population — a guard reporting green over a set it never looked at, which is
        # the failure this whole module exists to prevent (same reasoning as the
        # `verify-accept-oracle.sh` tripwire, corpus#15).
        sys.exit("census: no nodes under CORPUS_ROOT %s. Refusing to check anything "
                 "against an empty specification." % CORPUS)
    return found


def language_of(node):
    """The `language:` a node declares, or "" when it declares none."""
    p = os.path.join(CORPUS, node, "meta.yaml")
    try:
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r'^language:\s*"?([\w+-]+)"?', line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return ""


def languages():
    """Every language present in the tree.

    Read from the corpus rather than taken from a hardcoded list, so adding a seventh
    language cannot silently produce a stratum with no GREEN evidence: `build-census.py`
    iterated a literal `LANGS` and skipped any file it did not find, so a new language's
    nodes would all have come out `green_reachable=UNPROVEN` and therefore BROKEN, with
    nothing saying the input was simply never produced.
    """
    return {lang for lang in (language_of(n) for n in nodes()) if lang}


def require_complete(kind, measured, source):
    """Fail unless `measured` covers exactly the corpus. Returns nothing; exits 2.

    Both directions are reported. A node in the tree and not in the measurement is the
    silent-skip case; a node in the measurement and not in the tree means the input was
    produced against a different corpus than the one being described, which makes every
    count in the report a count over the wrong population.
    """
    spec = nodes()
    missing = sorted(spec - set(measured))
    extra = sorted(set(measured) - spec)
    if not missing and not extra:
        return
    print("census: %s does not cover the corpus (%s)" % (kind, source), file=sys.stderr)
    print("  corpus has %d node(s); %s has %d"
          % (len(spec), kind, len(set(measured))), file=sys.stderr)
    if missing:
        print("  %d node(s) in the tree that %s does not cover — every count taken from "
              "it describes a smaller population than the corpus, with nothing on the "
              "report saying so:" % (len(missing), kind), file=sys.stderr)
        for n in missing[:20]:
            print("      %s" % n, file=sys.stderr)
        if len(missing) > 20:
            print("      … and %d more" % (len(missing) - 20), file=sys.stderr)
    if extra:
        print("  %d row(s) for nodes that are not in the tree — this input was produced "
              "against a different corpus:" % len(extra), file=sys.stderr)
        for n in extra[:20]:
            print("      %s" % n, file=sys.stderr)
    sys.exit(2)


# ── self-test: the guards must bite ──────────────────────────────────────────────────
#
# Same stance as `verify-red-invariant.sh --self-test` and `verify-oracle-sabotage.sh`: a
# guard that cannot be shown to fail is not a guard. Every check in this module exists
# because its absence produced a green report over a population nobody had measured, and
# each of those absences looked exactly like this module does when it is working.
#
# Runs on a throwaway corpus, so it needs no toolchain and no census inputs.

def _self_test():
    import io
    import shutil
    import tempfile

    global CORPUS
    failures = []
    _stderr = io.StringIO()

    def expect_exit(what, fn, want_code=2, want_text=None):
        try:
            fn()
        except SystemExit as exc:
            code = exc.code if isinstance(exc.code, int) else 1
            msg = "" if isinstance(exc.code, int) else str(exc.code or "")
            if code != want_code:
                failures.append("%s: exited %s, expected %s" % (what, code, want_code))
            elif want_text and want_text not in (msg + _stderr.getvalue()):
                failures.append("%s: exited correctly but never named %r" % (what, want_text))
            return
        failures.append("%s: DID NOT FAIL — the guard is inert" % what)

    def expect_ok(what, fn):
        try:
            fn()
        except SystemExit as exc:
            failures.append("%s: failed (%s) on input it should accept" % (what, exc.code))

    tmp = tempfile.mkdtemp()
    saved, _stderr_real = CORPUS, sys.stderr
    try:
        sys.stderr = _stderr

        # 1. An empty or wrong CORPUS_ROOT must not be treated as "a corpus with no nodes".
        #    That is the whole failure class: a control reporting green over nothing.
        CORPUS = os.path.join(tmp, "does-not-exist")
        expect_exit("nodes() on an unreadable CORPUS_ROOT", nodes, 1)
        CORPUS = os.path.join(tmp, "empty")
        os.makedirs(CORPUS)
        expect_exit("nodes() on an empty CORPUS_ROOT", nodes, 1)

        # 2. A real little corpus: two languages, three nodes.
        CORPUS = os.path.join(tmp, "corpus")
        for name, lang in (("a-one", "python"), ("a-two", "python"), ("b-one", "go")):
            os.makedirs(os.path.join(CORPUS, name))
            with open(os.path.join(CORPUS, name, "meta.yaml"), "w", encoding="utf-8") as fh:
                fh.write('id: "%s"\nlanguage: "%s"\n' % (name, lang))
        # A directory without meta.yaml is not a node — build spill must not enter the
        # denominator, or every completeness check reports a phantom missing row forever.
        os.makedirs(os.path.join(CORPUS, "not-a-node"))
        if nodes() != {"a-one", "a-two", "b-one"}:
            failures.append("nodes(): counted a directory with no meta.yaml as a node")
        if languages() != {"python", "go"}:
            failures.append("languages(): %r, expected {python, go}" % (languages(),))

        # 3. require_complete, in all three directions.
        expect_ok("require_complete on exact coverage",
                  lambda: require_complete("t", {"a-one", "a-two", "b-one"}, "fixture"))
        expect_exit("require_complete with a node MISSING from the measurement",
                    lambda: require_complete("t", {"a-one", "a-two"}, "fixture"),
                    2, "b-one")
        expect_exit("require_complete with a row for a node NOT in the tree",
                    lambda: require_complete("t", {"a-one", "a-two", "b-one", "ghost"}, "fixture"),
                    2, "ghost")
    finally:
        sys.stderr = _stderr_real
        CORPUS = saved
        shutil.rmtree(tmp, ignore_errors=True)

    if failures:
        print("census spec self-test: FAIL", file=sys.stderr)
        for f in failures:
            print("  %s" % f, file=sys.stderr)
        return 1
    print("census spec self-test: PASS")
    print("  - an unreadable or empty CORPUS_ROOT fails rather than yielding an empty corpus")
    print("  - a directory without meta.yaml is not counted as a node")
    print("  - a measurement missing a node fails, and names it")
    print("  - a measurement carrying a row for a node not in the tree fails, and names it")
    return 0


if __name__ == "__main__":
    if sys.argv[1:2] == ["--self-test"]:
        sys.exit(_self_test())
    sys.exit("usage: spec.py --self-test   (this module is imported, not run)")
