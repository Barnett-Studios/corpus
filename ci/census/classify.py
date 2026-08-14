#!/usr/bin/env python3
"""Stage 2 of the corpus validity census (corpus#14).

Reads what the runners actually printed (stage 1, sweep.sh) and decides, per node,
whether it functions as a measurement instrument. Classification is offline so it can be
re-derived without re-running 250 accepts.

A node is an instrument only if all three hold:

  oracle_sound          the accept scores on the runner's exit status  (#15)
  red_for_right_reason  RED on the untouched seed AND the runner demonstrably ran  (#14)
  green_reachable       a reference solution reaches GREEN

The middle column is the one that needs care, and it is where corpus#14's cpp finding
came from: a non-zero exit is evidence of the invariant ONLY if the mechanism ran. The
per-language signatures below distinguish "the stub is unimplemented" from "the toolchain
never reached the tests". Every verdict carries the evidence string that produced it, so
a reader can audit the call rather than trust it.
"""

import os
import re
import sys

import spec  # corpus#26: what the corpus contains, read from the tree and never from an input

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
H = os.environ.get("CENSUS_WORK", os.path.join(REPO, ".census-work"))
RUNS = os.path.join(H, "census-runs")
CORPUS = os.environ.get("CORPUS_ROOT", os.path.join(REPO, "red-baseline"))

# ── red_for_right_reason: per-language evidence ─────────────────────────────────
# (regex, verdict, human-readable evidence). First match wins, so ENV patterns that are
# strictly more specific must come first.
SIGNATURES = {
    "python": [
        (r"No module named pytest", "ENV", "pytest not installed"),
        (r"ImportError: cannot import name '(\w+)' from '(\w+)'", "TASK",
         "test imports a symbol the stub does not define"),
        (r"ModuleNotFoundError: No module named '(\w+)'", "TASK",
         "test imports a module the task must create"),
        (r"(\d+) failed", "TASK", "pytest ran and reported failures"),
        (r"FAILED \(failures=", "TASK", "unittest ran and reported failures"),
        (r"NotImplementedError", "TASK", "stub raises NotImplementedError"),
    ],
    "go": [
        (r"^go: ", "ENV", "go toolchain/module error"),
        (r"\[build failed\]", "TASK", "test package does not compile against the stub"),
        (r"--- FAIL", "TASK", "go test ran and reported failures"),
        (r"^FAIL", "TASK", "go test reported FAIL"),
        (r"undefined: ", "TASK", "test references a symbol the stub does not define"),
    ],
    "rust": [
        (r"could not find `Cargo.toml`", "ENV", "no cargo manifest"),
        (r"failed to (download|get) ", "ENV", "crate download failed"),
        (r"test result: FAILED", "TASK", "cargo test ran and reported failures"),
        (r"error\[E\d+\]", "TASK", "test does not compile against the stub"),
        (r"panicked at", "TASK", "stub panics (todo!/unimplemented!)"),
        # Upstream rust stubs use `???` as a placeholder type and half-written macro arms, so
        # the compiler rejects them with uncoded errors. That is the stub being unimplemented,
        # not a broken toolchain — the crate named in the message is the node's own.
        (r"could not compile `[^`]+` \((lib|test)", "TASK",
         "the node's own crate does not compile — stub is unimplemented"),
    ],
    "java": [
        (r"Could not resolve|Could not download|Could not GET", "ENV", "dependency resolution failed"),
        (r"Could not determine java version|Unsupported class file", "ENV", "JDK/gradle mismatch"),
        (r"Execution failed for task ':test'", "TASK", "gradle test task ran and failed"),
        (r"Compilation failed|error: cannot find symbol", "TASK",
         "test does not compile against the stub"),
        (r"Execution failed for task ':compileTestJava'", "TASK",
         "test does not compile against the stub"),
        # The 6 java katas do not use gradle: `javac … && java TestRunner <case>`. Their
        # supervising probe reports the stub's failure in its own words.
        (r"probe for \w+ exited \d+ without producing observations", "TASK",
         "supervising probe ran; stub produced no observations"),
        (r"java\.lang\.AssertionError", "TASK", "TestRunner ran and asserted"),
    ],
    "javascript": [
        (r"npm ERR!", "ENV", "npm install failed"),
        (r"Cannot find module '(jest|mocha|chai|@babel)", "ENV", "test framework not installed"),
        (r"Tests:\s+\d+ failed", "TASK", "jest ran and reported failures"),
        (r"\d+ failing", "TASK", "mocha ran and reported failures"),
        (r"Test suite failed to run", "TASK", "spec does not load against the stub"),
    ],
    "cpp": [
        (r"Could NOT find Boost", "ENV", "Boost absent and not declared in requires:"),
        (r"CMake Error", "ENV", "cmake configure failed"),
        (r"_test\.cpp\.o\] Error", "TASK", "test does not compile against the stub"),
        (r"error: .*(no member named|undeclared|not declared)", "TASK",
         "test references a symbol the stub does not define"),
        (r"assertion.*failed|FAILED:", "TASK", "test binary ran and reported failures"),
        (r"\] Error [12]", "TASK", "build failed at the test target"),
    ],
}


def meta(node, field):
    path = os.path.join(CORPUS, node, "meta.yaml")
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith(field + ":"):
                    return line.split(":", 1)[1].strip().strip('"')
    except OSError:
        pass
    return ""


def classify_red(node, lang, exit_code, log):
    """-> (verdict, evidence). TASK | ENV | NOT_RED | UNKNOWN."""
    if exit_code == 0:
        return "NOT_RED", "accept exits 0 on the untouched seed"
    for pattern, verdict, why in SIGNATURES.get(lang, []):
        if re.search(pattern, log, re.M):
            return verdict, why
    return "UNKNOWN", "non-zero exit, but no runner signature matched — mechanism unproven"


def main():
    rows = []
    all_tsv = os.path.join(RUNS, "all.tsv")
    with open(all_tsv, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 7:
                # NOT `continue` (corpus#26). This function returned None and the module
                # ended `sys.exit(main())`, so a column-count change skipped every line
                # and still exited 0 with an empty classification.
                sys.exit("classify: %s:%d has %d field(s), expected >= 7. A row whose "
                         "shape this script does not recognise is not a row to skip.\n  %r"
                         % (all_tsv, lineno, len(parts), line[:120]))
            node, lang = parts[0], parts[1]
            exit_rc = int(parts[4])
            log = ""
            p = os.path.join(RUNS, lang, node + ".exit.log")
            if os.path.exists(p):
                with open(p, encoding="utf-8", errors="replace") as lf:
                    log = lf.read()
            red, evidence = classify_red(node, lang, exit_rc, log)
            rows.append({
                "node": node, "lang": lang, "exit_rc": exit_rc,
                "red": red, "evidence": evidence,
                "provenance": meta(node, "provenance"),
            })

    spec.require_complete("the classification", {r["node"] for r in rows}, all_tsv)

    # enabled-test counts (corpus#21)
    enabled = {}
    with open(os.path.join(H, "active-tests.tsv"), encoding="utf-8") as fh:
        for line in fh:
            n, l, tot, act = line.rstrip("\n").split("\t")
            enabled[n] = (int(tot), int(act))

    for r in rows:
        r["tests_total"], r["tests_enabled"] = enabled.get(r["node"], (0, 0))

    # summary
    print("=== red_for_right_reason ===")
    tally = {}
    for r in rows:
        tally.setdefault((r["lang"], r["red"]), 0)
        tally[(r["lang"], r["red"])] += 1
    for (lang, red), n in sorted(tally.items()):
        print("  %-12s %-8s %s" % (lang, red, n))

    print("\n=== nodes needing a hand-look (UNKNOWN / ENV / NOT_RED) ===")
    for r in rows:
        if r["red"] != "TASK":
            print("  %-30s %-11s %-8s rc=%-4s %s"
                  % (r["node"], r["lang"], r["red"], r["exit_rc"], r["evidence"]))

    import json
    with open(os.path.join(H, "census-stage2.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=1)
    print("\nwrote census-stage2.json (%d rows)" % len(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
