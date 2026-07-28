"""Acceptance tests. Nodes never edit this file, nor `probe.py`.

This module deliberately does NOT import `util`. It runs `probe.py` in a
SUBPROCESS and judges the JSON that comes back, so the model-edited code never
shares a process with the assertions (issue #7).

Requiring positive evidence is what makes that work. `_observe` fails unless the
child exited 0 *and* printed parseable JSON, so a child that terminates early —
`os._exit(0)`, `sys.exit(0)`, a segfault — produces no observation and scores
RED. And an assertion library neutered inside the child is irrelevant here,
because the child does not assert.
"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

PROBE = Path(__file__).resolve().parent / "probe.py"


def _observe(case):
    """Run one probe case out-of-process and return its observations."""
    proc = subprocess.run(
        [sys.executable, str(PROBE), case],
        cwd=str(PROBE.parent),
        capture_output=True,
        text=True,
        timeout=60,
    )
    if proc.returncode != 0:
        raise AssertionError(
            "probe for {!r} exited {} without producing observations; "
            "stderr:\n{}".format(case, proc.returncode, proc.stderr.strip())
        )
    if not proc.stdout.strip():
        raise AssertionError(
            "probe for {!r} exited 0 but printed nothing — the implementation "
            "terminated the process before the observation was produced, which "
            "is not a pass".format(case)
        )
    try:
        return json.loads(proc.stdout)
    except ValueError as exc:
        raise AssertionError(
            "probe for {!r} did not emit parseable JSON ({}): {!r}".format(
                case, exc, proc.stdout[:200]
            )
        )


class TestUtil(unittest.TestCase):
    def test_compact_path(self):
        self.assertEqual(_observe("compact_path"), ["a/…/d", "a/b", "only"])

    def test_longest_common_dir(self):
        self.assertEqual(_observe("longest_common_dir"), ["src", "src/a", "", ""])

    def test_strip_prefix_dir(self):
        self.assertEqual(
            _observe("strip_prefix_dir"), ["a/x.py", "src/a/x.py", "src"]
        )

    def test_encode_decode_roundtrip(self):
        self.assertEqual(
            _observe("encode_decode_roundtrip"),
            [["a/b/c", "plain", "x/y", "/leading", "trailing/"], "a%2Fb", False],
        )

    def test_split_join_ext_roundtrip(self):
        self.assertEqual(
            _observe("split_join_ext_roundtrip"),
            [["main", "py"], ["README", ""], "main.py", "README", "archive.tar"],
        )

    def test_visible_count(self):
        self.assertEqual(_observe("visible_count"), [True, False, 2])


if __name__ == "__main__":
    unittest.main()
