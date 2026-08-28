#!/usr/bin/env bash
# Regenerate MANIFEST.tsv from the corpus node data, or (--check) verify the
# committed manifest still matches the data — so attribution can never silently
# drift from what is actually shipped.
#
# Usage:
#   verify-attribution.sh [--check] [<corpus-root>]
# <corpus-root> defaults to $CORPUS_ROOT, else the repo's own red-baseline/ dir
# (resolved relative to this script).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0
CORPUS_ROOT="${CORPUS_ROOT:-}"

for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    *) CORPUS_ROOT="$arg" ;;
  esac
done
if [[ -z "$CORPUS_ROOT" ]]; then
  CORPUS_ROOT="$HERE/red-baseline"
fi
if [[ ! -d "$CORPUS_ROOT" ]]; then
  echo "corpus root not found: $CORPUS_ROOT (set \$CORPUS_ROOT or pass it as an arg)" >&2
  exit 2
fi

# ── the unclassified-artifact guard (#2) ─────────────────────────────────────────────
#
# `generate` detects bundled third-party by two hard-coded filenames, and `--check` diffs
# its output against the committed manifest. Both sides of that diff come from the same two
# rules, so the gate proves the manifest is **self-consistent with the heuristic** and says
# nothing about whether the heuristic is **correct**. Anything else bundled — a vendored
# module, `doctest.h`, a JUnit jar — is recorded as `-` and the gate stays green.
#
# So this asks the other question, with an enumeration that does NOT come from those rules:
# sweep every shipped file for the shapes third-party code takes, and **refuse** anything
# not explicitly classified. Detection is now an allowlist with a hard failure, which is
# what makes the answer trustworthy rather than merely stable.
#
# Two signals, chosen after measuring what is actually in the corpus (1520 tracked files):
#   content — a copyright / SPDX / "licensed under" line. Precise here: exactly 49 LICENSE,
#             47 gradlew, 47 gradlew.bat, 26 catch.hpp, and nothing else.
#   shape   — a binary or archive extension, or a path inside a vendored-dependency
#             directory. Catches what carries no header: 47 gradle-wrapper.jar, and today
#             nothing else at all.
#
# The honest limit, stated because a guard that hides one is worse than no guard. Two earlier
# versions of this comment got it wrong in opposite directions: "no licence header" was
# narrower than the hole, and "every licence family outside Apache/MIT/Boost" was wider. The
# axis is neither. It is the FORM OF THE COPYRIGHT LINE.
#
# `grep -qEi` below is case-insensitive, so `copyright \(c\)` also matches `Copyright (C)` —
# the opening line of the canonical GPL, BSD-3-Clause, ISC and MIT headers. All four refuse.
# Measured over 14 header shapes: 6 refuse, 8 pass. What passes is a copyright line in some
# other form, or none — `Copyright ©`, a bare `(C) 2020` with no keyword, `Copyright … All
# rights reserved`, an MPL-2.0 notice alone, a "this program is free software" preamble alone,
# GPL/BSD bodies with the copyright line stripped, and no header at all.
#
# So the hole is: a vendored *source* file with an ordinary extension carrying none of the
# three forms. Widening the pattern is a real option and is NOT taken here — `Copyright` alone
# matches ordinary prose, and this gate hard-fails, so recall is bought with false refusals on
# files nobody vendored.
#
# TRACKED files, not the working tree: the claim is about what is redistributed, and a local
# `__pycache__` is not. Running the sweep over a dirty tree reported two `.pyc` files as
# unclassified artifacts while `git status` was clean — a false finding this guard would
# otherwise have made on every developer who had run the suite.
ARTIFACT_CONTENT_RE='copyright \(c\)|SPDX-License-Identifier|Licensed under the (Apache|MIT|Boost)'
ARTIFACT_SHAPE_RE='\.(jar|zip|whl|tar|tgz|gz|so|dylib|dll|a|class|pyc|exe|wasm)$|(^|/)(node_modules|vendor|third_party|bower_components|site-packages|Godeps)/'
# Every entry must match something — `unmatched_classifications` fails if one stops doing so,
# so a rule that outlives the artifact it classifies cannot sit here looking like coverage.
#
# ONE list. The regex and the anti-rot loop are both derived from it, because they were two
# hand-written copies of the same five names and only entries appearing in BOTH were covered:
# adding a classification to the regex alone — `nonexistent\.blob`, matching nothing shipped —
# left `--self-test` and a live `--check` at exit 0, green on exactly the condition anti-rot
# exists to detect. This is a DRIFT property, not a completeness one, so a shared denominator
# is the correct shape here: the claim is about `CLASSIFIED`, so `CLASSIFIED` must be the
# thing enumerated.
CLASSIFIED_NAMES=(LICENSE gradlew gradlew.bat catch.hpp gradle-wrapper.jar)

# Entries are plain filenames, and the refusal below is why that can be assumed rather than
# hoped: only `.` is escaped when a name is spliced into a regex, so a name carrying any other
# metacharacter would build a pattern that silently means something else. Fail loudly instead.
for _n in "${CLASSIFIED_NAMES[@]}"; do
    [[ "$_n" =~ ^[A-Za-z0-9._-]+$ ]] || {
        echo "CLASSIFIED_NAMES entry '$_n' is not a plain filename — only [A-Za-z0-9._-] is" \
             "escaped correctly into the regex below" >&2
        exit 2
    }
done
unset _n
CLASSIFIED="(^|/)($(IFS='|'; printf '%s' "${CLASSIFIED_NAMES[*]//./\\.}"))\$"

# Files this sweep can see, one per line. Prefers git so the answer is about what ships.
shipped_files() {
    local root="$1"
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$root" ls-files
    else
        echo "note: $root is not a git work tree — sweeping the working tree, which may include build output" >&2
        (cd "$root" && find . -type f | sed 's|^\./||')
    fi
}

# Shipped files that look like third-party and are not classified. Takes the file list as
# text rather than calling `shipped_files` itself, so no consumer of it sits downstream of a
# pipe it can close early — see `unmatched_classifications`.
unclassified_artifacts() {
    local root="$1" files="$2" f
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ "$f" =~ $CLASSIFIED ]]; then continue; fi
        if [[ "$f" =~ $ARTIFACT_SHAPE_RE ]]; then printf '%s\tshape\n' "$f"; continue; fi
        if grep -qEi "$ARTIFACT_CONTENT_RE" "$root/$f" 2>/dev/null; then printf '%s\tcontent\n' "$f"; fi
    done <<< "$files"
}

# Anti-rot: a classification whose artifact is gone is dead coverage that still reads as
# coverage. The same property the RED-invariant quarantine holds, for the same reason.
#
# The list arrives as text, and that is not tidiness. `shipped_files "$root" | grep -q …`
# reported `gradlew.bat` and `catch.hpp` missing while 47 and 26 of them were shipped:
# `grep -q` exits on its first match, `git ls-files` dies of SIGPIPE, and `set -o pipefail`
# makes the pipeline fail — so a classification failed the check precisely BECAUSE it matched
# early. Nondeterministic, and in the direction that invents findings.
unmatched_classifications() {
    local files="$1" name
    for name in "${CLASSIFIED_NAMES[@]}"; do
        grep -qE "(^|/)${name//./\\.}$" <<< "$files" || printf '%s\n' "$name"
    done
}

generate() {
  # `requires`, not `accept_tool`: this column has only ever mirrored the meta.yaml field,
  # and 59 nodes already read `-` because they declare none. #27 drops `gradle` from the 47
  # wrapper nodes — their accept is `./gradlew`, which needs no ambient tool — so under the
  # old name the manifest would have asserted that a gradle node has no accept tool. The
  # column has no consumer outside this script; the name was the only thing making a claim.
  printf 'node_id\tlanguage\trequires\tseed_license\tthird_party\tprovenance\n'
  for d in "$CORPUS_ROOT"/*/; do
    local id lang req lic tp
    id=$(basename "$d")
    # A node without a readable meta.yaml is malformed — warn and skip it rather than
    # let a failing sed under `set -o pipefail` abort mid-generation (which, if we wrote
    # straight to the tracked file, would truncate it). Skipping keeps generation total.
    if [[ ! -r "$d/meta.yaml" ]]; then
      echo "warning: $id has no readable meta.yaml — skipped" >&2
      continue
    fi
    # requires: assumes at most one tool per node (true for the current corpus); a
    # multi-tool node would collapse "a", "b" to a,b — revisit the extraction if that changes.
    lang=$(sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}/\1/p' "$d/meta.yaml" 2>/dev/null | head -1)
    req=$(sed -n 's/.*requires: *\[\(.*\)\].*/\1/p' "$d/meta.yaml" 2>/dev/null | head -1 | tr -d '"[:space:]')
    [[ -z "$req" ]] && req="-"
    lic="none"; [[ -f "$d/seed/LICENSE" ]] && lic="MIT(Exercism)"
    tp=""
    [[ -n "$(find "$d" -name catch.hpp 2>/dev/null)" ]] && tp="Catch2/BSL-1.0"
    [[ -n "$(find "$d" -name gradlew 2>/dev/null)" ]] && tp="${tp:+$tp,}Gradle-wrapper/Apache-2.0"
    [[ -z "$tp" ]] && tp="-"
    # provenance is READ from the node's own declaration, never inferred. `seed_license`
    # above is derived from LICENSE-file presence and is wrong for that reason (#1); a
    # contamination marker inferred from a filename pattern would repeat the mistake on a
    # field where being wrong is worse — it decides which nodes count as held-out.
    prov=$(sed -n 's/^provenance: *"\{0,1\}\([a-z-]*\)"\{0,1\}/\1/p' "$d/meta.yaml" 2>/dev/null | head -1)
    if [[ -z "$prov" ]]; then
      echo "error: $id declares no provenance: (expected \"exercism\" or \"hand-authored\")" >&2
      exit 1
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$lang" "$req" "$lic" "$tp" "$prov"
  done
}

if [[ "${SELF_TEST:-0}" == "1" ]]; then
  # A guard nobody has watched refuse is a guard nobody has watched. Three fixtures, each a
  # shape the corpus does not currently contain — which is the point: the live sweep passes,
  # so nothing else here proves the refusal path works at all.
  # One trap, installed the moment `$t` exists: four `exit 1` paths below sat between the
  # `mktemp -d` and the trap that used to be installed further down, and each leaked the
  # fixture tree. `resource-cleanup` says every path including the error paths, and these are
  # the error paths. `$e` is created later and joins the same trap rather than a second one.
  t=$(mktemp -d); e=""
  trap 'rm -rf "$t" ${e:+"$e"}' EXIT
  mkdir -p "$t/n/seed"
  printf 'id: "n"\nlanguage: "python"\nprovenance: "hand-authored"\n' > "$t/n/meta.yaml"
  printf 'print(1)\n' > "$t/n/seed/main.py"

  # 1. a vendored source file carrying a licence header (the CONTENT signal)
  printf '// Copyright (c) 2020 Someone\nint f(void);\n' > "$t/n/seed/doctest.h"
  # 2. a binary artifact with no header at all (the SHAPE signal)
  printf '\x50\x4b\x03\x04binary' > "$t/n/seed/junit.jar"
  # 3. a plain source file inside a vendored directory (the SHAPE signal, path arm)
  mkdir -p "$t/n/seed/node_modules/left-pad"; printf 'module.exports=1\n' > "$t/n/seed/node_modules/left-pad/index.js"

  found=$(unclassified_artifacts "$t" "$( (cd "$t" && find . -type f | sed 's|^\./||') )")
  for want in doctest.h junit.jar node_modules/left-pad/index.js; do
    grep -q "$want" <<< "$found" || {
      echo "SELF-TEST FAIL: $want was not refused" >&2; printf '%s\n' "$found" >&2; exit 1; }
  done
  # The control. Without it a sweep that refused EVERY file would satisfy the three above
  # while making the gate unusable, and the live corpus passing is not proof — the corpus is
  # exactly the input this guard was tuned on.
  grep -q 'main.py\|meta.yaml' <<< "$found" && {
    echo "SELF-TEST FAIL: an ordinary source file was refused" >&2; printf '%s\n' "$found" >&2; exit 1; }
  # And a classified artifact must pass, or CLASSIFIED is doing nothing.
  cp "$t/n/seed/junit.jar" "$t/n/seed/gradle-wrapper.jar"
  found2=$(unclassified_artifacts "$t" "$( (cd "$t" && find . -type f | sed 's|^\./||') )")
  grep -q 'gradle-wrapper.jar' <<< "$found2" && {
    echo "SELF-TEST FAIL: a classified artifact was refused" >&2; exit 1; }

  # End-to-end, because everything above tests the FUNCTION and the defect could live in the
  # wiring. Stubbing the fire (`if [[ -n "" ]]`) left every assertion above green and the live
  # `--check` green too — the guard computed its answer correctly and nobody acted on it.
  #
  # `--check "$t"` hits the guard before the manifest diff, so the fixture needing no
  # MANIFEST.tsv is fine. The MESSAGE is asserted, not just the exit code: with the fire
  # stubbed this same invocation still exits 1, on the stale-manifest branch, for an unrelated
  # reason.
  # Anti-rot, end-to-end and on its own fixture: a corpus with nothing classified in it must
  # stop, because a classification matching nothing is dead coverage that still reads as
  # coverage. Its own fixture because the unclassified guard runs first and would mask it.
  b=$(mktemp -d); mkdir -p "$b/n/seed"
  printf 'id: "n"\nlanguage: "cpp"\nprovenance: "hand-authored"\n' > "$b/n/meta.yaml"
  printf 'int main(){}\n' > "$b/n/seed/main.cpp"
  rot=$(SELF_TEST=0 bash "${BASH_SOURCE[0]}" --check "$b" 2>&1) && rot_rc=0 || rot_rc=$?
  rm -rf "$b"
  if [[ "$rot_rc" == 0 ]] || ! grep -q 'match nothing shipped' <<< "$rot"; then
    echo "SELF-TEST FAIL: a corpus with no classified artifact did not trip anti-rot (rc=$rot_rc)" >&2
    printf '%s\n' "$rot" >&2; exit 1
  fi

  # A SECOND fixture for the end-to-end run, carrying one of every classified artifact. `$t`
  # has none of LICENSE/gradlew/gradlew.bat/catch.hpp, so running the script against it stops
  # at the anti-rot branch instead — a confound that made this assertion pass for a mutant
  # that only warned. The guard under test has to be the only reason to stop.
  e=$(mktemp -d)
  mkdir -p "$e/n/seed/gradle/wrapper"
  printf 'id: "n"\nlanguage: "cpp"\nprovenance: "hand-authored"\n' > "$e/n/meta.yaml"
  printf 'int main(){}\n'            > "$e/n/seed/main.cpp"
  printf 'MIT\nCopyright (c) X\n'    > "$e/n/seed/LICENSE"
  printf '#!/bin/sh\n# Copyright (c) Gradle\n' > "$e/n/seed/gradlew"
  printf '@rem Copyright (c) Gradle\n'         > "$e/n/seed/gradlew.bat"
  printf '// Copyright (c) Catch2\n'           > "$e/n/seed/catch.hpp"
  printf 'PK\x03\x04'                          > "$e/n/seed/gradle/wrapper/gradle-wrapper.jar"
  # …and the one thing that must stop it.
  printf '// Copyright (c) 2020 Someone\n' > "$e/n/seed/doctest.h"

  e2e=$(SELF_TEST=0 bash "${BASH_SOURCE[0]}" --check "$e" 2>&1) && e2e_rc=0 || e2e_rc=$?
  if [[ "$e2e_rc" == 0 ]] || ! grep -q 'unclassified third-party artifact' <<< "$e2e"; then
    echo "SELF-TEST FAIL: the script did not REFUSE a corpus holding unclassified artifacts (rc=$e2e_rc)" >&2
    printf '%s\n' "$e2e" >&2; exit 1
  fi
  # It has to STOP there, not warn and carry on. Dropping the `exit 1` and keeping the
  # diagnostic satisfied the two conditions above — the run continued to the manifest diff and
  # failed there instead, so a non-zero exit and the right message were both present for the
  # wrong reason. On a corpus whose manifest happened to match, that mutant exits 0 and ships
  # the artifact with a warning nobody reads.
  if grep -q 'MANIFEST.tsv' <<< "$e2e"; then
    echo "SELF-TEST FAIL: the refusal did not stop the run — it reached the manifest diff" >&2
    printf '%s\n' "$e2e" >&2; exit 1
  fi

  # Anti-rot reads CLASSIFIED_NAMES, and that is the property — not that it fires on a corpus
  # holding nothing classified, which the `$b` fixture above already covers and which a
  # hard-coded loop passes just as well. The defect was two hand-written copies of the same
  # five names: a classification added to one alone was dead coverage that both the self-test
  # and a live `--check` reported as fine.
  #
  # `$e` carries one of every classified artifact, so on the real list nothing is unmatched —
  # and adding one name that matches nothing must come back named. Both directions, because
  # the first alone is satisfied by a function that returns every name it is given.
  e_files=$( (cd "$e" && find . -type f | sed 's|^\./||') )
  live_dead=$(unmatched_classifications "$e_files")
  if [[ -n "$live_dead" ]]; then
    echo "SELF-TEST FAIL: a fixture carrying every classified artifact reported dead entries: $live_dead" >&2
    exit 1
  fi
  _saved_classified=("${CLASSIFIED_NAMES[@]}")
  CLASSIFIED_NAMES+=("nonexistent.blob")
  injected_dead=$(unmatched_classifications "$e_files")
  CLASSIFIED_NAMES=("${_saved_classified[@]}")
  if ! grep -qx 'nonexistent.blob' <<< "$injected_dead"; then
    echo "SELF-TEST FAIL: a classification matching nothing shipped was not reported dead —" \
         "anti-rot is not reading CLASSIFIED_NAMES (got: ${injected_dead:-<empty>})" >&2
    exit 1
  fi

  echo "attribution self-test: PASS"
  echo "  - a vendored source file with a licence header is refused (content)"
  echo "  - a binary artifact with no header is refused (shape)"
  echo "  - a plain file inside a vendored directory is refused (shape, path)"
  echo "  - an ordinary source file and a classified artifact are not"
  echo "  - and the script itself STOPS, non-zero, before the manifest diff"
  echo "  - a classification matching nothing shipped stops it too (anti-rot)"
  echo "  - anti-rot enumerates CLASSIFIED_NAMES, so one list governs the regex and the loop"
  exit 0
fi

# Runs in BOTH modes. Generating a manifest that omits an unclassified artifact is the same
# defect as checking one — the file would then be committed and `--check` would agree with it
# forever.
shipped=$(shipped_files "$CORPUS_ROOT")
unclassified=$(unclassified_artifacts "$CORPUS_ROOT" "$shipped")
if [[ -n "$unclassified" ]]; then
  echo "unclassified third-party artifact(s) — classify each in CLASSIFIED and attribute it," >&2
  echo "or remove it from the corpus. Redistributing it unattributed is the thing this gate exists to stop:" >&2
  printf '%s\n' "$unclassified" | sed 's/^/  /' >&2
  exit 1
fi
dead=$(unmatched_classifications "$shipped")
if [[ -n "$dead" ]]; then
  echo "classification(s) that match nothing shipped — delete them rather than leave dead coverage:" >&2
  printf '%s\n' "$dead" | sed 's/^/  /' >&2
  exit 1
fi

if [[ "$CHECK" == "1" ]]; then
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  generate > "$tmp"
  if ! diff -u "$HERE/MANIFEST.tsv" "$tmp"; then
    echo "MANIFEST.tsv is stale — attribution drifted from the corpus data. Regenerate." >&2
    exit 1
  fi
  echo "MANIFEST.tsv matches the corpus data ($(($(wc -l < "$HERE/MANIFEST.tsv") - 1)) nodes)."
else
  # Write to a temp then atomically rename, so a mid-generation failure never leaves the
  # tracked MANIFEST.tsv truncated.
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  generate > "$tmp"
  mv "$tmp" "$HERE/MANIFEST.tsv"
  echo "wrote MANIFEST.tsv ($(($(wc -l < "$HERE/MANIFEST.tsv") - 1)) nodes)"
fi
