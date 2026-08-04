#!/usr/bin/env python3
"""corpus#14 — build the validity census.

Joins four measured inputs into one row per node and decides a verdict:

  census-runs/all.tsv    the RED arm: each accept run against the untouched seed
  census-runs/<l>/*.log  what the runner printed, for the mechanism-ran classification
  green/<lang>.tsv       the GREEN arm: upstream reference solution overlaid, accept re-run
  active-tests.tsv       how much of each node's own suite is enabled (corpus#21)

A node is an INSTRUMENT only if all three hold:
  oracle_sound          accept scores on the runner's exit status          (#15)
  red_for_right_reason  RED on the seed AND the runner demonstrably ran    (#14)
  green_reachable       a reference solution reaches GREEN                 (#14)

Anything else is BROKEN, except javascript-ledger which is UNUSABLE_BY_DESIGN (#16):
a refactoring exercise whose premise is that the seed passes, so no oracle recovers a
RED state for it.

Nodes that pass all three but grade on a fraction of their own suite (#21) are still
instruments — a one-assertion bar is a weak instrument, not a broken one — and carry a
caveat so the count can be reported at both bars.
"""

import json
import os
import re

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
H = os.environ.get("CENSUS_WORK", os.path.join(REPO, ".census-work"))
RUNS = os.path.join(H, "census-runs")
GREEN = os.path.join(H, "green")
CORPUS = os.environ.get("CORPUS_ROOT", os.path.join(REPO, "red-baseline"))

import classify  # reuse the per-language runner signatures

LANGS = ["cpp", "go", "java", "javascript", "python", "rust"]


def meta(node, field):
    p = os.path.join(CORPUS, node, "meta.yaml")
    try:
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith(field + ":"):
                    return line.split(":", 1)[1].strip().strip('"')
    except OSError:
        pass
    return ""


def load():
    red = {}
    with open(os.path.join(RUNS, "all.tsv"), encoding="utf-8") as fh:
        for line in fh:
            p = line.rstrip("\n").split("\t")
            if len(p) < 7:
                continue
            red[p[0]] = {"lang": p[1], "exit": int(p[4])}

    green = {}
    for lang in LANGS:
        path = os.path.join(GREEN, lang + ".tsv")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                p = line.rstrip("\n").split("\t")
                if len(p) >= 4:
                    green[p[0]] = {"verdict": p[2], "why": p[3]}

    active = {}
    with open(os.path.join(H, "active-tests.tsv"), encoding="utf-8") as fh:
        for line in fh:
            n, l, tot, act = line.rstrip("\n").split("\t")
            active[n] = (int(tot), int(act))
    return red, green, active


def main():
    red, green, active = load()
    rows = []

    for node in sorted(red):
        lang = red[node]["lang"]
        rc = red[node]["exit"]

        log = ""
        p = os.path.join(RUNS, lang, node + ".exit.log")
        if os.path.exists(p):
            with open(p, encoding="utf-8", errors="replace") as fh:
                log = fh.read()
        red_v, red_why = classify.classify_red(node, lang, rc, log)

        # oracle_sound: post-#15 no accept pipes its runner. Measured, not assumed.
        acc = meta(node, "accept")
        oracle_sound = "|" not in acc

        g = green.get(node, {"verdict": "MISSING", "why": ""})
        if g["verdict"] == "PROVEN":
            green_v, green_why = "PROVEN", "upstream Exercism example reaches GREEN"
        elif g["verdict"] == "KATA":
            green_v, green_why = "PROVEN", "hand-authored kata; ci/prove-solvable.sh proves it in CI"
        elif g["verdict"] == "SOLUTION_RED":
            green_v, green_why = "UNPROVEN", "reference solution did NOT reach GREEN: " + g["why"]
        elif g["verdict"] == "NO_EXAMPLE":
            green_v, green_why = "UNPROVEN", "no reference solution exists for this node"
        else:
            green_v, green_why = "UNPROVEN", "not measured"

        tot, act = active.get(node, (0, 0))

        # ── verdict ──────────────────────────────────────────────────────────
        if node == "javascript-ledger":
            verdict = "UNUSABLE_BY_DESIGN"
            reason = ("corpus#16: upstream refactoring exercise whose premise is that the seed "
                      "passes; no accept oracle recovers a RED state")
        elif not oracle_sound:
            verdict, reason = "BROKEN", "corpus#15: accept still scores by a success-substring filter"
        elif red_v == "NOT_RED":
            verdict, reason = "BROKEN", "corpus#11: accept exits 0 on the untouched seed — no RED state"
        elif red_v == "ENV":
            verdict, reason = "BROKEN", "corpus#14: RED for an environmental reason — " + red_why
        elif red_v == "UNKNOWN":
            verdict, reason = "BROKEN", "corpus#14: " + red_why
        elif green_v != "PROVEN":
            verdict, reason = "BROKEN", "corpus#14: " + green_why
        else:
            verdict = "INSTRUMENT"
            reason = "RED on seed (runner ran), GREEN with a reference solution, exit-status oracle"
            if tot > 0 and act < tot:
                reason += "; corpus#21: grades on %d of %d tests" % (act, tot)

        rows.append({
            "node_id": node, "lang": lang,
            "provenance": meta(node, "provenance"),
            "oracle_sound": "yes" if oracle_sound else "no",
            "red_for_right_reason": red_v,
            "green_reachable": green_v,
            "tests_total": tot, "tests_enabled": act,
            "verdict": verdict, "reason": reason,
        })

    cols = ["node_id", "lang", "provenance", "oracle_sound", "red_for_right_reason",
            "green_reachable", "tests_total", "tests_enabled", "verdict", "reason"]
    out = os.path.join(H, "validity-census.tsv")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("\t".join(cols) + "\n")
        for r in rows:
            fh.write("\t".join(str(r[c]) for c in cols) + "\n")

    # ── report ───────────────────────────────────────────────────────────────
    def tally(key):
        d = {}
        for r in rows:
            d[r[key]] = d.get(r[key], 0) + 1
        return d

    print("rows: %d" % len(rows))
    for k in ("oracle_sound", "red_for_right_reason", "green_reachable", "verdict"):
        print("\n%s:" % k)
        for v, n in sorted(tally(k).items(), key=lambda kv: -kv[1]):
            print("   %-22s %s" % (v, n))

    inst = [r for r in rows if r["verdict"] == "INSTRUMENT"]
    strong = [r for r in inst if r["tests_enabled"] == r["tests_total"]]
    print("\n=== N_instrument ===")
    print("  INSTRUMENT (all three columns hold):        %d" % len(inst))
    print("    of which full-suite (corpus#21 clean):    %d" % len(strong))
    print("    of which grade on a partial suite:        %d" % (len(inst) - len(strong)))
    print("\n  by provenance:")
    for prov in ("hand-authored", "exercism"):
        a = len([r for r in inst if r["provenance"] == prov])
        b = len([r for r in strong if r["provenance"] == prov])
        print("    %-16s instrument=%-4s full-suite=%s" % (prov, a, b))
    print("\n  by language:")
    for lang in LANGS:
        a = len([r for r in inst if r["lang"] == lang])
        t = len([r for r in rows if r["lang"] == lang])
        print("    %-12s %s / %s" % (lang, a, t))

    print("\n=== every non-INSTRUMENT node ===")
    for r in rows:
        if r["verdict"] != "INSTRUMENT":
            print("  %-32s %-20s %s" % (r["node_id"], r["verdict"], r["reason"][:78]))
    print("\nwrote %s" % out)


if __name__ == "__main__":
    main()
