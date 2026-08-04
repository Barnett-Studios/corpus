#!/usr/bin/env bash
# Per node: how many of its acceptance tests are ENABLED?
# Emits a TSV consumed by the census: node, lang, tests_total, tests_active.
set -uo pipefail
# Paths: CENSUS_WORK holds the run artefacts (sweep logs, green-proof logs, upstream
# track clones). It defaults to .census-work/ beside the repo, so nothing lands in the
# repo tree. CORPUS_ROOT defaults to the repo's own red-baseline/.
CENSUS_WORK="${CENSUS_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.census-work}"
CORPUS_ROOT="${CORPUS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/red-baseline}"
mkdir -p "$CENSUS_WORK"

C="$CORPUS_ROOT"
OUT="$CENSUS_WORK/active-tests.tsv"
: > "$OUT"

for d in "$C"/*; do
  [ -d "$d" ] || continue
  n="$(basename "$d")"
  lang="$(sed -n 's/^language: *"\{0,1\}\([a-z+]*\)"\{0,1\}.*/\1/p' "$d/meta.yaml" | sed -n '1p')"
  tot=0; act=0
  case "$lang" in
    rust)
      for t in "$d"/seed/tests/*.rs "$d"/seed/src/lib.rs; do
        [ -f "$t" ] || continue
        tot=$((tot + $(grep -c '#\[test\]' "$t")))
        act=$((act + $(grep -c '#\[test\]' "$t") - $(grep -c '#\[ignore\]' "$t")))
      done ;;
    java)
      while IFS= read -r t; do
        [ -n "$t" ] || continue
        tot=$((tot + $(grep -c '@Test' "$t")))
        act=$((act + $(grep -c '@Test' "$t") - $(grep -cE '@Disabled|@Ignore' "$t")))
      done < <(find "$d/seed" -name '*Test.java' 2>/dev/null) ;;
    javascript)
      for t in "$d"/seed/*.spec.js; do
        [ -f "$t" ] || continue
        x=$(grep -cE '(^|[^a-zA-Z])xtest\(|\.skip\(' "$t")
        a=$(grep -cE '(^|[^a-zA-Z])test\(|(^|[^a-zA-Z])it\(' "$t")
        tot=$((tot + a + x)); act=$((act + a))
      done ;;
    cpp)
      t="$d/seed/$(echo "${n#cpp-}" | tr '-' '_')_test.cpp"
      if [ -f "$t" ]; then
        tot=$(grep -c 'TEST_CASE' "$t")
        line=$(grep -n 'EXERCISM_RUN_ALL_TESTS' "$t" | head -1 | cut -d: -f1)
        if [ -n "$line" ]; then act=$(head -n "$((line - 1))" "$t" | grep -c 'TEST_CASE'); else act=$tot; fi
      fi ;;
    go)
      for t in "$d"/seed/*_test.go; do
        [ -f "$t" ] || continue
        tot=$((tot + $(grep -c '^func Test' "$t")))
        act=$((act + $(grep -c '^func Test' "$t") - $(grep -c 't\.Skip' "$t")))
      done ;;
    python)
      for t in "$d"/seed/*_test.py "$d"/seed/test_*.py; do
        [ -f "$t" ] || continue
        tot=$((tot + $(grep -cE '^ *def test' "$t")))
        act=$((act + $(grep -cE '^ *def test' "$t") - $(grep -cE '@(unittest\.)?skip|pytest\.mark\.skip' "$t")))
      done ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$n" "$lang" "$tot" "$act" >> "$OUT"
done

echo "=== per language: nodes, tests shipped, tests enabled ==="
awk -F'\t' '{n[$2]++; t[$2]+=$3; a[$2]+=$4} END {
  for (l in n) printf "  %-12s nodes=%-4s shipped=%-6s enabled=%-6s  %5.1f%%\n", l, n[l], t[l], a[l], (t[l]?100*a[l]/t[l]:0)}' "$OUT" | sort
echo
echo "=== nodes running exactly 1 of >1 tests ==="
awk -F'\t' '$4==1 && $3>1 {c[$2]++} END {for (l in c) printf "  %-12s %s\n", l, c[l]}' "$OUT" | sort
echo
echo "=== total nodes where enabled < shipped ==="
awk -F'\t' '$4<$3 {c++} END {print "  "c" / 250"}' "$OUT"
