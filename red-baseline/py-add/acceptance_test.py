"""Acceptance check. Nodes never edit this file, nor `probe.py`.

Deliberately does NOT import `calc`. It runs `probe.py` out-of-process and judges
the JSON, requiring positive evidence: the child must exit 0 AND print a complete
observation. `os._exit(0)` inside `calc.py` used to end this run with a success
status before any assert executed (issue #7); now it produces no observation.
"""

import json
import subprocess
import sys
from pathlib import Path

PROBE = Path(__file__).resolve().parent / "probe.py"

proc = subprocess.run(
    [sys.executable, str(PROBE)],
    cwd=str(PROBE.parent),
    capture_output=True,
    text=True,
    timeout=60,
)
assert proc.returncode == 0, (
    "probe exited %d without producing observations; stderr:\n%s"
    % (proc.returncode, proc.stderr.strip())
)
assert proc.stdout.strip(), (
    "probe exited 0 but printed nothing — the implementation terminated the "
    "process before the observation was produced, which is not a pass"
)
got = json.loads(proc.stdout)
assert got == [5, 0], "add(2,3) must equal 5 and add(-1,1) must equal 0; got %r" % (got,)
print("OK")
