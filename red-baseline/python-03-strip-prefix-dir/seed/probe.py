"""Fixed harness — nodes never edit this file (it is not in any node's `files:`).

`probe.py` is the only thing that imports the model-edited `util`. It computes
observations and prints them as JSON; it asserts NOTHING. All judgement lives in
`test_util.py`, which runs this as a SUBPROCESS.

That split is the point (issue #7). When model code and assertions share one
process, the model can win without solving anything — `os._exit(0)` before any
assertion runs, or replacing `unittest.TestCase.assert*` with no-ops. Both are
edits to `util.py` alone, which every node already permits.

Out-of-process, neither works: a process that dies early prints no JSON, and a
neutered `unittest` in this child is invisible to the parent that does the
asserting. The parent requires *positive evidence* — a complete, parseable
observation — rather than merely a zero exit.

Usage: python3 probe.py <case-name>   ->  JSON on stdout, exit 0
"""

import json
import sys

import util


def _cases():
    return {
        "compact_path": lambda: [
            util.compact_path("a/b/c/d", 3),
            util.compact_path("a/b", 3),
            util.compact_path("only", 3),
        ],
        "longest_common_dir": lambda: [
            util.longest_common_dir(["src/a/x.py", "src/a/y.py", "src/b/z.py"]),
            util.longest_common_dir(["src/a/x.py"]),
            util.longest_common_dir(["a.py", "b.py"]),
            util.longest_common_dir([]),
        ],
        "strip_prefix_dir": lambda: [
            util.strip_prefix_dir("src/a/x.py", "src"),
            util.strip_prefix_dir("src/a/x.py", "lib"),
            util.strip_prefix_dir("src", "src"),
        ],
        "encode_decode_roundtrip": lambda: [
            [util.decode_seg(util.encode_seg(s)) for s in
             ["a/b/c", "plain", "x/y", "/leading", "trailing/"]],
            util.encode_seg("a/b"),
            "/" in util.encode_seg("a/b"),
        ],
        "split_join_ext_roundtrip": lambda: [
            list(util.split_ext("main.py")),
            list(util.split_ext("README")),
            util.join_ext("main", "py"),
            util.join_ext("README", ""),
            util.join_ext(*util.split_ext("archive.tar")),
        ],
        "visible_count": lambda: [
            util.is_hidden(".git"),
            util.is_hidden("src"),
            util.visible_count([".git", "src", ".env", "main.py"]),
        ],
    }


def main():
    if len(sys.argv) != 2:
        print("usage: probe.py <case-name>", file=sys.stderr)
        return 2
    cases = _cases()
    case = sys.argv[1]
    if case not in cases:
        print("unknown case: " + case, file=sys.stderr)
        return 2
    json.dump(cases[case](), sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
