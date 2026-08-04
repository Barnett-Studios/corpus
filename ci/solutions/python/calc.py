"""Reference solution for py-add. Validation only — never shipped into red-baseline/.

`prove-solvable.sh` overlays this over the node's editable file (`calc.py`, which the
loader synthesises from `stub.py`) and requires the accept to exit 0. That closes the
RED/GREEN bracket on the last hand-authored node it was open on.
"""


def add(a, b):
    return a + b
