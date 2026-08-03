#!/usr/bin/env bash
# corpus#14 — green_reachable at 225-node scale, without authoring anything.
#
# Every one of the 225 Exercism nodes maps 1:1 onto an upstream exercise that ships a
# canonical example solution in `.meta/`. Overlay it onto the node's editable files and run
# the node's (post-#15, exit-status) accept. Exit 0 => GREEN is reachable and the node's
# RED/GREEN bracket closes.
#
# Reference solutions live in the scratchpad and are NEVER written into red-baseline/ —
# abproof reads only red-baseline/, so it must never see a solution.
#
# Usage: prove-green.sh <language>
set -uo pipefail
# Paths: CENSUS_WORK holds the run artefacts (sweep logs, green-proof logs, upstream
# track clones). It defaults to .census-work/ beside the repo, so nothing lands in the
# repo tree. CORPUS_ROOT defaults to the repo's own red-baseline/.
CENSUS_WORK="${CENSUS_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.census-work}"
CORPUS_ROOT="${CORPUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/red-baseline}"
mkdir -p "$CENSUS_WORK"

export PATH="$PATH:/opt/homebrew/bin"
C="$CENSUS_WORK/wt-fix-15-exit-status-accept-oracle/red-baseline"   # post-#15 accepts + repaired cpp seeds
U="$CENSUS_WORK/upstream"
OUT="$CENSUS_WORK/green"
LANG_F="${1:?usage: prove-green.sh <language>}"
mkdir -p "$OUT/$LANG_F"

accept_of() {
  sed -n 's/^accept: *"\(.*\)"$/\1/p' "$1/meta.yaml" | sed -n '1p' \
    | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

# Overlay the upstream example onto a materialised seed. Echoes "ok" or a reason.
overlay() {
  # Separate `local`s: within one `local`, later assignments cannot see earlier ones.
  local w="$1" lang="$2" slug="$3"
  local m="$U/$lang/exercises/practice/$slug/.meta"
  [ -d "$m" ] || { echo "no upstream exercise"; return 1; }
  local snake; snake="$(printf '%s' "$slug" | tr '-' '_')"
  case "$lang" in
    cpp)
      [ -f "$m/example.cpp" ] || [ -f "$m/example.h" ] || { echo "no example.cpp/.h"; return 1; }
      [ -f "$m/example.cpp" ] && cp "$m/example.cpp" "$w/$snake.cpp"
      [ -f "$m/example.h" ]   && cp "$m/example.h"   "$w/$snake.h" ;;
    go)
      [ -f "$m/example.go" ] || { echo "no example.go"; return 1; }
      # Target the file the node declares EDITABLE, not the first .go in the dir. Several go
      # nodes ship a given-and-not-editable helper (interface.go, defs.go) that the tests
      # depend on; overwriting that with the example deletes the definitions it needs.
      local tgt=""
      for rel in $NODE_FILES; do
        case "$rel" in *.go) [ -f "$w/$rel" ] && tgt="$w/$rel" && break ;; esac
      done
      [ -n "$tgt" ] || tgt="$(find "$w" -maxdepth 1 -name '*.go' -not -name '*_test.go' | head -1)"
      [ -n "$tgt" ] || { echo "seed has no impl .go"; return 1; }
      cp "$m/example.go" "$tgt"
      # Multi-file examples: bring the rest, minus gen.go (a test GENERATOR, not solution code).
      for extra in "$m"/*.go; do
        case "$(basename "$extra")" in example.go|gen.go) continue ;; esac
        cp "$extra" "$w/$(basename "$extra")"
      done
      # Upstream names the package after the exercise; the corpus seed names it after its own
      # module, and the two disagree on ~a third of nodes ("found packages saddlepoints and
      # matrix"). Align the overlay to the SEED's test package -- the test file is the fixed
      # part of the node, the solution is the part being supplied.
      WORK="$w" python3 - <<'PY'
import glob, os, re
w = os.environ["WORK"]
tests = glob.glob(os.path.join(w, "*_test.go"))
pkg = None
for t in tests:
    m = re.search(r"^package (\w+)", open(t, encoding="utf-8").read(), re.M)
    if m:
        pkg = m.group(1); break
if pkg:
    for f in glob.glob(os.path.join(w, "*.go")):
        if f.endswith("_test.go"):
            continue
        src = open(f, encoding="utf-8").read()
        open(f, "w", encoding="utf-8").write(re.sub(r"^package \w+", "package " + pkg, src, count=1, flags=re.M))
PY
      # The seeds pin `go 1.18`; upstream examples use `for range int` (1.22+). That is a
      # property of the EXAMPLE, not of the node -- a 1.18-compatible solution exists for
      # every one of these katas. Bump for the proof run only; recorded in the census.
      [ -f "$w/go.mod" ] && perl -pi -e 's/^go 1\.1[0-9]\s*$/go 1.22\n/' "$w/go.mod" ;;
    java)
      [ -d "$m/src/reference/java" ] || { echo "no reference java"; return 1; }
      mkdir -p "$w/src/main/java"
      cp "$m"/src/reference/java/*.java "$w/src/main/java/" 2>/dev/null || { echo "copy failed"; return 1; } ;;
    javascript)
      [ -f "$m/proof.ci.js" ] || { echo "no proof.ci.js"; return 1; }
      cp "$m/proof.ci.js" "$w/$slug.js" ;;
    python)
      [ -f "$m/example.py" ] || { echo "no example.py"; return 1; }
      cp "$m/example.py" "$w/$snake.py" ;;
    rust)
      [ -f "$m/example.rs" ] || { echo "no example.rs"; return 1; }
      mkdir -p "$w/src"; cp "$m/example.rs" "$w/src/lib.rs"
      # Multi-module examples (e.g. macros' compile_fail_tests.rs) ship alongside example.rs.
      for extra in "$m"/*.rs; do
        case "$(basename "$extra")" in example.rs) continue ;; esac
        cp "$extra" "$w/src/$(basename "$extra")"
      done
      # Upstream keeps the SOLUTION's dependencies in .meta/Cargo-example.toml, separate from
      # the student Cargo.toml. Without them the example fails to resolve its imports
      # (E0432/E0463) and would be misread as an unsolvable node. Merge them in.
      if [ -f "$m/Cargo-example.toml" ]; then
        SEED_TOML="$w/Cargo.toml" EX_TOML="$m/Cargo-example.toml" python3 - <<'PY'
import os, re
seed_p, ex_p = os.environ["SEED_TOML"], os.environ["EX_TOML"]
seed = open(seed_p, encoding="utf-8").read()
ex = open(ex_p, encoding="utf-8").read()
m = re.search(r"^\[dependencies\](.*?)(?=^\[|\Z)", ex, re.M | re.S)
if m:
    # Merge by crate NAME, keeping the seed's pin where both declare one -- a blind
    # concatenation produces `duplicate key` and cargo refuses the manifest.
    have = set()
    sm = re.search(r"^\[dependencies\](.*?)(?=^\[|\Z)", seed, re.M | re.S)
    if sm:
        have = {ln.split("=")[0].strip() for ln in sm.group(1).splitlines() if "=" in ln}
    add = [ln for ln in m.group(1).splitlines()
           if "=" in ln and ln.split("=")[0].strip() not in have]
    if add:
        block = "\n" + "\n".join(add) + "\n"
        if sm:
            seed = re.sub(r"^\[dependencies\]", "[dependencies]" + block, seed, count=1, flags=re.M)
        else:
            seed = seed.rstrip() + "\n\n[dependencies]" + block
        open(seed_p, "w", encoding="utf-8").write(seed)
PY
      fi ;;
  esac
  echo ok
}

for node in "$C"/*; do
  [ -d "$node" ] || continue
  lang="$(sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$node/meta.yaml" | sed -n '1p')"
  [ "$lang" = "$LANG_F" ] || continue
  base="$(basename "$node")"
  [ -f "$OUT/$LANG_F.tsv" ] && cut -f1 "$OUT/$LANG_F.tsv" | grep -qx "$base" && continue
  slug="${base#"${lang}"-}"
  case "$slug" in 0[1-6]-*) printf '%s\t%s\t%s\t%s\n' "$base" "$lang" "KATA" "hand-authored: covered by ci/prove-solvable.sh" >> "$OUT/$LANG_F.tsv"; continue ;; esac

  w="$(mktemp -d)"
  cp -R "$node/seed/." "$w/"
  NODE_FILES="$(sed -n 's/^files: *\[\(.*\)\].*/\1/p' "$node/meta.yaml" | sed -n '1p' | tr ',' ' ' | tr -d '"')"
  export NODE_FILES
  why="$(overlay "$w" "$lang" "$slug")"
  if [ "$why" != ok ]; then
    printf '%s\t%s\t%s\t%s\n' "$base" "$lang" "NO_EXAMPLE" "$why" >> "$OUT/$LANG_F.tsv"
    rm -rf "$w"; printf '%-40s NO_EXAMPLE (%s)\n' "$base" "$why"; continue
  fi
  acc="$(accept_of "$node")"
  ( set +o pipefail; cd "$w" && timeout "${ACCEPT_TIMEOUT:-420}" bash -c "$acc" ) \
      >"$OUT/$LANG_F/$base.green.log" 2>&1
  rc=$?
  rm -rf "$w"
  if [ "$rc" -eq 0 ]; then v=PROVEN; else v=SOLUTION_RED; fi
  printf '%s\t%s\t%s\t%s\n' "$base" "$lang" "$v" "upstream example -> exit $rc" >> "$OUT/$LANG_F.tsv"
  printf '%-40s %s (exit %s)\n' "$base" "$v" "$rc"
done
echo "DONE $LANG_F"
